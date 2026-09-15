import AVFoundation
import CoreMedia
import UIKit

protocol MPVPlayerEngineDelegate: AnyObject {
    func engine(_ engine: MPVPlayerEngine, didLoad url: URL)
    func engine(_ engine: MPVPlayerEngine, didUpdateProgress position: Double, duration: Double, cacheSeconds: Double)
    func engine(_ engine: MPVPlayerEngine, didChangePause isPaused: Bool)
    func engine(_ engine: MPVPlayerEngine, didChangeLoading isLoading: Bool)
    func engine(_ engine: MPVPlayerEngine, didBecomeReadyToSeek ready: Bool)
    func engine(_ engine: MPVPlayerEngine, didBecomeTracksReady ready: Bool)
    func engine(_ engine: MPVPlayerEngine, didChangePictureInPicture isActive: Bool)
    func engine(_ engine: MPVPlayerEngine, didFailWithError message: String)
    func engine(_ engine: MPVPlayerEngine, didDetectHDRMode mode: HDRMode, fps: Double)
    func engineDidReachEnd(_ engine: MPVPlayerEngine)
    func engine(_ engine: MPVPlayerEngine, requestsSeekTo position: Double)
    func engine(_ engine: MPVPlayerEngine, requestsSeekBy offset: Double)
}

extension MPVPlayerEngineDelegate {
    func engine(_ engine: MPVPlayerEngine, requestsSeekTo position: Double) { engine.seekTo(position: position) }
    func engine(_ engine: MPVPlayerEngine, requestsSeekBy offset: Double) { engine.seekBy(offset: offset) }
}

final class MPVPlayerEngine: NSObject {
    weak var delegate: MPVPlayerEngineDelegate?
    let displayLayer = AVSampleBufferDisplayLayer()
    private let renderer: MPVLayerRenderer
    private let pipController: PiPController
    private let nowPlaying = MPVNowPlayingManager.shared
    private var currentURL: URL?
    private var currentLoop = false
    private var position = 0.0
    private var duration = 0.0
    private var zoomed = false
    private var shutDown = false
    private(set) var intendedPlayState = false

