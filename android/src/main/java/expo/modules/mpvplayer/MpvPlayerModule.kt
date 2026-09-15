package expo.modules.mpvplayer

import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.mpvplayer.nativeplayer.engine.VideoLoadConfig

class MpvPlayerModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("MpvPlayer")
        Events("onChange", "onNativeLog")

        Function("hello") { "Hello from MPV Player! 👋" }
        Function("supportsAv1HardwareDecode") {
            MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.any { info ->
                !info.isEncoder &&
                    info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AV1, ignoreCase = true) } &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || info.isHardwareAccelerated)
            }
        }
        AsyncFunction("setValueAsync") { value: String -> sendEvent("onChange", mapOf("value" to value)) }

        View(MpvPlayerView::class) {
            Prop("source") { view: MpvPlayerView, source: Map<String, Any?>? ->
                if (source == null) return@Prop
                val url = source["url"] as? String ?: return@Prop
                @Suppress("UNCHECKED_CAST")
                val cache = source["cacheConfig"] as? Map<String, Any?>
                @Suppress("UNCHECKED_CAST")
                val config = VideoLoadConfig(
                    url = url,
                    headers = source["headers"] as? Map<String, String>,
                    externalSubtitles = source["externalSubtitles"] as? List<String>,
                    startPosition = (source["startPosition"] as? Number)?.toDouble(),
                    autoplay = (source["autoplay"] as? Boolean) ?: true,
                    initialSubtitleId = (source["initialSubtitleId"] as? Number)?.toInt(),
                    initialAudioId = (source["initialAudioId"] as? Number)?.toInt(),
                    loop = (source["loop"] as? Boolean) ?: false,
                    voDriver = source["voDriver"] as? String,
                    cacheEnabled = cache?.get("enabled") as? String,
                    cacheSeconds = (cache?.get("cacheSeconds") as? Number)?.toInt(),
                    demuxerMaxBytes = (cache?.get("maxBytes") as? Number)?.toInt(),
                    demuxerMaxBackBytes = (cache?.get("maxBackBytes") as? Number)?.toInt(),
                )
                view.loadVideo(config)
            }
            Prop("nowPlayingMetadata") { _: MpvPlayerView, _: Map<String, Any?>? -> }

            AsyncFunction("play") { view: MpvPlayerView -> view.play() }
            AsyncFunction("pause") { view: MpvPlayerView -> view.pause() }
            AsyncFunction("destroy") { view: MpvPlayerView -> view.destroy() }
            AsyncFunction("seekTo") { view: MpvPlayerView, position: Double -> view.seekTo(position) }
            AsyncFunction("seekBy") { view: MpvPlayerView, offset: Double -> view.seekBy(offset) }
            AsyncFunction("setSpeed") { view: MpvPlayerView, speed: Double -> view.setSpeed(speed) }
            AsyncFunction("setMute") { view: MpvPlayerView, muted: Boolean -> view.setMute(muted) }
            AsyncFunction("getSpeed") { view: MpvPlayerView -> view.getSpeed() }
            AsyncFunction("isPaused") { view: MpvPlayerView -> view.isPaused() }
            AsyncFunction("getCurrentPosition") { view: MpvPlayerView -> view.getCurrentPosition() }
            AsyncFunction("getDuration") { view: MpvPlayerView -> view.getDuration() }
            AsyncFunction("startPictureInPicture") { view: MpvPlayerView -> view.startPictureInPicture() }
            AsyncFunction("stopPictureInPicture") { view: MpvPlayerView -> view.stopPictureInPicture() }
            AsyncFunction("isPictureInPictureSupported") { view: MpvPlayerView -> view.isPictureInPictureSupported() }
            AsyncFunction("isPictureInPictureActive") { view: MpvPlayerView -> view.isPictureInPictureActive() }
            AsyncFunction("getSubtitleTracks") { view: MpvPlayerView -> view.getSubtitleTracks() }
            AsyncFunction("setSubtitleTrack") { view: MpvPlayerView, id: Int -> view.setSubtitleTrack(id) }
            AsyncFunction("disableSubtitles") { view: MpvPlayerView -> view.disableSubtitles() }
            AsyncFunction("getCurrentSubtitleTrack") { view: MpvPlayerView -> view.getCurrentSubtitleTrack() }
            AsyncFunction("addSubtitleFile") { view: MpvPlayerView, url: String, select: Boolean -> view.addSubtitleFile(url, select) }
            AsyncFunction("setSubtitlePosition") { view: MpvPlayerView, position: Int -> view.setSubtitlePosition(position) }
            AsyncFunction("setSubtitleScale") { view: MpvPlayerView, scale: Double -> view.setSubtitleScale(scale) }
            AsyncFunction("setSubtitleDelay") { view: MpvPlayerView, seconds: Double -> view.setSubtitleDelay(seconds) }
            AsyncFunction("setSubtitleMarginY") { view: MpvPlayerView, margin: Int -> view.setSubtitleMarginY(margin) }
            AsyncFunction("setSubtitleAlignX") { view: MpvPlayerView, alignment: String -> view.setSubtitleAlignX(alignment) }
            AsyncFunction("setSubtitleAlignY") { view: MpvPlayerView, alignment: String -> view.setSubtitleAlignY(alignment) }
            AsyncFunction("setSubtitleStyle") { view: MpvPlayerView, config: Map<String, Any> -> view.setSubtitleStyle(config) }
            AsyncFunction("setSubtitleFontSize") { view: MpvPlayerView, size: Int -> view.setSubtitleFontSize(size) }
            AsyncFunction("setSubtitleBorderStyle") { view: MpvPlayerView, style: String -> view.setSubtitleBorderStyle(style) }
            AsyncFunction("setSubtitleBackgroundColor") { view: MpvPlayerView, color: String -> view.setSubtitleBackgroundColor(color) }
            AsyncFunction("setSubtitleAssOverride") { view: MpvPlayerView, mode: String -> view.setSubtitleAssOverride(mode) }
            AsyncFunction("getAudioTracks") { view: MpvPlayerView -> view.getAudioTracks() }
            AsyncFunction("setAudioTrack") { view: MpvPlayerView, id: Int -> view.setAudioTrack(id) }
            AsyncFunction("getCurrentAudioTrack") { view: MpvPlayerView -> view.getCurrentAudioTrack() }
            AsyncFunction("setZoomedToFill") { view: MpvPlayerView, zoomed: Boolean -> view.setZoomedToFill(zoomed) }
            AsyncFunction("isZoomedToFill") { view: MpvPlayerView -> view.isZoomedToFill() }
            AsyncFunction("getTechnicalInfo") { view: MpvPlayerView -> view.getTechnicalInfo() }

            Events("onLoad", "onPlaybackStateChange", "onProgress", "onError", "onTracksReady", "onPictureInPictureChange")
        }
    }
}
