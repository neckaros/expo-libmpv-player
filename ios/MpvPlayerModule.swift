import CoreMedia
import ExpoModulesCore
import VideoToolbox

public class MpvPlayerModule: Module {
    private var logObserver: NSObjectProtocol?

    private func intValue(_ value: Any?) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? Double, v.isFinite { return Int(exactly: v) }
        return nil
    }

    public func definition() -> ModuleDefinition {
        Name("MpvPlayer")
        Events("onChange", "onNativeLog")

        OnStartObserving {
            guard self.logObserver == nil else { return }
            self.logObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("LoggerNotification"), object: nil, queue: nil) { [weak self] note in
                guard let message = note.userInfo?["message"] as? String else { return }
                self?.sendEvent("onNativeLog", ["message": message, "type": note.userInfo?["type"] as? String ?? "General"])
            }
        }
        OnStopObserving {
            if let observer = self.logObserver { NotificationCenter.default.removeObserver(observer); self.logObserver = nil }
        }

        Function("hello") { "Hello from MPV Player! 👋" }
        Function("supportsAv1HardwareDecode") { () -> Bool in
            VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
        }
        AsyncFunction("setValueAsync") { (value: String) in self.sendEvent("onChange", ["value": value]) }

        View(MpvPlayerView.self) {
            Prop("source") { (view: MpvPlayerView, source: [String: Any]?) in
                guard let source, let string = source["url"] as? String, let url = URL(string: string) else { return }
                let cache = source["cacheConfig"] as? [String: Any]
                view.loadVideo(config: VideoLoadConfig(
                    url: url,
                    headers: source["headers"] as? [String: String],
                    externalSubtitles: source["externalSubtitles"] as? [String],
                    startPosition: source["startPosition"] as? Double,
                    autoplay: source["autoplay"] as? Bool ?? true,
                    initialSubtitleId: self.intValue(source["initialSubtitleId"]),
                    initialAudioId: self.intValue(source["initialAudioId"]),
                    loop: source["loop"] as? Bool ?? false,
                    cacheEnabled: cache?["enabled"] as? String,
                    cacheSeconds: self.intValue(cache?["cacheSeconds"]),
                    demuxerMaxBytes: self.intValue(cache?["maxBytes"]),
                    demuxerMaxBackBytes: self.intValue(cache?["maxBackBytes"]),
                    cachePause: cache?["pause"] as? Bool,
                    cachePauseInitial: cache?["pauseInitial"] as? Bool,
                    cachePauseWaitSeconds: cache?["pauseWaitSeconds"] as? Double
                ))
            }
            Prop("nowPlayingMetadata") { (view: MpvPlayerView, metadata: [String: Any]?) in
                guard let metadata else { return }
                var strings: [String: String] = [:]
                for (k, v) in metadata { if let v = v as? String { strings[k] = v } }
                view.setNowPlayingMetadata(strings, artworkHeaders: metadata["artworkHeaders"] as? [String: String])
            }

            AsyncFunction("play") { (view: MpvPlayerView) in view.play() }
            AsyncFunction("pause") { (view: MpvPlayerView) in view.pause() }
            AsyncFunction("destroy") { (view: MpvPlayerView) in view.destroy() }
            AsyncFunction("seekTo") { (view: MpvPlayerView, v: Double) in view.seekTo(position: v) }
            AsyncFunction("seekBy") { (view: MpvPlayerView, v: Double) in view.seekBy(offset: v) }
            AsyncFunction("setSpeed") { (view: MpvPlayerView, v: Double) in view.setSpeed(speed: v) }
            AsyncFunction("setMute") { (view: MpvPlayerView, v: Bool) in view.setMute(muted: v) }
            AsyncFunction("getSpeed") { (view: MpvPlayerView) -> Double in view.getSpeed() }
            AsyncFunction("isPaused") { (view: MpvPlayerView) -> Bool in view.isPaused() }
            AsyncFunction("getCurrentPosition") { (view: MpvPlayerView) -> Double in view.getCurrentPosition() }
            AsyncFunction("getDuration") { (view: MpvPlayerView) -> Double in view.getDuration() }
            AsyncFunction("startPictureInPicture") { (view: MpvPlayerView) in view.startPictureInPicture() }
            AsyncFunction("stopPictureInPicture") { (view: MpvPlayerView) in view.stopPictureInPicture() }
            AsyncFunction("isPictureInPictureSupported") { (view: MpvPlayerView) -> Bool in view.isPictureInPictureSupported() }
            AsyncFunction("isPictureInPictureActive") { (view: MpvPlayerView) -> Bool in view.isPictureInPictureActive() }
            AsyncFunction("getSubtitleTracks") { (view: MpvPlayerView, promise: Promise) in view.getSubtitleTracks { promise.resolve($0) } }
            AsyncFunction("setSubtitleTrack") { (view: MpvPlayerView, id: Int) in view.setSubtitleTrack(id) }
            AsyncFunction("disableSubtitles") { (view: MpvPlayerView) in view.disableSubtitles() }
            AsyncFunction("getCurrentSubtitleTrack") { (view: MpvPlayerView, promise: Promise) in view.getCurrentSubtitleTrack { promise.resolve($0) } }
            AsyncFunction("addSubtitleFile") { (view: MpvPlayerView, url: String, select: Bool) in view.addSubtitleFile(url: url, select: select) }
            AsyncFunction("setSubtitlePosition") { (view: MpvPlayerView, v: Int) in view.setSubtitlePosition(v) }
            AsyncFunction("setSubtitleScale") { (view: MpvPlayerView, v: Double) in view.setSubtitleScale(v) }
            AsyncFunction("setSubtitleDelay") { (view: MpvPlayerView, v: Double) in view.setSubtitleDelay(v) }
            AsyncFunction("setSubtitleMarginY") { (view: MpvPlayerView, v: Int) in view.setSubtitleMarginY(v) }
            AsyncFunction("setSubtitleAlignX") { (view: MpvPlayerView, v: String) in view.setSubtitleAlignX(v) }
            AsyncFunction("setSubtitleAlignY") { (view: MpvPlayerView, v: String) in view.setSubtitleAlignY(v) }
            AsyncFunction("setSubtitleFontSize") { (view: MpvPlayerView, v: Int) in view.setSubtitleFontSize(v) }
            AsyncFunction("setSubtitleStyle") { (view: MpvPlayerView, v: [String: Any]) in view.setSubtitleStyle(config: v) }
            AsyncFunction("setSubtitleBackgroundColor") { (view: MpvPlayerView, v: String) in view.setSubtitleBackgroundColor(v) }
            AsyncFunction("setSubtitleBorderStyle") { (view: MpvPlayerView, v: String) in view.setSubtitleBorderStyle(v) }
            AsyncFunction("setSubtitleAssOverride") { (view: MpvPlayerView, v: String) in view.setSubtitleAssOverride(v) }
            AsyncFunction("getAudioTracks") { (view: MpvPlayerView, promise: Promise) in view.getAudioTracks { promise.resolve($0) } }
            AsyncFunction("setAudioTrack") { (view: MpvPlayerView, id: Int) in view.setAudioTrack(id) }
            AsyncFunction("getCurrentAudioTrack") { (view: MpvPlayerView, promise: Promise) in view.getCurrentAudioTrack { promise.resolve($0) } }
            AsyncFunction("setAudioDelay") { (view: MpvPlayerView, seconds: Double) in view.setAudioDelay(seconds) }
            AsyncFunction("setVolumeBoost") { (view: MpvPlayerView, percent: Int) in view.setVolumeBoost(percent) }
            AsyncFunction("setDialogueBoost") { (view: MpvPlayerView, enabled: Bool) in view.setDialogueBoost(enabled) }
            AsyncFunction("setMonoDownmix") { (view: MpvPlayerView, enabled: Bool) in view.setMonoDownmix(enabled) }
            AsyncFunction("setZoomedToFill") { (view: MpvPlayerView, v: Bool) in view.setZoomedToFill(v) }
            AsyncFunction("isZoomedToFill") { (view: MpvPlayerView) -> Bool in view.isZoomedToFill() }
            AsyncFunction("getTechnicalInfo") { (view: MpvPlayerView, promise: Promise) in view.getTechnicalInfo { promise.resolve($0) } }

            Events("onLoad", "onPlaybackStateChange", "onProgress", "onError", "onTracksReady", "onPictureInPictureChange", "onEnd")
        }
    }
}