    override init() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        #if !os(tvOS)
        if #available(iOS 17.0, *) { displayLayer.wantsExtendedDynamicRangeContent = true }
        #endif
        renderer = MPVLayerRenderer(displayLayer: displayLayer)
        pipController = PiPController(sampleBufferDisplayLayer: displayLayer)
        super.init()
        renderer.delegate = self
        pipController.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }

    func start() throws { try renderer.start() }

    private func configureAudioSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .moviePlayback, policy: .longFormAudio, options: [])
            try s.setActive(true)
        } catch { Logger.shared.log("Audio session: \(error)", type: "Warn") }
    }

    @objc private func handleAudioInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began { pause() }
    }

    private func setupRemoteCommands() {
        nowPlaying.setupRemoteCommands(
            playHandler: { [weak self] in self?.play() },
            pauseHandler: { [weak self] in self?.pause() },
            toggleHandler: { [weak self] in guard let self else { return }; self.intendedPlayState ? self.pause() : self.play() },
            seekHandler: { [weak self] in self?.requestSeek(to: $0) },
            skipForward: { [weak self] in self?.requestSeek(by: $0) },
            skipBackward: { [weak self] in self?.requestSeek(by: -$0) }
        )
    }

    func setNowPlayingMetadata(_ metadata: [String: String], artworkHeaders: [String: String]? = nil) {
        nowPlaying.setMetadata(title: metadata["title"], artist: metadata["artist"], albumTitle: metadata["albumTitle"], artworkUrl: metadata["artworkUri"], artworkHeaders: artworkHeaders)
    }

    func loadVideo(config: VideoLoadConfig, force: Bool = false) {
        if !force && currentURL == config.url && currentLoop == config.loop { return }
        currentURL = config.url
        currentLoop = config.loop
        pipController.setAutoStartEnabled(true)
        let preset = PlayerPreset(id: .sdrRec709, title: "Default", summary: "Default", commands: [])
        renderer.load(
            url: config.url,
            with: preset,
            headers: config.headers,
            startPosition: config.startPosition,
            externalSubtitles: config.externalSubtitles,
            initialSubtitleId: config.initialSubtitleId,
            initialAudioId: config.initialAudioId,
            loop: config.loop,
            cacheEnabled: config.cacheEnabled,
            cacheSeconds: config.cacheSeconds,
            demuxerMaxBytes: config.demuxerMaxBytes,
            demuxerMaxBackBytes: config.demuxerMaxBackBytes
        )
        if config.autoplay { play() }
        delegate?.engine(self, didLoad: config.url)
    }

    func play() {
        intendedPlayState = true
        configureAudioSession(); setupRemoteCommands(); renderer.play(); pipController.setPlaybackRate(1)
    }
    func pause() { intendedPlayState = false; renderer.pausePlayback(); pipController.setPlaybackRate(0) }
    func destroy() {
        pipController.setAutoStartEnabled(false); renderer.stop(); currentURL = nil; currentLoop = false; intendedPlayState = false
        do { try renderer.start() } catch { delegate?.engine(self, didFailWithError: "Failed to restart renderer: \(error.localizedDescription)") }
    }
    func shutdown() {
        guard !shutDown else { return }; shutDown = true
        pipController.stopPictureInPicture(); renderer.stop(); displayLayer.removeFromSuperlayer()
        nowPlaying.cleanupRemoteCommands(); nowPlaying.deactivateAudioSession(); nowPlaying.clear()
        NotificationCenter.default.removeObserver(self)
    }
    deinit { shutdown() }

    func seekTo(position: Double) { self.position = position; renderer.seek(to: position); syncNowPlaying() }
    func seekBy(offset: Double) { position = max(0, min(position + offset, duration)); renderer.seek(by: offset); syncNowPlaying() }
    func requestSeek(to position: Double) {
        if let delegate { delegate.engine(self, requestsSeekTo: position) }
        else { seekTo(position: position) }
    }
    func requestSeek(by offset: Double) {
        if let delegate { delegate.engine(self, requestsSeekBy: offset) }
        else { seekBy(offset: offset) }
    }
    func setSpeed(speed: Double) { renderer.setSpeed(speed) }
    func getSpeed() -> Double { renderer.getSpeed() }
    func setMute(_ muted: Bool) { renderer.setMute(muted) }
    func isPaused() -> Bool { renderer.isPausedState }
    func getCurrentPosition() -> Double { position }
    func getDuration() -> Double { duration }

    func startPictureInPicture() { pipController.startPictureInPicture() }
    func stopPictureInPicture() { pipController.stopPictureInPicture() }
    func isPictureInPictureSupported() -> Bool { pipController.isPictureInPictureSupported }
    func isPictureInPictureActive() -> Bool { pipController.isPictureInPictureActive }

    func getSubtitleTracks(completion: @escaping ([[String: Any]]) -> Void) { renderer.getSubtitleTracks(completion: completion) }
    func setSubtitleTrack(_ id: Int) { renderer.setSubtitleTrack(id) }
    func disableSubtitles() { renderer.disableSubtitles() }
    func getCurrentSubtitleTrack(completion: @escaping (Int) -> Void) { renderer.getCurrentSubtitleTrack(completion: completion) }
    func addSubtitleFile(url: String, select: Bool = true) { renderer.addSubtitleFile(url: url, select: select) }
    func getAudioTracks(completion: @escaping ([[String: Any]]) -> Void) { renderer.getAudioTracks(completion: completion) }
    func setAudioTrack(_ id: Int) { renderer.setAudioTrack(id) }
    func getCurrentAudioTrack(completion: @escaping (Int) -> Void) { renderer.getCurrentAudioTrack(completion: completion) }
    func setAudioDelay(_ seconds: Double) { renderer.setAudioDelay(seconds) }
    func setVolumeBoost(_ percent: Int) { renderer.setVolumeBoost(percent) }
    func setDialogueBoost(_ enabled: Bool) { renderer.setDialogueBoost(enabled) }
    func setMonoDownmix(_ enabled: Bool) { renderer.setMonoDownmix(enabled) }
    func setSubtitlePosition(_ v: Int) { renderer.setSubtitlePosition(v) }
    func setSubtitleScale(_ v: Double) { renderer.setSubtitleScale(v) }
    func setSubtitleDelay(_ v: Double) { renderer.setSubtitleDelay(v) }
    func setSubtitleMarginY(_ v: Int) { renderer.setSubtitleMarginY(v) }
    func setSubtitleAlignX(_ v: String) { renderer.setSubtitleAlignX(v) }
    func setSubtitleAlignY(_ v: String) { renderer.setSubtitleAlignY(v) }
    func setSubtitleStyle(config: [String: Any]) { renderer.setSubtitleStyle(config: config) }
    func setSubtitleFontSize(_ v: Int) { renderer.setSubtitleFontSize(v) }
    func setSubtitleBackgroundColor(_ v: String) { renderer.setSubtitleBackgroundColor(v) }
    func setSubtitleBorderStyle(_ v: String) { renderer.setSubtitleBorderStyle(v) }
    func setSubtitleAssOverride(_ v: String) { renderer.setSubtitleAssOverride(v) }
    func setZoomedToFill(_ v: Bool) { zoomed = v; displayLayer.videoGravity = v ? .resizeAspectFill : .resizeAspect; renderer.syncSubtitleLayerFrame() }
    func isZoomedToFill() -> Bool { zoomed }
    func getTechnicalInfo(completion: @escaping ([String: Any]) -> Void) { renderer.getTechnicalInfo(completion: completion) }

    private func syncNowPlaying() { nowPlaying.updatePlayback(position: position, duration: duration, isPlaying: !renderer.isPausedState) }
}

