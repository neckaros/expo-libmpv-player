import AVFoundation
import ExpoModulesCore
import UIKit

struct VideoLoadConfig {
    let url: URL
    var headers: [String: String]?
    var externalSubtitles: [String]?
    var startPosition: Double?
    var autoplay: Bool
    var initialSubtitleId: Int?
    var initialAudioId: Int?
    var loop: Bool
    var cacheEnabled: String?
    var cacheSeconds: Int?
    var demuxerMaxBytes: Int?
    var demuxerMaxBackBytes: Int?
    var cachePause: Bool?
    var cachePauseInitial: Bool?
    var cachePauseWaitSeconds: Double?
}

class MpvPlayerView: ExpoView {
    private let engine = MPVPlayerEngine()
    private let videoContainer = UIView()
    let onLoad = EventDispatcher()
    let onPlaybackStateChange = EventDispatcher()
    let onProgress = EventDispatcher()
    let onError = EventDispatcher()
    let onTracksReady = EventDispatcher()
    let onPictureInPictureChange = EventDispatcher()
    let onEnd = EventDispatcher()

    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        clipsToBounds = true
        backgroundColor = .black
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.backgroundColor = .black
        videoContainer.clipsToBounds = true
        addSubview(videoContainer)
        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: topAnchor), videoContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: leadingAnchor), videoContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        engine.delegate = self
        videoContainer.layer.addSublayer(engine.displayLayer)
        do { try engine.start() } catch { onError(["error": "Failed to start renderer: \(error.localizedDescription)"]) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        engine.displayLayer.frame = videoContainer.bounds
        engine.displayLayer.contentsScale = contentScaleFactor
        CATransaction.commit()
    }

    func loadVideo(config: VideoLoadConfig) { engine.loadVideo(config: config) }
    func setNowPlayingMetadata(_ metadata: [String: String], artworkHeaders: [String: String]? = nil) { engine.setNowPlayingMetadata(metadata, artworkHeaders: artworkHeaders) }
    func play() { engine.play() }
    func pause() { engine.pause() }
    func destroy() { engine.destroy() }
    func seekTo(position: Double) { engine.seekTo(position: position) }
    func seekBy(offset: Double) { engine.seekBy(offset: offset) }
    func setSpeed(speed: Double) { engine.setSpeed(speed: speed) }
    func setMute(muted: Bool) { engine.setMute(muted) }
    func getSpeed() -> Double { engine.getSpeed() }
    func isPaused() -> Bool { engine.isPaused() }
    func getCurrentPosition() -> Double { engine.getCurrentPosition() }
    func getDuration() -> Double { engine.getDuration() }
    func startPictureInPicture() { engine.startPictureInPicture() }
    func stopPictureInPicture() { engine.stopPictureInPicture() }
    func isPictureInPictureSupported() -> Bool { engine.isPictureInPictureSupported() }
    func isPictureInPictureActive() -> Bool { engine.isPictureInPictureActive() }
    func getSubtitleTracks(completion: @escaping ([[String: Any]]) -> Void) { engine.getSubtitleTracks(completion: completion) }
    func setSubtitleTrack(_ id: Int) { engine.setSubtitleTrack(id) }
    func disableSubtitles() { engine.disableSubtitles() }
    func getCurrentSubtitleTrack(completion: @escaping (Int) -> Void) { engine.getCurrentSubtitleTrack(completion: completion) }
    func addSubtitleFile(url: String, select: Bool = true) { engine.addSubtitleFile(url: url, select: select) }
    func getAudioTracks(completion: @escaping ([[String: Any]]) -> Void) { engine.getAudioTracks(completion: completion) }
    func setAudioTrack(_ id: Int) { engine.setAudioTrack(id) }
    func getCurrentAudioTrack(completion: @escaping (Int) -> Void) { engine.getCurrentAudioTrack(completion: completion) }
    func setAudioDelay(_ seconds: Double) { engine.setAudioDelay(seconds) }
    func setVolumeBoost(_ percent: Int) { engine.setVolumeBoost(percent) }
    func setDialogueBoost(_ enabled: Bool) { engine.setDialogueBoost(enabled) }
    func setMonoDownmix(_ enabled: Bool) { engine.setMonoDownmix(enabled) }
    func setSubtitlePosition(_ v: Int) { engine.setSubtitlePosition(v) }
    func setSubtitleScale(_ v: Double) { engine.setSubtitleScale(v) }
    func setSubtitleDelay(_ v: Double) { engine.setSubtitleDelay(v) }
    func setSubtitleMarginY(_ v: Int) { engine.setSubtitleMarginY(v) }
    func setSubtitleAlignX(_ v: String) { engine.setSubtitleAlignX(v) }
    func setSubtitleAlignY(_ v: String) { engine.setSubtitleAlignY(v) }
    func setSubtitleStyle(config: [String: Any]) { engine.setSubtitleStyle(config: config) }
    func setSubtitleFontSize(_ v: Int) { engine.setSubtitleFontSize(v) }
    func setSubtitleBackgroundColor(_ v: String) { engine.setSubtitleBackgroundColor(v) }
    func setSubtitleBorderStyle(_ v: String) { engine.setSubtitleBorderStyle(v) }
    func setSubtitleAssOverride(_ v: String) { engine.setSubtitleAssOverride(v) }
    func setZoomedToFill(_ v: Bool) { engine.setZoomedToFill(v) }
    func isZoomedToFill() -> Bool { engine.isZoomedToFill() }
    func getTechnicalInfo(completion: @escaping ([String: Any]) -> Void) { engine.getTechnicalInfo(completion: completion) }

    deinit { engine.shutdown() }
}

