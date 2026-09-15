package expo.modules.mpvplayer

import android.content.Context
import dev.jdtech.mpv.MPVLib as LibMPV

/** Per-instance wrapper around dev.jdtech.mpv.MPVLib. */
class MPVLib private constructor(private val instance: LibMPV) {
    interface EventObserver {
        fun eventProperty(property: String)
        fun eventProperty(property: String, value: Long)
        fun eventProperty(property: String, value: Boolean)
        fun eventProperty(property: String, value: String)
        fun eventProperty(property: String, value: Double)
        fun event(eventId: Int)
    }

    private val observers = mutableListOf<EventObserver>()
    private val libObserver = object : LibMPV.EventObserver {
        override fun eventProperty(property: String) = dispatch { it.eventProperty(property) }
        override fun eventProperty(property: String, value: Long) = dispatch { it.eventProperty(property, value) }
        override fun eventProperty(property: String, value: Boolean) = dispatch { it.eventProperty(property, value) }
        override fun eventProperty(property: String, value: String) = dispatch { it.eventProperty(property, value) }
        override fun eventProperty(property: String, value: Double) = dispatch { it.eventProperty(property, value) }
        override fun event(eventId: Int) = dispatch { it.event(eventId) }
        private inline fun dispatch(block: (EventObserver) -> Unit) {
            synchronized(observers) { observers.forEach(block) }
        }
    }

    fun addObserver(observer: EventObserver) = synchronized(observers) { observers.add(observer); Unit }
    fun removeObserver(observer: EventObserver) = synchronized(observers) { observers.remove(observer); Unit }
    fun initialize() = instance.init()
    fun attachSurface(surface: android.view.Surface) = instance.attachSurface(surface)
    fun detachSurface() = instance.detachSurface()
    fun command(cmd: Array<String>) = instance.command(cmd)
    fun setOptionString(name: String, value: String): Int = instance.setOptionString(name, value)
    fun getPropertyInt(name: String): Int? = try { instance.getPropertyInt(name) } catch (_: Exception) { null }
    fun getPropertyDouble(name: String): Double? = try { instance.getPropertyDouble(name) } catch (_: Exception) { null }
    fun getPropertyBoolean(name: String): Boolean? = try { instance.getPropertyBoolean(name) } catch (_: Exception) { null }
    fun getPropertyString(name: String): String? = try { instance.getPropertyString(name) } catch (_: Exception) { null }
    fun setPropertyInt(name: String, value: Int) = instance.setPropertyInt(name, value)
    fun setPropertyDouble(name: String, value: Double) = instance.setPropertyDouble(name, value)
    fun setPropertyBoolean(name: String, value: Boolean) = instance.setPropertyBoolean(name, value)
    fun setPropertyString(name: String, value: String) = instance.setPropertyString(name, value)
    fun observeProperty(name: String, format: Int) = instance.observeProperty(name, format)

    companion object {
        fun create(context: Context): MPVLib {
            val lib = LibMPV.create(context) ?: throw IllegalStateException("LibMPV.create returned null")
            val wrapper = MPVLib(lib)
            lib.addObserver(wrapper.libObserver)
            return wrapper
        }
        const val MPV_EVENT_SHUTDOWN = 1
        const val MPV_EVENT_START_FILE = 6
        const val MPV_EVENT_END_FILE = 7
        const val MPV_EVENT_FILE_LOADED = 8
        const val MPV_EVENT_SEEK = 20
        const val MPV_EVENT_PLAYBACK_RESTART = 21
    }
}
