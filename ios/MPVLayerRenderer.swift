import AVFoundation
import CoreMedia
import Foundation
import MPVKit
import UIKit

enum HDRMode { case sdr, hdr10, dolbyVision, hlg }

protocol MPVLayerRendererDelegate: AnyObject {
    func renderer(_ renderer: MPVLayerRenderer, didUpdatePosition position: Double, duration: Double, cacheSeconds: Double)
    func renderer(_ renderer: MPVLayerRenderer, didChangePause isPaused: Bool)
    func renderer(_ renderer: MPVLayerRenderer, didChangeLoading isLoading: Bool)
    func renderer(_ renderer: MPVLayerRenderer, didBecomeReadyToSeek: Bool)
    func renderer(_ renderer: MPVLayerRenderer, didBecomeTracksReady: Bool)
    func renderer(_ renderer: MPVLayerRenderer, didDetectHDRMode mode: HDRMode, fps: Double)
    func renderer(_ renderer: MPVLayerRenderer, didSelectAudioOutput audioOutput: String)
    func rendererDidReachEnd(_ renderer: MPVLayerRenderer)
}

final class MPVLayerRenderer {
    enum RendererError: Error { case mpvCreationFailed, mpvInitialization(Int32) }

    private let displayLayer: AVSampleBufferDisplayLayer
    private let queue = DispatchQueue(label: "expo.libmpv.avfoundation", qos: .userInitiated)
    private static let queueKey = DispatchSpecificKey<Bool>()
    private var mpv: OpaquePointer?
    private var running = false
    private var stopping = false
    private var pendingExternalSubtitles: [String] = []
    private var initialSubtitleId: Int?
    private var initialAudioId: Int?
    private var cachedDuration = 0.0
    private var cachedPosition = 0.0
    private var cachedCacheSeconds = 0.0
    private var paused = true
    private var playbackSpeed = 1.0
    private var loading = false
    private var seeking = false
    private var muted = false
    private var lastProgressUpdate: CFAbsoluteTime = 0

    weak var delegate: MPVLayerRendererDelegate?
    var isPausedState: Bool { paused }

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    deinit { stop() }

    func start() throws {
        guard !running else { return }
        guard let handle = mpv_create() else { throw RendererError.mpvCreationFailed }
        mpv = handle

        _ = mpv_request_log_messages(handle, "warn")
        let layerPtrInt = Int(bitPattern: Unmanaged.passUnretained(displayLayer).toOpaque())
        var layerPtr = Int64(layerPtrInt)
        tryCheck(mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &layerPtr))
        tryCheck(mpv_set_option_string(handle, "vo", "avfoundation"))
        #if os(tvOS) || targetEnvironment(simulator)
        tryCheck(mpv_set_option_string(handle, "avfoundation-composite-osd", "no"))
        #else
        tryCheck(mpv_set_option_string(handle, "avfoundation-composite-osd", "yes"))
        #endif
        #if targetEnvironment(simulator)
        tryCheck(mpv_set_option_string(handle, "hwdec", "no"))
        #else
        tryCheck(mpv_set_option_string(handle, "hwdec", "videotoolbox"))
        #endif
        tryCheck(mpv_set_option_string(handle, "hwdec-codecs", "all"))
        tryCheck(mpv_set_option_string(handle, "hwdec-software-fallback", "yes"))
        #if os(tvOS)
        tryCheck(mpv_set_option_string(handle, "target-colorspace-hint", "yes"))
        tryCheck(mpv_set_option_string(handle, "ao", "audiounit"))
        #endif
        tryCheck(mpv_set_option_string(handle, "sub-scale-with-window", "no"))
        tryCheck(mpv_set_option_string(handle, "sub-use-margins", "no"))
        tryCheck(mpv_set_option_string(handle, "subs-match-os-language", "yes"))
        tryCheck(mpv_set_option_string(handle, "subs-fallback", "yes"))
        tryCheck(mpv_set_option_string(handle, "sub-vsfilter-bidi-compat", "yes"))

