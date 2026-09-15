package expo.modules.mpvplayer.nativeplayer

import java.util.ArrayDeque

object MpvOwnership {
    enum class Owner { NONE, EMBEDDED_VIEW, NATIVE_SESSION }
    private data class Claim(val owner: Owner, val token: Any, val onAcquired: () -> Unit)
    private var currentClaim: Claim? = null
    private val pendingClaims = ArrayDeque<Claim>()

    fun claim(owner: Owner, token: Any, onAcquired: () -> Unit) {
        val acquired = synchronized(this) {
            val claim = Claim(owner, token, onAcquired)
            if (currentClaim == null) { currentClaim = claim; true }
            else { pendingClaims.addLast(claim); false }
        }
        if (acquired) onAcquired()
    }

    @Synchronized fun cancel(token: Any) { pendingClaims.removeAll { it.token === token } }

    fun release(token: Any) {
        val next = synchronized(this) {
            if (currentClaim?.token !== token) return
            pendingClaims.pollFirst().also { currentClaim = it }
        }
        next?.onAcquired?.invoke()
    }
}
