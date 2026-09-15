import AVFoundation
import AVKit

protocol PiPControllerDelegate: AnyObject {
    func pipController(_ controller: PiPController, willStartPictureInPicture: Bool)
    func pipController(_ controller: PiPController, didStartPictureInPicture: Bool)
    func pipController(_ controller: PiPController, willStopPictureInPicture: Bool)
    func pipController(_ controller: PiPController, didStopPictureInPicture: Bool)
    func pipController(_ controller: PiPController, restoreUserInterfaceForPictureInPictureStop completionHandler: @escaping (Bool) -> Void)
    func pipControllerPlay(_ controller: PiPController)
    func pipControllerPause(_ controller: PiPController)
    func pipController(_ controller: PiPController, skipByInterval interval: CMTime)
    func pipControllerIsPlaying(_ controller: PiPController) -> Bool
    func pipControllerDuration(_ controller: PiPController) -> Double
    func pipControllerCurrentPosition(_ controller: PiPController) -> Double
}

final class PiPController: NSObject {
    private static weak var automaticStartOwner: PiPController?
    private var controller: AVPictureInPictureController?
    private weak var displayLayer: AVSampleBufferDisplayLayer?
    private var timebase: CMTimebase?
    weak var delegate: PiPControllerDelegate?

    var isPictureInPictureSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
    var isPictureInPictureActive: Bool { controller?.isPictureInPictureActive ?? false }

    init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer) {
        displayLayer = sampleBufferDisplayLayer
        super.init()
        var tb: CMTimebase?
        if CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &tb) == noErr {
            timebase = tb
            if let tb { CMTimebaseSetTime(tb, time: .zero); CMTimebaseSetRate(tb, rate: 0); sampleBufferDisplayLayer.controlTimebase = tb }
        }
        guard isPictureInPictureSupported else { return }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferDisplayLayer, playbackDelegate: self)
        controller = AVPictureInPictureController(contentSource: source)
        controller?.delegate = self
        controller?.requiresLinearPlayback = false
    }

    func setAutoStartEnabled(_ enabled: Bool) {
        #if !os(tvOS)
        guard let controller else { return }
        if enabled {
            Self.automaticStartOwner?.controller?.canStartPictureInPictureAutomaticallyFromInline = false
            Self.automaticStartOwner = self
        } else if Self.automaticStartOwner === self { Self.automaticStartOwner = nil }
        controller.canStartPictureInPictureAutomaticallyFromInline = enabled
        #endif
    }

    func startPictureInPicture() {
        guard let controller else { return }
        guard controller.isPictureInPicturePossible else {
            Logger.shared.log("PiP start refused: isPictureInPicturePossible=false", type: "Warn")
            return
        }
        controller.startPictureInPicture()
    }
    func stopPictureInPicture() { controller?.stopPictureInPicture() }
    func updatePlaybackState() { if isPictureInPictureActive { controller?.invalidatePlaybackState() } }
    func setCurrentTimeFromSeconds(_ seconds: Double, duration: Double) {
        guard seconds >= 0, let timebase else { return }
        CMTimebaseSetTime(timebase, time: CMTime(seconds: seconds, preferredTimescale: 1000))
        updatePlaybackState()
    }
    func setPlaybackRate(_ rate: Float) { if let timebase { CMTimebaseSetRate(timebase, rate: Float64(rate)) } }

    deinit {
        if let timebase { CMTimebaseSetRate(timebase, rate: 0) }
        displayLayer?.controlTimebase = nil
        controller?.delegate = nil
    }
}

extension PiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { delegate?.pipController(self, willStartPictureInPicture: true) }
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { delegate?.pipController(self, didStartPictureInPicture: true) }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Logger.shared.log("PiP failed: \(error.localizedDescription)", type: "Error")
        delegate?.pipController(self, didStartPictureInPicture: false)
    }
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { delegate?.pipController(self, willStopPictureInPicture: true) }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { delegate?.pipController(self, didStopPictureInPicture: true) }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        delegate?.pipController(self, restoreUserInterfaceForPictureInPictureStop: completionHandler)
    }
}

extension PiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        playing ? delegate?.pipControllerPlay(self) : delegate?.pipControllerPause(self)
    }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        delegate?.pipController(self, skipByInterval: skipInterval); completionHandler()
    }
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        let duration = delegate?.pipControllerDuration(self) ?? 0
        return duration > 0 ? CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 1000)) : CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { !(delegate?.pipControllerIsPlaying(self) ?? false) }
}