extension MpvPlayerView: MPVPlayerEngineDelegate {
    func engine(_ engine: MPVPlayerEngine, didLoad url: URL) { onLoad(["url": url.absoluteString]) }
    func engine(_ engine: MPVPlayerEngine, didUpdateProgress position: Double, duration: Double, cacheSeconds: Double) {
        onProgress(["position": position, "duration": duration, "progress": duration > 0 ? position / duration : 0, "cacheSeconds": cacheSeconds])
    }
    func engine(_ engine: MPVPlayerEngine, didChangePause isPaused: Bool) { onPlaybackStateChange(["isPaused": isPaused, "isPlaying": !isPaused]) }
    func engine(_ engine: MPVPlayerEngine, didChangeLoading isLoading: Bool) { onPlaybackStateChange(["isLoading": isLoading]) }
    func engine(_ engine: MPVPlayerEngine, didBecomeReadyToSeek ready: Bool) { onPlaybackStateChange(["isReadyToSeek": ready]) }
    func engine(_ engine: MPVPlayerEngine, didBecomeTracksReady ready: Bool) { onTracksReady([:]) }
    func engine(_ engine: MPVPlayerEngine, didChangePictureInPicture isActive: Bool) { onPictureInPictureChange(["isActive": isActive]) }
    func engine(_ engine: MPVPlayerEngine, didFailWithError message: String) { onError(["error": message]) }
    func engine(_ engine: MPVPlayerEngine, didDetectHDRMode mode: HDRMode, fps: Double) {
        #if os(tvOS)
        setDisplayCriteria(for: mode, fps: Float(fps))
        #endif
    }
    func engineDidReachEnd(_ engine: MPVPlayerEngine) { onEnd([:]) }
}

#if os(tvOS)
import AVKit
import CoreMedia

extension MpvPlayerView {
    private func makeHDRFormat(_ mode: HDRMode) -> CMFormatDescription? {
        if case .sdr = mode { return nil }
        var extensions: [String: Any] = [kCMFormatDescriptionExtension_FullRangeVideo as String: true]
        extensions[kCMFormatDescriptionExtension_ColorPrimaries as String] = kCMFormatDescriptionColorPrimaries_ITU_R_2020
        if case .hlg = mode {
            extensions[kCMFormatDescriptionExtension_TransferFunction as String] = kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG
        } else {
            extensions[kCMFormatDescriptionExtension_TransferFunction as String] = kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
        }
        extensions[kCMFormatDescriptionExtension_YCbCrMatrix as String] = kCMFormatDescriptionYCbCrMatrix_ITU_R_2020
        var out: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: kCMVideoCodecType_HEVC, width: 3840, height: 2160, extensions: extensions as CFDictionary, formatDescriptionOut: &out)
        return status == noErr ? out : nil
    }
    private func setDisplayCriteria(for mode: HDRMode, fps: Float) {
        guard #available(tvOS 17.0, *), let window else { return }
        guard let format = makeHDRFormat(mode) else { window.avDisplayManager.preferredDisplayCriteria = nil; return }
        window.avDisplayManager.preferredDisplayCriteria = AVDisplayCriteria(refreshRate: fps, formatDescription: format)
    }
}
#endif