        let status = mpv_initialize(handle)
        guard status >= 0 else { throw RendererError.mpvInitialization(status) }
        if muted { _ = mpv_set_property_string(handle, "mute", "yes") }
        observeProperties(handle)
        mpv_set_wakeup_callback(handle, { ctx in
            guard let ctx else { return }
            Unmanaged<MPVLayerRenderer>.fromOpaque(ctx).takeUnretainedValue().processEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
        running = true
    }

    private func tryCheck(_ status: Int32) {
        if status < 0 { Logger.shared.log("MPV API error: \(String(cString: mpv_error_string(status)))", type: "Warn") }
    }

    func stop() {
        guard !stopping else { return }
        guard let handle = mpv else { return }
        stopping = true
        running = false
        mpv_set_wakeup_callback(handle, nil, nil)
        mpv = nil
        queue.async {
            "quit".withCString { quit in
                var args: [UnsafePointer<CChar>?] = [quit, nil]
                args.withUnsafeMutableBufferPointer { _ = mpv_command(handle, $0.baseAddress) }
            }
            DispatchQueue.global(qos: .userInitiated).async { mpv_terminate_destroy(handle) }
        }
        stopping = false
        DispatchQueue.main.async { [weak self] in
            if #available(iOS 18.0, tvOS 17.0, *) {
                self?.displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
            } else {
                self?.displayLayer.flushAndRemoveImage()
            }
        }
    }

    func load(
        url: URL,
        with preset: PlayerPreset,
        headers: [String: String]? = nil,
        startPosition: Double? = nil,
        externalSubtitles: [String]? = nil,
        initialSubtitleId: Int? = nil,
        initialAudioId: Int? = nil,
        loop: Bool = false,
        cacheEnabled: String? = nil,
        cacheSeconds: Int? = nil,
        demuxerMaxBytes: Int? = nil,
        demuxerMaxBackBytes: Int? = nil
    ) {
        onQueue { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.pendingExternalSubtitles = externalSubtitles ?? []
            self.initialSubtitleId = initialSubtitleId
            self.initialAudioId = initialAudioId
            self.loading = true
            DispatchQueue.main.async { self.delegate?.renderer(self, didChangeLoading: true) }
            self.commandSync(handle, ["stop"])
            self.updateHTTPHeaders(headers)
            self.setPropertyOnQueue(handle, "loop-file", loop ? "inf" : "no")
            if let value = cacheEnabled { self.setPropertyOnQueue(handle, "cache", value) }
            if let value = cacheSeconds { self.setPropertyOnQueue(handle, "cache-secs", String(value)) }
            if let value = demuxerMaxBytes { self.setPropertyOnQueue(handle, "demuxer-max-bytes", "\(value)MiB") }
            if let value = demuxerMaxBackBytes { self.setPropertyOnQueue(handle, "demuxer-max-back-bytes", "\(value)MiB") }
            self.setPropertyOnQueue(handle, "start", startPosition.map { String(format: "%.2f", max(0, $0)) } ?? "0")
            let target = url.isFileURL ? url.path : url.absoluteString
            self.commandSync(handle, ["loadfile", target, "replace"])
        }
    }

    private var isOnQueue: Bool { DispatchQueue.getSpecific(key: Self.queueKey) == true }
    private func onQueue(_ work: @escaping () -> Void) { isOnQueue ? work() : queue.async(execute: work) }

    private func setProperty(name: String, value: String) {
        onQueue { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.setPropertyOnQueue(handle, name, value)
        }
    }
    private func setPropertyOnQueue(_ handle: OpaquePointer, _ name: String, _ value: String) {
        let status = mpv_set_property_string(handle, name, value)
        if status < 0 { Logger.shared.log("Failed to set \(name)=\(value)", type: "Warn") }
    }

    private func updateHTTPHeaders(_ headers: [String: String]?) {
        guard let handle = mpv else { return }
        setPropertyOnQueue(handle, "http-header-fields", "")
        guard let headers, !headers.isEmpty else { return }
        setPropertyOnQueue(handle, "http-header-fields", headers.map { "\($0.key): \($0.value)" }.joined(separator: ","))
    }

    private func observeProperties(_ handle: OpaquePointer) {
        let properties: [(String, mpv_format)] = [
            ("duration", MPV_FORMAT_DOUBLE), ("time-pos", MPV_FORMAT_DOUBLE),
            ("pause", MPV_FORMAT_FLAG), ("track-list/count", MPV_FORMAT_INT64),
            ("paused-for-cache", MPV_FORMAT_FLAG), ("demuxer-cache-duration", MPV_FORMAT_DOUBLE),
            ("current-ao", MPV_FORMAT_STRING),
        ]
        for (name, format) in properties { mpv_observe_property(handle, 0, name, format) }
    }

