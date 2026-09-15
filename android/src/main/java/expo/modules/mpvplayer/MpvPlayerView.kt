package expo.modules.mpvplayer

import android.content.Context
import android.graphics.Color
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.ViewGroup
import expo.modules.kotlin.AppContext
import expo.modules.kotlin.viewevent.EventDispatcher
import expo.modules.kotlin.views.ExpoView
import expo.modules.mpvplayer.nativeplayer.engine.PlayerEngine
import expo.modules.mpvplayer.nativeplayer.engine.VideoLoadConfig

class MpvPlayerView(context: Context, appContext: AppContext) : ExpoView(context, appContext),
    PlayerEngine.Delegate, SurfaceHolder.Callback {

    val onLoad by EventDispatcher()
    val onPlaybackStateChange by EventDispatcher()
    val onProgress by EventDispatcher()
    val onError by EventDispatcher()
    val onTracksReady by EventDispatcher()
    val onPictureInPictureChange by EventDispatcher()

    private val surfaceView = SurfaceView(context)
    private var renderer: MPVLayerRenderer? = null
    private var rendererVoDriver: String? = null
    private val pipController = PiPController(context, appContext)
    private var surfaceReady = false
    private var rendererStarted = false
    private var pendingConfig: VideoLoadConfig? = null
    private var currentUrl: String? = null
    private var currentLoop = false
    private var cachedPosition = 0.0
    private var cachedDuration = 0.0
    private var zoomed = false

    init {
        setBackgroundColor(Color.BLACK)
        surfaceView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        surfaceView.holder.addCallback(this)
        addView(surfaceView)
        pipController.setPlayerView(surfaceView)
        pipController.delegate = object : PiPController.Delegate {
            override fun onPlay() = play()
            override fun onPause() = pause()
            override fun onSeekBy(seconds: Double) = seekBy(seconds)
            override fun onPictureInPictureModeChanged(isInPiP: Boolean) {
                onPictureInPictureChange(mapOf("isActive" to isInPiP))
            }
        }
    }

    private fun ensureRendererStarted(voDriver: String?) {
        if (rendererStarted) { loadPending(); return }
        val wanted = voDriver ?: "gpu-next"
        if (renderer == null || rendererVoDriver != wanted) {
            renderer?.stop()
            renderer = MPVLayerRenderer(context, wanted)
            rendererVoDriver = wanted
        }
        renderer?.delegate = this
        renderer?.start(PlayerEngine.Owner.EMBEDDED_VIEW) {
            rendererStarted = true
            surfaceView.holder.surface?.takeIf { it.isValid }?.let { renderer?.attachSurface(it) }
            if (surfaceView.width > 0 && surfaceView.height > 0) renderer?.updateSurfaceSize(surfaceView.width, surfaceView.height)
            loadPending()
        }
    }

    private fun loadPending() {
        if (!rendererStarted || !surfaceReady) return
        pendingConfig?.let { config ->
            currentUrl = config.url
            currentLoop = config.loop
            renderer?.load(config)
            if (config.autoplay) play()
            onLoad(mapOf("url" to config.url))
        }
        pendingConfig = null
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        surfaceReady = true
        if (rendererStarted) renderer?.attachSurface(holder.surface)
        pendingConfig?.let { ensureRendererStarted(it.voDriver) }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (width > 0 && height > 0) renderer?.updateSurfaceSize(width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        surfaceReady = false
        renderer?.detachSurface()
    }

    fun loadVideo(config: VideoLoadConfig) {
        if (currentUrl == config.url && currentLoop == config.loop) return
        pendingConfig = config
        if (surfaceReady) ensureRendererStarted(config.voDriver)
    }

    fun play() { renderer?.play(); pipController.setPlaybackRate(1.0) }
    fun pause() { renderer?.pause(); pipController.setPlaybackRate(0.0) }
    fun destroy() {
        renderer?.stop()
        rendererStarted = false
        pendingConfig = null
        currentUrl = null
    }
    fun seekTo(position: Double) = renderer?.seekTo(position) ?: Unit
    fun seekBy(offset: Double) = renderer?.seekBy(offset) ?: Unit
    fun setSpeed(speed: Double) = renderer?.setSpeed(speed) ?: Unit
    fun setMute(muted: Boolean) = renderer?.setMute(muted) ?: Unit
    fun getSpeed(): Double = renderer?.getSpeed() ?: 1.0
    fun isPaused(): Boolean = renderer?.isPausedState ?: true
    fun getCurrentPosition(): Double = cachedPosition
    fun getDuration(): Double = cachedDuration

    fun startPictureInPicture() = pipController.startPictureInPicture()
    fun stopPictureInPicture() = pipController.stopPictureInPicture()
    fun isPictureInPictureSupported(): Boolean = pipController.isPictureInPictureSupported()
    fun isPictureInPictureActive(): Boolean = pipController.isPictureInPictureActive()

    fun getSubtitleTracks(): List<Map<String, Any>> = renderer?.getSubtitleTracks() ?: emptyList()
    fun setSubtitleTrack(trackId: Int) = renderer?.setSubtitleTrack(trackId) ?: Unit
    fun disableSubtitles() = renderer?.disableSubtitles() ?: Unit
    fun getCurrentSubtitleTrack(): Int = renderer?.getCurrentSubtitleTrack() ?: 0
    fun addSubtitleFile(url: String, select: Boolean = true) = renderer?.addSubtitleFile(url, select) ?: Unit
    fun setSubtitlePosition(position: Int) = renderer?.setSubtitlePosition(position) ?: Unit
    fun setSubtitleScale(scale: Double) = renderer?.setSubtitleScale(scale) ?: Unit
    fun setSubtitleDelay(seconds: Double) = renderer?.setSubtitleDelay(seconds) ?: Unit
    fun setSubtitleMarginY(margin: Int) = renderer?.setSubtitleMarginY(margin) ?: Unit
    fun setSubtitleAlignX(alignment: String) = renderer?.setSubtitleAlignX(alignment) ?: Unit
    fun setSubtitleAlignY(alignment: String) = renderer?.setSubtitleAlignY(alignment) ?: Unit
    fun setSubtitleStyle(config: Map<String, Any>) = renderer?.setSubtitleStyle(config) ?: Unit
    fun setSubtitleFontSize(size: Int) = renderer?.setSubtitleFontSize(size) ?: Unit
    fun setSubtitleBorderStyle(style: String) = renderer?.setSubtitleBorderStyle(style) ?: Unit
    fun setSubtitleBackgroundColor(color: String) = renderer?.setSubtitleBackgroundColor(color) ?: Unit
    fun setSubtitleAssOverride(mode: String) = renderer?.setSubtitleAssOverride(mode) ?: Unit
    fun getAudioTracks(): List<Map<String, Any>> = renderer?.getAudioTracks() ?: emptyList()
    fun setAudioTrack(trackId: Int) = renderer?.setAudioTrack(trackId) ?: Unit
    fun getCurrentAudioTrack(): Int = renderer?.getCurrentAudioTrack() ?: 0
    fun setZoomedToFill(value: Boolean) { zoomed = value; renderer?.setZoomedToFill(value) }
    fun isZoomedToFill(): Boolean = zoomed
    fun getTechnicalInfo(): Map<String, Any> = renderer?.getTechnicalInfo() ?: emptyMap()

    override fun onPositionChanged(position: Double, duration: Double, cacheSeconds: Double) {
        cachedPosition = position; cachedDuration = duration
        if (pipController.isPictureInPictureActive()) pipController.setCurrentTime(position, duration)
        onProgress(mapOf("position" to position, "duration" to duration, "progress" to if (duration > 0) position / duration else 0.0, "cacheSeconds" to cacheSeconds))
    }
    override fun onPauseChanged(isPaused: Boolean) {
        pipController.setPlaybackRate(if (isPaused) 0.0 else 1.0)
        onPlaybackStateChange(mapOf("isPaused" to isPaused, "isPlaying" to !isPaused))
    }
    override fun onLoadingChanged(isLoading: Boolean) = onPlaybackStateChange(mapOf("isLoading" to isLoading))
    override fun onReadyToSeek() = onPlaybackStateChange(mapOf("isReadyToSeek" to true))
    override fun onTracksReady() = onTracksReady(emptyMap<String, Any>())
    override fun onError(message: String) = onError(mapOf("error" to message))
    override fun onVideoDimensionsChanged(width: Int, height: Int) = pipController.setVideoDimensions(width, height)

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        pipController.stopPictureInPicture()
        renderer?.stop()
        renderer?.delegate = null
    }
}
