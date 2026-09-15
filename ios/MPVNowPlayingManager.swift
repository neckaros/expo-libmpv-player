import AVFoundation
import Foundation
import MediaPlayer
import UIKit

final class MPVNowPlayingManager {
    static let shared = MPVNowPlayingManager()
    private var title: String?
    private var artist: String?
    private var albumTitle: String?
    private var artwork: MPMediaItemArtwork?
    private var duration: TimeInterval = 0
    private var position: TimeInterval = 0
    private var playing = false
    private var commandsSetup = false
    private var artworkTask: URLSessionDataTask?
    private init() {}

    func activateAudioSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .moviePlayback)
            try s.setActive(true)
        } catch { Logger.shared.log("Audio session: \(error)", type: "Warn") }
    }

    func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func setupRemoteCommands(
        playHandler: @escaping () -> Void,
        pauseHandler: @escaping () -> Void,
        toggleHandler: @escaping () -> Void,
        seekHandler: @escaping (TimeInterval) -> Void,
        skipForward: @escaping (TimeInterval) -> Void,
        skipBackward: @escaping (TimeInterval) -> Void
    ) {
        guard !commandsSetup else { return }
        commandsSetup = true
        #if os(iOS)
        DispatchQueue.main.async { UIApplication.shared.beginReceivingRemoteControlEvents() }
        #endif
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { _ in playHandler(); return .success }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { _ in pauseHandler(); return .success }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { _ in toggleHandler(); return .success }
        cc.skipForwardCommand.isEnabled = true
        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.addTarget { e in if let e = e as? MPSkipIntervalCommandEvent { skipForward(e.interval) }; return .success }
        cc.skipBackwardCommand.isEnabled = true
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.addTarget { e in if let e = e as? MPSkipIntervalCommandEvent { skipBackward(e.interval) }; return .success }
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { e in if let e = e as? MPChangePlaybackPositionCommandEvent { seekHandler(e.positionTime) }; return .success }
    }

    func cleanupRemoteCommands() {
        guard commandsSetup else { return }
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.removeTarget(nil); cc.pauseCommand.removeTarget(nil); cc.togglePlayPauseCommand.removeTarget(nil)
        cc.skipForwardCommand.removeTarget(nil); cc.skipBackwardCommand.removeTarget(nil); cc.changePlaybackPositionCommand.removeTarget(nil)
        #if os(iOS)
        DispatchQueue.main.async { UIApplication.shared.endReceivingRemoteControlEvents() }
        #endif
        commandsSetup = false
    }

    func setMetadata(title: String?, artist: String?, albumTitle: String?, artworkUrl: String?, artworkHeaders: [String: String]? = nil) {
        self.title = title; self.artist = artist; self.albumTitle = albumTitle
        artworkTask?.cancel()
        if let s = artworkUrl, let url = URL(string: s) {
            var req = URLRequest(url: url)
            artworkHeaders?.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
            artworkTask = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                self?.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                DispatchQueue.main.async { self?.refresh() }
            }
            artworkTask?.resume()
        }
        refresh()
    }

    func updatePlayback(position: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        self.position = position; self.duration = duration; self.playing = isPlaying; refresh()
    }

    func clear() {
        artworkTask?.cancel(); title = nil; artist = nil; albumTitle = nil; artwork = nil
        duration = 0; position = 0; playing = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func refresh() {
        guard duration > 0 else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        if let title { info[MPMediaItemPropertyTitle] = title }
        if let artist { info[MPMediaItemPropertyArtist] = artist }
        if let albumTitle { info[MPMediaItemPropertyAlbumTitle] = albumTitle }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
