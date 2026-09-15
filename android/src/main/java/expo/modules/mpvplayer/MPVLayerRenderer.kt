package expo.modules.mpvplayer

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.system.Os
import android.util.Log
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import expo.modules.mpvplayer.nativeplayer.MpvOwnership
import expo.modules.mpvplayer.nativeplayer.engine.PlayerEngine
import expo.modules.mpvplayer.nativeplayer.engine.VideoLoadConfig
import java.io.File
import java.util.Locale

private fun normalizeVideoDimensions(width: Int, height: Int, rotation: Int): Pair<Int, Int> {
    val r = ((rotation % 360) + 360) % 360
    return if (r == 90 || r == 270) height to width else width to height
}

private fun subtitleFont(font: String): String = when (font) {
    "System" -> "sans-serif"
    "sans-serif" -> "Roboto"
    "serif" -> "Noto Serif"
    "monospace" -> "Droid Sans Mono"
    else -> font
}

class MPVLayerRenderer(
    private val context: Context,
    private val voDriver: String = "gpu-next",
) : PlayerEngine, MPVLib.EventObserver {
    companion object {
        private const val TAG = "MPVLayerRenderer"
        private const val MPV_FORMAT_FLAG = 3
        private const val MPV_FORMAT_INT64 = 4
        private const val MPV_FORMAT_DOUBLE = 5
    }

    override var delegate: PlayerEngine.Delegate? = null
    override val subtitleOverlay: View? = null
    override val isTv: Boolean = DeviceKind.isTelevision(context)
    override var playbackResumeIntent: Boolean = false

    private val main = Handler(Looper.getMainLooper())
    private var mpv: MPVLib? = null
    private var surface: Surface? = null
    private var running = false
    private var pendingToken: Any? = null
    private var activeToken: Any? = null
    private var currentConfig: VideoLoadConfig? = null
    private var pendingExternalSubtitles = emptyList<String>()
    @Volatile private var activeExternalSubtitles = emptyList<String>()
    @Volatile private var initialSubtitleId: Int? = null
    @Volatile private var initialAudioId: Int? = null
    private var muted = false
    private var zoomed = false
    @Volatile private var cachedCacheSeconds = 0.0
    private var rotation = 0
    @Volatile private var _videoWidth = 0
    @Volatile private var _videoHeight = 0
    @Volatile private var _position = 0.0
    @Volatile private var _duration = 0.0
    @Volatile private var _paused = true
    private var speed = 1.0
    @Volatile private var loading = false
    @Volatile private var seeking = false
    private var lastProgressMs = 0L

    override val videoWidth: Int get() = _videoWidth
    override val videoHeight: Int get() = _videoHeight
    override val isPausedState: Boolean get() = _paused
    override val currentPosition: Double get() = _position
    override val duration: Double get() = _duration

    private fun isEmulator(): Boolean {
        val hardware = Build.HARDWARE.lowercase()
        return hardware == "goldfish" || hardware == "ranchu" ||
            Build.PRODUCT == "sdk" || Build.PRODUCT.startsWith("sdk_") ||
            Build.FINGERPRINT.startsWith("generic") || Build.FINGERPRINT.contains("emulator", true)
    }

    override fun start(owner: PlayerEngine.Owner, onStarted: () -> Unit) {
        if (running || pendingToken != null) return
        val token = Any()
        pendingToken = token
        val mpvOwner = if (owner == PlayerEngine.Owner.EMBEDDED_VIEW) MpvOwnership.Owner.EMBEDDED_VIEW else MpvOwnership.Owner.NATIVE_SESSION
        MpvOwnership.claim(mpvOwner, token) {
            main.post {
                if (pendingToken !== token) {
                    MpvOwnership.release(token)
                    return@post
                }
                pendingToken = null
                activeToken = token
                try {
                    val instance = MPVLib.create(context)
                    mpv = instance
                    instance.addObserver(this)

                    // Give fontconfig stable writable config/cache locations.
                    // libmpv 1.0 otherwise re-scans system fonts repeatedly on some
                    // devices, which is costly during subtitle/seek activity.
                    val mpvDir = File(context.getExternalFilesDir(null) ?: context.filesDir, "mpv")
                    if (!mpvDir.exists()) mpvDir.mkdirs()
                    try {
                        val cacheDir = context.cacheDir.absolutePath
                        val configDir = (context.getExternalFilesDir(null) ?: context.filesDir).absolutePath
                        Os.setenv("XDG_CACHE_HOME", cacheDir, true)
                        Os.setenv("XDG_CONFIG_HOME", configDir, true)
                        Os.setenv("HOME", configDir, true)
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not configure fontconfig environment: ${e.message}")
                    }
                    instance.setOptionString("config", "yes")
                    instance.setOptionString("config-dir", mpvDir.path)

                    instance.setOptionString("vo", voDriver)
                    instance.setOptionString("gpu-context", "android")
                    instance.setOptionString("opengl-es", "yes")
                    instance.setOptionString("hwdec-codecs", "h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1")
                    instance.setOptionString("cache-pause-initial", "yes")
                    when {
                        isEmulator() -> instance.setOptionString("hwdec", "no")
                        isTv -> {
                            // Zero-copy mediacodec wedges some low-end TV SoCs;
                            // copy mode is more robust and matches Lunarr 1.1.1.
                            instance.setOptionString("hwdec", "mediacodec-copy")
                            instance.setOptionString("profile", "fast")
                            instance.setOptionString("demuxer-seekable-cache", "no")
                            instance.setOptionString("audio-buffer", "0.5")
                        }
                        else -> instance.setOptionString("hwdec", "mediacodec-copy")
                    }
                    instance.setOptionString("hr-seek", "no")
                    instance.setOptionString("hr-seek-framedrop", "yes")
                    instance.setOptionString("sub-scale-with-window", "no")
                    instance.setOptionString("sub-use-margins", "no")
                    instance.setOptionString("subs-match-os-language", "yes")
                    instance.setOptionString("subs-fallback", "yes")
                    instance.setOptionString("sub-vsfilter-bidi-compat", "yes")
                    instance.setOptionString("keep-open", "always")
                    instance.setOptionString("force-window", "no")
                    instance.initialize()
                    if (muted) instance.setPropertyBoolean("mute", true)
                    observeProperties()
                    running = true
                    surface?.takeIf { it.isValid }?.let(::attachSurface)
                    onStarted()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start mpv", e)
                    delegate?.onError("Failed to start renderer: ${e.message}")
                    activeToken?.let(MpvOwnership::release)
                    activeToken = null
                }
            }
        }
    }

    override fun stop() {
        val p = pendingToken
        pendingToken = null
        p?.let(MpvOwnership::cancel)
        val token = activeToken
        activeToken = null
        val instance = mpv
        mpv = null
        running = false
        currentConfig = null
        pendingExternalSubtitles = emptyList()
        activeExternalSubtitles = emptyList()
        initialSubtitleId = null
        initialAudioId = null
        _position = 0.0
        _duration = 0.0
        cachedCacheSeconds = 0.0
        if (instance == null) {
            token?.let(MpvOwnership::release)
            return
        }
        Thread {
            try { instance.setOptionString("force-window", "no") } catch (_: Exception) {}
            try { instance.command(arrayOf("stop")) } catch (_: Exception) {}
            try { instance.removeObserver(this) } catch (_: Exception) {}
            try { instance.detachSurface() } catch (_: Exception) {}
            token?.let(MpvOwnership::release)
        }.also { it.isDaemon = true }.start()
    }

    override fun attachSurfaceView(surfaceView: SurfaceView) = attachSurface(surfaceView.holder.surface)

    fun attachSurface(surface: Surface) {
        this.surface = surface
        if (running) {
            mpv?.attachSurface(surface)
            mpv?.setOptionString("force-window", "yes")
        }
    }

    override fun detachSurface() {
        surface = null
        if (running) mpv?.detachSurface()
    }

    override fun updateSurfaceSize(width: Int, height: Int) {
        if (running && width > 0 && height > 0) mpv?.setPropertyString("android-surface-size", "${width}x$height")
    }

    override fun isVideoOutputBroken(): Boolean {
        if (!running) return false
        return try {
            val count = mpv?.getPropertyInt("track-list/count") ?: 0
            val hasVideo = (0 until count).any { mpv?.getPropertyString("track-list/$it/type") == "video" }
            hasVideo && (mpv?.getPropertyString("vid") == "no" || mpv?.getPropertyBoolean("vo-configured") == false)
        } catch (_: Exception) { false }
    }

    override fun recoverVideoOutput(surface: Surface?) {
        val config = currentConfig ?: return
        surface?.takeIf { it.isValid }?.let(::attachSurface)
        val aid = getCurrentAudioTrack()
        val sid = getCurrentSubtitleTrack()
        load(config.copy(
            startPosition = _position,
            initialAudioId = aid,
            initialSubtitleId = sid,
            externalSubtitles = activeExternalSubtitles,
        ))
        if (playbackResumeIntent) play() else pause()
    }

    override fun load(config: VideoLoadConfig) {
        currentConfig = config
        pendingExternalSubtitles = config.externalSubtitles ?: emptyList()
        activeExternalSubtitles = pendingExternalSubtitles
        initialSubtitleId = config.initialSubtitleId
        initialAudioId = config.initialAudioId
        _videoWidth = 0; _videoHeight = 0; rotation = 0
        loading = true
        main.post { delegate?.onLoadingChanged(true) }
        mpv?.command(arrayOf("stop"))
        updateHttpHeaders(config.headers)
        mpv?.setPropertyString("loop-file", if (config.loop) "inf" else "no")
        config.cacheEnabled?.let { mpv?.setPropertyString("cache", it) }
        config.cacheSeconds?.let { mpv?.setPropertyString("cache-secs", it.toString()) }
        config.demuxerMaxBytes?.let { mpv?.setPropertyString("demuxer-max-bytes", "${it}MiB") }
        config.demuxerMaxBackBytes?.let { mpv?.setPropertyString("demuxer-max-back-bytes", "${it}MiB") }
        val pos = config.startPosition ?: 0.0
        mpv?.setPropertyString("start", if (pos > 0) String.format(Locale.US, "%.2f", pos) else "0")
        mpv?.command(arrayOf("loadfile", config.url, "replace"))
    }

    override fun reloadCurrentItem() { currentConfig?.let(::load) }

    private fun updateHttpHeaders(headers: Map<String, String>?) {
        mpv?.setPropertyString("http-header-fields", "")
        if (!headers.isNullOrEmpty()) {
            mpv?.setPropertyString("http-header-fields", headers.entries.joinToString(",") { "${it.key}: ${it.value}" })
        }
    }

    private fun observeProperties() {
        mpv?.observeProperty("duration", MPV_FORMAT_DOUBLE)
        mpv?.observeProperty("time-pos", MPV_FORMAT_DOUBLE)
        mpv?.observeProperty("pause", MPV_FORMAT_FLAG)
        mpv?.observeProperty("track-list/count", MPV_FORMAT_INT64)
        mpv?.observeProperty("paused-for-cache", MPV_FORMAT_FLAG)
        mpv?.observeProperty("demuxer-cache-duration", MPV_FORMAT_DOUBLE)
        mpv?.observeProperty("eof-reached", MPV_FORMAT_FLAG)
        mpv?.observeProperty("video-params/w", MPV_FORMAT_INT64)
        mpv?.observeProperty("video-params/h", MPV_FORMAT_INT64)
        mpv?.observeProperty("video-params/rotate", MPV_FORMAT_INT64)
    }

    override fun play() { mpv?.setPropertyBoolean("pause", false) }
    override fun pause() { mpv?.setPropertyBoolean("pause", true) }
    override fun togglePause() { if (_paused) play() else pause() }
    override fun seekTo(seconds: Double) {
        _position = maxOf(0.0, seconds)
        mpv?.command(arrayOf("seek", _position.toString(), "absolute"))
    }
    override fun seekBy(seconds: Double) {
        _position = maxOf(0.0, _position + seconds)
        mpv?.command(arrayOf("seek", seconds.toString(), "relative"))
    }
    override fun setSpeed(speed: Double) { this.speed = speed; mpv?.setPropertyDouble("speed", speed) }
    override fun getSpeed(): Double = mpv?.getPropertyDouble("speed") ?: speed
    override fun setMute(muted: Boolean) { this.muted = muted; mpv?.setPropertyBoolean("mute", muted) }

    override fun getChapters(): List<Map<String, Any>> {
        val count = mpv?.getPropertyInt("chapter-list/count") ?: 0
        return (0 until count).map { i ->
            mapOf("name" to (mpv?.getPropertyString("chapter-list/$i/title") ?: ""), "startSec" to (mpv?.getPropertyDouble("chapter-list/$i/time") ?: 0.0))
        }
    }

    override fun getSubtitleTracks(): List<Map<String, Any>> = tracksOfType("sub")
    override fun getAudioTracks(): List<Map<String, Any>> = tracksOfType("audio")

    private fun tracksOfType(type: String): List<Map<String, Any>> {
        val count = mpv?.getPropertyInt("track-list/count") ?: 0
        val result = mutableListOf<Map<String, Any>>()
        for (i in 0 until count) {
            if (mpv?.getPropertyString("track-list/$i/type") != type) continue
            val id = mpv?.getPropertyInt("track-list/$i/id") ?: continue
            val row = mutableMapOf<String, Any>("id" to id)
            mpv?.getPropertyString("track-list/$i/title")?.let { row["title"] = it }
            mpv?.getPropertyString("track-list/$i/lang")?.let { row["lang"] = it }
            mpv?.getPropertyString("track-list/$i/codec")?.let { row["codec"] = it }
            row["selected"] = mpv?.getPropertyBoolean("track-list/$i/selected") ?: false
            if (type == "sub") {
                row["external"] = mpv?.getPropertyBoolean("track-list/$i/external") ?: false
                mpv?.getPropertyString("track-list/$i/external-filename")?.let { row["externalFilename"] = it }
                mpv?.getPropertyInt("track-list/$i/ff-index")?.let { row["ffIndex"] = it }
            } else {
                mpv?.getPropertyInt("track-list/$i/audio-channels")?.takeIf { it > 0 }?.let { row["channels"] = it }
            }
            result.add(row)
        }
        return result
    }

    override fun setSubtitleTrack(trackId: Int) {
        if (trackId < 0) mpv?.setPropertyString("sid", "no") else mpv?.setPropertyInt("sid", trackId)
        applyBidiModeFor(trackId)
    }

    private fun applyBidiModeFor(trackId: Int) {
        val codec = if (trackId >= 0) subtitleCodecFor(trackId) else null
        val isAss = codec == "ass" || codec == "ssa"
        mpv?.setPropertyString("sub-ass-style-overrides", if (isAss) "Encoding=-1" else "")
    }

    private fun subtitleCodecFor(trackId: Int): String? {
        val count = mpv?.getPropertyInt("track-list/count") ?: return null
        for (i in 0 until count) {
            if (mpv?.getPropertyString("track-list/$i/type") != "sub") continue
            if (mpv?.getPropertyInt("track-list/$i/id") != trackId) continue
            return mpv?.getPropertyString("track-list/$i/codec")
        }
        return null
    }

    override fun disableSubtitles() {
        mpv?.setPropertyString("sid", "no")
        applyBidiModeFor(-1)
    }
    override fun getCurrentSubtitleTrack(): Int = mpv?.getPropertyInt("sid") ?: 0
    override fun addSubtitleFile(url: String, select: Boolean) {
        mpv?.command(arrayOf("sub-add", url, if (select) "select" else "cached"))
        if (select) applyBidiModeFor(mpv?.getPropertyInt("sid") ?: -1)
        if (url !in activeExternalSubtitles) activeExternalSubtitles = activeExternalSubtitles + url
    }
    override fun setAudioTrack(trackId: Int) { mpv?.setPropertyInt("aid", trackId) }
    override fun getCurrentAudioTrack(): Int = mpv?.getPropertyInt("aid") ?: 0

    override fun setSubtitlePosition(position: Int) { mpv?.setPropertyInt("sub-pos", position) }
    override fun setSubtitleScale(scale: Double) { mpv?.setPropertyDouble("sub-scale", scale) }
    override fun setSubtitleDelay(seconds: Double) { mpv?.setPropertyDouble("sub-delay", seconds) }
    override fun setSubtitleMarginY(margin: Int) { mpv?.setPropertyInt("sub-margin-y", margin) }
    override fun setSubtitleUseMargins(enabled: Boolean) { if (running) mpv?.setPropertyString("sub-use-margins", if (enabled) "yes" else "no") }
    override fun setSubtitleScaleWithWindow(enabled: Boolean) { if (running) mpv?.setPropertyString("sub-scale-with-window", if (enabled) "yes" else "no") }
    override fun setSubtitleAlignX(alignment: String) { mpv?.setPropertyString("sub-align-x", alignment) }
    override fun setSubtitleAlignY(alignment: String) { mpv?.setPropertyString("sub-align-y", alignment) }
    override fun setSubtitleFontSize(size: Int) { mpv?.setPropertyInt("sub-font-size", size) }
    override fun setSubtitleBorderStyle(style: String) { mpv?.setPropertyString("sub-border-style", style) }
    override fun setSubtitleBackgroundColor(color: String) { mpv?.setPropertyString("sub-back-color", color) }
    override fun setSubtitleAssOverride(mode: String) { mpv?.setPropertyString("sub-ass-override", if (mode == "no") "scale" else mode) }
    override fun setSubtitleStyle(config: Map<String, Any>) {
        (config["fontSize"] as? Number)?.let { setSubtitleFontSize(it.toInt()) }
        (config["color"] as? String)?.let { mpv?.setPropertyString("sub-color", it) }
        (config["font"] as? String)?.let { mpv?.setPropertyString("sub-font", subtitleFont(it)) }
        val background = config["background"] as? String
        if (background != null) {
            if (background.isEmpty()) {
                setSubtitleBorderStyle("outline-and-shadow")
                mpv?.setPropertyString("sub-shadow-offset", "1")
                mpv?.setPropertyString("sub-border-size", "3")
            } else {
                setSubtitleBackgroundColor(background)
                setSubtitleBorderStyle("background-box")
                mpv?.setPropertyString("sub-shadow-offset", ((config["backgroundPadding"] as? Number)?.toInt() ?: 12).toString())
                mpv?.setPropertyString("sub-border-size", "0")
            }
        }
    }

    override fun setAudioDelay(seconds: Double) { mpv?.setPropertyDouble("audio-delay", seconds) }
    override fun setVolumeBoost(percent: Int) {
        mpv?.setPropertyInt("volume-max", if (percent > 100) 200 else 130)
        mpv?.setPropertyInt("volume", percent)
    }
    override fun setDialogueBoost(enabled: Boolean) {
        if (enabled) {
            mpv?.command(arrayOf(
                "af", "add",
                "@dialogue-boost:lavfi=[equalizer=f=100:t=q:w=1.2:g=-6,equalizer=f=2800:t=q:w=1.2:g=4]"
            ))
        } else {
            mpv?.command(arrayOf("af", "remove", "@dialogue-boost"))
        }
    }
    override fun setMonoDownmix(enabled: Boolean) { mpv?.setPropertyString("audio-channels", if (enabled) "mono" else "auto-safe") }
    override fun setZoomedToFill(zoomed: Boolean) { this.zoomed = zoomed; mpv?.setPropertyDouble("panscan", if (zoomed) 1.0 else 0.0) }

    override fun getTechnicalInfo(): Map<String, Any> {
        val info = mutableMapOf<String, Any>()
        fun int(name: String, key: String = name) { mpv?.getPropertyInt(name)?.let { info[key] = it } }
        fun dbl(name: String, key: String = name) { mpv?.getPropertyDouble(name)?.let { info[key] = it } }
        fun str(name: String, key: String = name) { mpv?.getPropertyString(name)?.let { info[key] = it } }
        int("video-params/w", "videoWidth"); int("video-params/h", "videoHeight")
        str("video-format", "videoCodec"); str("audio-codec-name", "audioCodec")
        dbl("container-fps", "fps"); int("video-bitrate", "videoBitrate"); int("audio-bitrate", "audioBitrate")
        dbl("demuxer-cache-duration", "cacheSeconds"); int("frame-drop-count", "droppedFrames")
        str("vo", "voDriver"); str("hwdec-current", "hwdec"); dbl("estimated-vf-fps", "estimatedVfFps")
        str("video-params/gamma", "gamma"); str("video-params/primaries", "primaries")
        str("video-params/colormatrix", "colormatrix"); str("video-params/colorlevels", "colorlevels")
        str("video-params/pixelformat", "pixelformat")
        return info
    }

    override fun eventProperty(property: String) {}
    override fun eventProperty(property: String, value: String) {}
    override fun eventProperty(property: String, value: Long) {
        when (property) {
            "track-list/count" -> if (value > 0) main.post { delegate?.onTracksReady() }
            "video-params/w" -> { _videoWidth = value.toInt(); notifyDimensions() }
            "video-params/h" -> { _videoHeight = value.toInt(); notifyDimensions() }
            "video-params/rotate" -> { rotation = value.toInt(); notifyDimensions() }
        }
    }
    override fun eventProperty(property: String, value: Boolean) {
        when (property) {
            "pause" -> if (value != _paused) { _paused = value; main.post { delegate?.onPauseChanged(value) } }
            "paused-for-cache" -> if (value != loading) { loading = value; main.post { delegate?.onLoadingChanged(value) } }
            "eof-reached" -> if (value) main.post { delegate?.onPlaybackEnded() }
        }
    }
    override fun eventProperty(property: String, value: Double) {
        when (property) {
            "duration" -> { _duration = value; postProgress() }
            "time-pos" -> {
                _position = value
                val now = System.currentTimeMillis()
                if (seeking || now - lastProgressMs >= 1000) { lastProgressMs = now; postProgress() }
            }
            "demuxer-cache-duration" -> cachedCacheSeconds = value
        }
    }
    override fun event(eventId: Int) {
        when (eventId) {
            MPVLib.MPV_EVENT_FILE_LOADED -> {
                pendingExternalSubtitles.forEach { mpv?.command(arrayOf("sub-add", it, "auto")) }
                pendingExternalSubtitles = emptyList()
                initialAudioId?.takeIf { it > 0 }?.let(::setAudioTrack)
                initialSubtitleId?.let(::setSubtitleTrack) ?: disableSubtitles()
                loading = false
                main.post { delegate?.onTracksReady(); delegate?.onReadyToSeek(); delegate?.onLoadingChanged(false) }
            }
            MPVLib.MPV_EVENT_SEEK -> { seeking = true; loading = true; main.post { delegate?.onLoadingChanged(true) } }
            MPVLib.MPV_EVENT_PLAYBACK_RESTART -> { seeking = false; if (loading) { loading = false; main.post { delegate?.onLoadingChanged(false) } } }
            MPVLib.MPV_EVENT_END_FILE -> {
                // Genuine EOF is emitted via the eof-reached property. END_FILE
                // also fires for stop/reload, so do not dispatch onEnd here.
                seeking = false
            }
            MPVLib.MPV_EVENT_START_FILE -> { seeking = false }
        }
    }

    private fun postProgress() = main.post { delegate?.onPositionChanged(_position, _duration, cachedCacheSeconds) }
    private fun notifyDimensions() {
        if (_videoWidth <= 0 || _videoHeight <= 0) return
        val (w, h) = normalizeVideoDimensions(_videoWidth, _videoHeight, rotation)
        main.post { delegate?.onVideoDimensionsChanged(w, h) }
    }
}
