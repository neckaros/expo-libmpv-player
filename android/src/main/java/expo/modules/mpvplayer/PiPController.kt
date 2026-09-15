package expo.modules.mpvplayer

import android.app.Activity
import android.app.Application
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.view.View
import expo.modules.kotlin.AppContext

class PiPController(private val context: Context, private val appContext: AppContext? = null) {
    interface Delegate {
        fun onPlay()
        fun onPause()
        fun onSeekBy(seconds: Double)
        fun onPictureInPictureModeChanged(isInPiP: Boolean)
    }

    var delegate: Delegate? = null
    private var videoWidth = 0
    private var videoHeight = 0
    private var playerView: View? = null
    private var playbackRate = 0.0
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null

    fun isPictureInPictureSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    fun isPictureInPictureActive(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && (getActivity()?.isInPictureInPictureMode == true)

    fun startPictureInPicture() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val activity = getActivity() ?: return
        if (!isPictureInPictureSupported()) return
        try {
            val entered = activity.enterPictureInPictureMode(buildParams(true))
            if (entered) {
                delegate?.onPictureInPictureModeChanged(true)
                registerLifecycleCallbacks()
            }
        } catch (e: Exception) {
            Log.e("PiPController", "Failed to enter PiP", e)
        }
    }

    fun stopPictureInPicture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getActivity()?.setPictureInPictureParams(PictureInPictureParams.Builder().setAutoEnterEnabled(false).build())
        }
        unregisterLifecycleCallbacks()
    }

    fun setCurrentTime(position: Double, duration: Double) { /* Android PiP has no native progress API. */ }

    fun setPlaybackRate(rate: Double) {
        playbackRate = rate
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try { getActivity()?.setPictureInPictureParams(buildParams(false)) } catch (_: Exception) {}
        }
        if (rate > 0) registerLifecycleCallbacks()
    }

    fun setVideoDimensions(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            videoWidth = width; videoHeight = height
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPictureInPictureActive()) {
                try { getActivity()?.setPictureInPictureParams(buildParams(false)) } catch (_: Exception) {}
            }
        }
    }

    fun setPlayerView(view: View?) { playerView = view }

    private fun buildParams(forEntering: Boolean): PictureInPictureParams {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) throw IllegalStateException("PiP unavailable")
        val vw = videoWidth.coerceAtLeast(16)
        val vh = videoHeight.coerceAtLeast(9)
        val maxAspect = 2.39f
        val w = vw.coerceAtMost((vh * maxAspect).toInt().coerceAtLeast(1))
        val h = vh.coerceAtMost((vw * maxAspect).toInt().coerceAtLeast(1))
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(w, h))
        val view = playerView
        if (view != null && view.width > 0 && view.height > 0) {
            builder.setSourceRectHint(Rect(0, 0, view.width, view.height))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(forEntering || playbackRate > 0)
        }
        return builder.build()
    }

    private fun getActivity(): Activity? {
        val currentActivity = appContext?.currentActivity
        if (currentActivity != null) return currentActivity
        var ctx: Context? = context
        while (ctx is android.content.ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    private fun registerLifecycleCallbacks() {
        if (lifecycleCallbacks != null) return
        val app = context.applicationContext as? Application ?: return
        lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityResumed(a: Activity) {
                if (!a.isInPictureInPictureMode) delegate?.onPictureInPictureModeChanged(false)
            }
            override fun onActivityPaused(a: Activity) {}
            override fun onActivityStopped(a: Activity) {
                delegate?.onPictureInPictureModeChanged(a.isInPictureInPictureMode)
            }
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        }
        app.registerActivityLifecycleCallbacks(lifecycleCallbacks)
    }

    private fun unregisterLifecycleCallbacks() {
        val app = context.applicationContext as? Application
        lifecycleCallbacks?.let { app?.unregisterActivityLifecycleCallbacks(it) }
        lifecycleCallbacks = null
    }
}