    private func processEvents() {
        queue.async { [weak self] in
            guard let self else { return }
            while let handle = self.mpv, !self.stopping {
                guard let eventPtr = mpv_wait_event(handle, 0) else { return }
                let event = eventPtr.pointee
                if event.event_id == MPV_EVENT_NONE { break }
                self.handleEvent(event)
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
            }
        }
    }

    private func handleEvent(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_FILE_LOADED:
            if let handle = mpv {
                for sub in pendingExternalSubtitles { commandSync(handle, ["sub-add", sub, "auto"]) }
                pendingExternalSubtitles.removeAll()
            }
            if let id = initialAudioId, id > 0 { setAudioTrack(id) }
            if let id = initialSubtitleId { setSubtitleTrack(id) } else { disableSubtitles() }
            loading = false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.renderer(self, didBecomeTracksReady: true)
                self.delegate?.renderer(self, didBecomeReadyToSeek: true)
                self.delegate?.renderer(self, didChangeLoading: false)
            }
            detectHDRMode()
        case MPV_EVENT_SEEK:
            seeking = true; loading = true
            DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didChangeLoading: true) } }
        case MPV_EVENT_PLAYBACK_RESTART:
            seeking = false
            if loading { loading = false; DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didChangeLoading: false) } } }
        case MPV_EVENT_END_FILE:
            if let data = event.data?.assumingMemoryBound(to: mpv_event_end_file.self).pointee,
               data.reason == MPV_END_FILE_REASON_EOF {
                DispatchQueue.main.async { [weak self] in if let self { self.delegate?.rendererDidReachEnd(self) } }
            }
        case MPV_EVENT_PROPERTY_CHANGE:
            if let cName = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee.name {
                refreshProperty(String(cString: cName))
            }
        default: break
        }
    }

    private func refreshProperty(_ name: String) {
        guard let handle = mpv else { return }
        switch name {
        case "duration":
            var value = 0.0; if getProperty(handle, name, MPV_FORMAT_DOUBLE, &value) >= 0 { cachedDuration = value; postProgress() }
        case "time-pos":
            var value = 0.0; if getProperty(handle, name, MPV_FORMAT_DOUBLE, &value) >= 0 {
                cachedPosition = value
                let now = CFAbsoluteTimeGetCurrent()
                if seeking || now - lastProgressUpdate >= 1 { lastProgressUpdate = now; postProgress() }
            }
        case "demuxer-cache-duration":
            var value = 0.0; if getProperty(handle, name, MPV_FORMAT_DOUBLE, &value) >= 0 { cachedCacheSeconds = value }
        case "pause":
            var flag: Int32 = 0; if getProperty(handle, name, MPV_FORMAT_FLAG, &flag) >= 0 {
                let p = flag != 0; if p != paused { paused = p; DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didChangePause: p) } } }
            }
        case "paused-for-cache":
            var flag: Int32 = 0; if getProperty(handle, name, MPV_FORMAT_FLAG, &flag) >= 0 {
                let buffering = flag != 0; if buffering != loading { loading = buffering; DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didChangeLoading: buffering) } } }
            }
        case "track-list/count":
            var count: Int64 = 0; if getProperty(handle, name, MPV_FORMAT_INT64, &count) >= 0, count > 0 {
                DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didBecomeTracksReady: true) } }
            }
        case "current-ao":
            if let ao = getStringProperty(handle, name) { DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didSelectAudioOutput: ao) } } }
        default: break
        }
    }

    private func postProgress() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.renderer(self, didUpdatePosition: self.cachedPosition, duration: self.cachedDuration, cacheSeconds: self.cachedCacheSeconds)
        }
    }

    func play() { setProperty(name: "pause", value: "no") }
    func pausePlayback() { setProperty(name: "pause", value: "yes") }
    func togglePause() { paused ? play() : pausePlayback() }
    func seek(to seconds: Double) { cachedPosition = max(0, seconds); onQueue { [weak self] in if let self, let h = self.mpv { self.commandSync(h, ["seek", String(max(0, seconds)), "absolute"]) } } }
    func seek(by seconds: Double) { cachedPosition = max(0, cachedPosition + seconds); onQueue { [weak self] in if let self, let h = self.mpv { self.commandSync(h, ["seek", String(seconds), "relative"]) } } }
    func syncSubtitleLayerFrame() {}
    func syncTimebase() {}
    func setSpeed(_ speed: Double) { playbackSpeed = speed; setProperty(name: "speed", value: String(speed)) }
    func getSpeed() -> Double { playbackSpeed }
    func setMute(_ muted: Bool) { self.muted = muted; setProperty(name: "mute", value: muted ? "yes" : "no") }

    func getSubtitleTracks(completion: @escaping ([[String: Any]]) -> Void) { onQueue { [weak self] in completion(self?.tracks(type: "sub") ?? []) } }
    func getAudioTracks(completion: @escaping ([[String: Any]]) -> Void) { onQueue { [weak self] in completion(self?.tracks(type: "audio") ?? []) } }

    private func tracks(type: String) -> [[String: Any]] {
        guard let handle = mpv else { return [] }
        var count: Int64 = 0; _ = getProperty(handle, "track-list/count", MPV_FORMAT_INT64, &count)
        var result: [[String: Any]] = []
        for i in 0..<count {
            guard getStringProperty(handle, "track-list/\(i)/type") == type else { continue }
            var id: Int64 = 0; guard getProperty(handle, "track-list/\(i)/id", MPV_FORMAT_INT64, &id) >= 0 else { continue }
            var row: [String: Any] = ["id": Int(id)]
            if let v = getStringProperty(handle, "track-list/\(i)/title") { row["title"] = v }
            if let v = getStringProperty(handle, "track-list/\(i)/lang") { row["lang"] = v }
            if let v = getStringProperty(handle, "track-list/\(i)/codec") { row["codec"] = v }
            var selected: Int32 = 0; _ = getProperty(handle, "track-list/\(i)/selected", MPV_FORMAT_FLAG, &selected); row["selected"] = selected != 0
            if type == "sub" {
                var external: Int32 = 0; _ = getProperty(handle, "track-list/\(i)/external", MPV_FORMAT_FLAG, &external); row["external"] = external != 0
                if let v = getStringProperty(handle, "track-list/\(i)/external-filename") { row["externalFilename"] = v }
                var idx: Int64 = 0; if getProperty(handle, "track-list/\(i)/ff-index", MPV_FORMAT_INT64, &idx) >= 0 { row["ffIndex"] = Int(idx) }
            }
            result.append(row)
        }
        return result
    }

    func setSubtitleTrack(_ id: Int) { setProperty(name: "sid", value: id < 0 ? "no" : String(id)) }
    func disableSubtitles() { setProperty(name: "sid", value: "no") }
    func getCurrentSubtitleTrack(completion: @escaping (Int) -> Void) { getIntProperty("sid", completion: completion) }
    func addSubtitleFile(url: String, select: Bool = true) { onQueue { [weak self] in if let self, let h = self.mpv { self.commandSync(h, ["sub-add", url, select ? "select" : "cached"]) } } }
    func setAudioTrack(_ id: Int) { setProperty(name: "aid", value: String(id)) }
    func getCurrentAudioTrack(completion: @escaping (Int) -> Void) { getIntProperty("aid", completion: completion) }
    private func getIntProperty(_ name: String, completion: @escaping (Int) -> Void) { onQueue { [weak self] in guard let self, let h = self.mpv else { completion(0); return }; var v: Int64 = 0; _ = self.getProperty(h, name, MPV_FORMAT_INT64, &v); completion(Int(v)) } }

    func setSubtitlePosition(_ v: Int) { setProperty(name: "sub-pos", value: String(v)) }
    func setSubtitleScale(_ v: Double) { setProperty(name: "sub-scale", value: String(v)) }
    func setSubtitleDelay(_ v: Double) { setProperty(name: "sub-delay", value: String(v)) }
    func setAudioDelay(_ v: Double) { setProperty(name: "audio-delay", value: String(v)) }
    func setVolumeBoost(_ v: Int) { setProperty(name: "volume-max", value: "200"); setProperty(name: "volume", value: String(v)) }
    func setDialogueBoost(_ enabled: Bool) { setProperty(name: "af", value: enabled ? "lavfi=[equalizer=f=100:t=q:w=1.2:g=-6,equalizer=f=2800:t=q:w=1.2:g=5]" : "") }
    func setMonoDownmix(_ enabled: Bool) { setProperty(name: "audio-channels", value: enabled ? "mono" : "auto-safe") }
    func setSubtitleMarginY(_ v: Int) { setProperty(name: "sub-margin-y", value: String(v)) }
    func setSubtitleAlignX(_ v: String) { setProperty(name: "sub-align-x", value: v) }
    func setSubtitleAlignY(_ v: String) { setProperty(name: "sub-align-y", value: v) }
    func setSubtitleFontSize(_ v: Int) { setProperty(name: "sub-font-size", value: String(v)) }
    func setSubtitleBackgroundColor(_ v: String) { setProperty(name: "sub-back-color", value: v) }
    func setSubtitleBorderStyle(_ v: String) { setProperty(name: "sub-border-style", value: v) }
    func setSubtitleAssOverride(_ v: String) { setProperty(name: "sub-ass-override", value: v == "no" ? "scale" : v) }
    func setSubtitleStyle(config: [String: Any]) {
        if let v = config["fontSize"] as? NSNumber { setSubtitleFontSize(v.intValue) }
        if let v = config["color"] as? String { setProperty(name: "sub-color", value: v) }
        if let v = config["font"] as? String { setProperty(name: "sub-font", value: Self.mpvSubtitleFont(v)) }
        if let bg = config["background"] as? String {
            if bg.isEmpty { setSubtitleBorderStyle("outline-and-shadow"); setProperty(name: "sub-border-size", value: "3") }
            else { setSubtitleBackgroundColor(bg); setSubtitleBorderStyle("background-box"); setProperty(name: "sub-border-size", value: "0") }
        }
    }
    static func mpvSubtitleFont(_ font: String) -> String {
        switch font { case "System": return "sans-serif"; case "sans-serif": return "Helvetica"; case "serif": return "Georgia"; case "monospace": return "Menlo"; default: return font }
    }

    private func detectHDRMode() {
        guard let handle = mpv else { return }
        let primaries = getStringProperty(handle, "video-params/primaries")
        let gamma = getStringProperty(handle, "video-params/gamma")
        var fps = 24.0; _ = getProperty(handle, "container-fps", MPV_FORMAT_DOUBLE, &fps); if fps <= 0 { fps = 24 }
        let mode: HDRMode
        if primaries == "bt.2020" || primaries == "bt.2020-ncl" {
            if gamma == "pq" { mode = .hdr10 } else if gamma == "hlg" { mode = .hlg } else { mode = .hdr10 }
        } else { mode = .sdr }
        DispatchQueue.main.async { [weak self] in if let self { self.delegate?.renderer(self, didDetectHDRMode: mode, fps: fps) } }
    }

    func getTechnicalInfo(completion: @escaping ([String: Any]) -> Void) {
        onQueue { [weak self] in
            guard let self, let h = self.mpv else { completion([:]); return }
            var info: [String: Any] = [:]
            func string(_ prop: String, _ key: String) { if let v = self.getStringProperty(h, prop) { info[key] = v } }
            func int(_ prop: String, _ key: String) { var v: Int64 = 0; if self.getProperty(h, prop, MPV_FORMAT_INT64, &v) >= 0 { info[key] = Int(v) } }
            func double(_ prop: String, _ key: String) { var v = 0.0; if self.getProperty(h, prop, MPV_FORMAT_DOUBLE, &v) >= 0 { info[key] = v } }
            int("video-params/w", "videoWidth"); int("video-params/h", "videoHeight")
            string("video-format", "videoCodec"); string("audio-codec-name", "audioCodec")
            double("container-fps", "fps"); int("video-bitrate", "videoBitrate"); int("audio-bitrate", "audioBitrate")
            double("demuxer-cache-duration", "cacheSeconds"); int("frame-drop-count", "droppedFrames")
            string("vo", "voDriver"); string("hwdec-current", "hwdec"); double("estimated-vf-fps", "estimatedVfFps")
            string("video-params/gamma", "colorTransfer"); string("video-params/primaries", "colorSpace")
            completion(info)
        }
    }

    private func commandSync(_ handle: OpaquePointer, _ args: [String]) -> Int32 {
        withCStringArray(args) { mpv_command(handle, $0) }
    }
    private func getStringProperty(_ handle: OpaquePointer, _ name: String) -> String? {
        guard let ptr = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(ptr) }
        return String(cString: ptr)
    }
    private func getProperty<T>(_ handle: OpaquePointer, _ name: String, _ format: mpv_format, _ value: inout T) -> Int32 {
        withUnsafeMutablePointer(to: &value) { mpv_get_property(handle, name, format, $0) }
    }
    private func withCStringArray<R>(_ args: [String], body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> R) -> R {
        var strings = args.map { strdup($0) }
        strings.append(nil)
        defer { strings.forEach { if let p = $0 { free(p) } } }
        return strings.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                body(UnsafeMutablePointer(mutating: $0))
            }
        }
    }
}
