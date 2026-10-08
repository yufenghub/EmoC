package com.codex.emoc

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.media3.common.C
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

class PlaybackCrossfade(
    private val outgoing: ExoPlayer,
    private val incoming: ExoPlayer,
    private val durationMs: Long,
    private val outgoingVolume: () -> Float,
    private val incomingVolume: () -> Float,
    private val onCancel: () -> Unit,
    private val onComplete: (ExoPlayer) -> Unit
) : Runnable {
    private val handler = Handler(Looper.getMainLooper())
    private var startPosition = -1L
    private var fadeDuration = durationMs
    private var closed = false
    private var waitingSince = 0L
    private val errorListener = object : Player.Listener {
        override fun onPlayerError(error: PlaybackException) = cancel(notifyFailure = true)
    }

    init {
        incoming.volume = 0f
        incoming.addListener(errorListener)
        handler.post(this)
    }

    override fun run() {
        if (closed) return
        val duration = outgoing.duration
        val remaining = duration - outgoing.currentPosition
        val ended = outgoing.playbackState == Player.STATE_ENDED
        if (ended && incoming.playbackState != Player.STATE_READY && outgoing.playWhenReady) {
            if (waitingSince == 0L) waitingSince = SystemClock.elapsedRealtime()
            if (SystemClock.elapsedRealtime() - waitingSince >= 8000) {
                cancel(notifyFailure = true)
                return
            }
        } else {
            waitingSince = 0L
        }
        if (startPosition >= 0 && incoming.playbackState == Player.STATE_BUFFERING) {
            cancel(notifyFailure = true)
            return
        }
        if (ended && outgoing.playWhenReady && incoming.playbackState == Player.STATE_READY) {
            finish()
            return
        }
        if (!outgoing.isPlaying) {
            incoming.pause()
        } else if (incoming.playbackState == Player.STATE_READY && duration != C.TIME_UNSET) {
            if (startPosition < 0 && remaining in 1..durationMs) {
                startPosition = outgoing.currentPosition
                fadeDuration = remaining
            }
            if (startPosition >= 0) {
                val elapsed = outgoing.currentPosition - startPosition
                if (elapsed < 0 || elapsed > fadeDuration + 1000) {
                    cancel(notifyFailure = true)
                    return
                }
                incoming.play()
                val fraction = (elapsed.toFloat() / fadeDuration).coerceIn(0f, 1f)
                outgoing.volume = outgoingVolume() * (1f - fraction)
                incoming.volume = incomingVolume() * fraction
                if (fraction >= 1f) {
                    finish()
                    return
                }
            }
        }
        handler.postDelayed(this, if (startPosition >= 0) 40 else 200)
    }

    private fun finish() {
        closed = true
        incoming.removeListener(errorListener)
        incoming.volume = incomingVolume()
        incoming.play()
        onComplete(incoming)
        outgoing.release()
    }

    fun cancel(notifyFailure: Boolean = false) {
        if (closed) return
        closed = true
        handler.removeCallbacks(this)
        incoming.removeListener(errorListener)
        incoming.release()
        outgoing.volume = outgoingVolume()
        if (notifyFailure) onCancel()
    }
}