extension MPVPlayerEngine: MPVLayerRendererDelegate {
    func renderer(_ renderer: MPVLayerRenderer, didUpdatePosition position: Double, duration: Double, cacheSeconds: Double) {
        self.position = position; self.duration = duration
        if pipController.isPictureInPictureActive { pipController.setCurrentTimeFromSeconds(position, duration: duration) }
        delegate?.engine(self, didUpdateProgress: position, duration: duration, cacheSeconds: cacheSeconds)
    }
    func renderer(_ renderer: MPVLayerRenderer, didChangePause isPaused: Bool) {
        pipController.setPlaybackRate(isPaused ? 0 : 1); syncNowPlaying(); delegate?.engine(self, didChangePause: isPaused)
    }
    func renderer(_ renderer: MPVLayerRenderer, didChangeLoading isLoading: Bool) { delegate?.engine(self, didChangeLoading: isLoading) }
    func renderer(_ renderer: MPVLayerRenderer, didBecomeReadyToSeek: Bool) { delegate?.engine(self, didBecomeReadyToSeek: didBecomeReadyToSeek) }
    func renderer(_ renderer: MPVLayerRenderer, didBecomeTracksReady: Bool) { delegate?.engine(self, didBecomeTracksReady: didBecomeTracksReady) }
    func renderer(_ renderer: MPVLayerRenderer, didDetectHDRMode mode: HDRMode, fps: Double) { delegate?.engine(self, didDetectHDRMode: mode, fps: fps) }
    func renderer(_ renderer: MPVLayerRenderer, didSelectAudioOutput audioOutput: String) { configureAudioSession(); syncNowPlaying() }
    func rendererDidReachEnd(_ renderer: MPVLayerRenderer) { delegate?.engineDidReachEnd(self) }
}

extension MPVPlayerEngine: PiPControllerDelegate {
    func pipController(_ controller: PiPController, willStartPictureInPicture: Bool) { renderer.syncTimebase(); pipController.setCurrentTimeFromSeconds(position, duration: duration) }
    func pipController(_ controller: PiPController, didStartPictureInPicture: Bool) { delegate?.engine(self, didChangePictureInPicture: didStartPictureInPicture) }
    func pipController(_ controller: PiPController, willStopPictureInPicture: Bool) { renderer.syncTimebase() }
    func pipController(_ controller: PiPController, didStopPictureInPicture: Bool) { renderer.syncTimebase(); delegate?.engine(self, didChangePictureInPicture: false) }
    func pipController(_ controller: PiPController, restoreUserInterfaceForPictureInPictureStop completionHandler: @escaping (Bool) -> Void) { completionHandler(true) }
    func pipControllerPlay(_ controller: PiPController) { play() }
    func pipControllerPause(_ controller: PiPController) { pause() }
    func pipController(_ controller: PiPController, skipByInterval interval: CMTime) { requestSeek(by: CMTimeGetSeconds(interval)) }
    func pipControllerIsPlaying(_ controller: PiPController) -> Bool { intendedPlayState }
    func pipControllerDuration(_ controller: PiPController) -> Double { duration }
    func pipControllerCurrentPosition(_ controller: PiPController) -> Double { position }
}
