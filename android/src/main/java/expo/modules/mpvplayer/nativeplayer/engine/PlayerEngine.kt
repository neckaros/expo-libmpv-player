package expo.modules.mpvplayer.nativeplayer.engine

import android.view.Surface
import android.view.SurfaceView
import android.view.View

data class VideoLoadConfig(
    val url: String,
    val headers: Map<String, String>? = null,
    val externalSubtitles: List<String>? = null,
    val startPosition: Double? = null,
    val autoplay: Boolean = true,
    val initialSubtitleId: Int? = null,
    val initialAudioId: Int? = null,
    val loop: Boolean = false,
    val voDriver: String? = null,
    val cacheEnabled: String? = null,
    val cacheSeconds: Int? = null,
    val demuxerMaxBytes: Int? = null,
    val demuxerMaxBackBytes: Int? = null,
    val cachePause: Boolean? = null,
    val cachePauseInitial: Boolean? = null,
    val cachePauseWaitSeconds: Double? = null,
)

interface PlayerEngine {
    enum class Owner { EMBEDDED_VIEW, NATIVE_SESSION }
    interface Delegate {
        fun onPositionChanged(position: Double, duration: Double, cacheSeconds: Double)
        fun onPauseChanged(isPaused: Boolean)
        fun onLoadingChanged(isLoading: Boolean)
        fun onReadyToSeek()
        fun onTracksReady()
        fun onError(message: String)
        fun onVideoDimensionsChanged(width: Int, height: Int)
        fun onPlaybackEnded() {}
        fun onChaptersChanged(chapters: List<Map<String, Any>>) {}
        fun onHDRModeDetected(isHdr: Boolean, fps: Double) {}
    }
    var delegate: Delegate?
    val subtitleOverlay: View?
    fun start(owner: Owner, onStarted: () -> Unit)
    fun stop()
    fun attachSurfaceView(surfaceView: SurfaceView)
    fun detachSurface()
    fun updateSurfaceSize(width: Int, height: Int)
    fun isVideoOutputBroken(): Boolean
    var playbackResumeIntent: Boolean
    fun recoverVideoOutput(surface: Surface?)
    fun load(config: VideoLoadConfig)
    fun reloadCurrentItem()
    fun play(); fun pause(); fun togglePause()
    fun seekTo(seconds: Double); fun seekBy(seconds: Double)
    fun setSpeed(speed: Double); fun getSpeed(): Double
    fun setMute(muted: Boolean)
    fun getChapters(): List<Map<String, Any>>
    fun getSubtitleTracks(): List<Map<String, Any>>
    fun setSubtitleTrack(trackId: Int); fun disableSubtitles(); fun getCurrentSubtitleTrack(): Int
    fun addSubtitleFile(url: String, select: Boolean)
    fun getAudioTracks(): List<Map<String, Any>>; fun setAudioTrack(trackId: Int); fun getCurrentAudioTrack(): Int
    fun setSubtitlePosition(position: Int); fun setSubtitleScale(scale: Double); fun setSubtitleDelay(seconds: Double)
    fun setSubtitleMarginY(margin: Int); fun setSubtitleUseMargins(enabled: Boolean); fun setSubtitleScaleWithWindow(enabled: Boolean)
    fun setSubtitleAlignX(alignment: String); fun setSubtitleAlignY(alignment: String); fun setSubtitleStyle(config: Map<String, Any>)
    fun setSubtitleFontSize(size: Int); fun setSubtitleBorderStyle(style: String); fun setSubtitleBackgroundColor(color: String)
    fun setSubtitleAssOverride(mode: String)
    fun setAudioDelay(seconds: Double); fun setVolumeBoost(percent: Int); fun setDialogueBoost(enabled: Boolean); fun setMonoDownmix(enabled: Boolean)
    fun setZoomedToFill(zoomed: Boolean)
    fun getTechnicalInfo(): Map<String, Any>
    val videoWidth: Int; val videoHeight: Int; val isPausedState: Boolean; val currentPosition: Double; val duration: Double; val isTv: Boolean
}
