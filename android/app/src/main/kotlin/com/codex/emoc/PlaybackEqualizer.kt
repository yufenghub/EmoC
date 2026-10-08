package com.codex.emoc

import android.media.audiofx.Equalizer
import kotlin.math.log10

class PlaybackEqualizer {
    private val anchorsHz = doubleArrayOf(60.0, 230.0, 910.0, 3600.0, 14000.0)
    private var effect: Equalizer? = null
    private var sessionId = 0
    private var enabled = false
    private var levelsDb = List(5) { 0.0 }

    fun configure(enabled: Boolean, levels: List<Double>, currentSessionId: Int) {
        this.enabled = enabled
        levelsDb = List(5) { index -> levels.getOrNull(index)?.coerceIn(-12.0, 12.0) ?: 0.0 }
        attach(currentSessionId)
    }

    fun attach(newSessionId: Int) {
        if (!enabled || newSessionId <= 0) {
            close()
            return
        }
        if (newSessionId != sessionId || effect == null) {
            close()
            effect = Equalizer(0, newSessionId)
            sessionId = newSessionId
        }
        val equalizer = effect ?: return
        val range = equalizer.bandLevelRange
        for (band in 0 until equalizer.numberOfBands.toInt()) {
            val hz = equalizer.getCenterFreq(band.toShort()) / 1000.0
            val gain = gainAt(hz)
            equalizer.setBandLevel(
                band.toShort(),
                (gain * 100).toInt().coerceIn(range[0].toInt(), range[1].toInt()).toShort()
            )
        }
        equalizer.enabled = true
    }

    private fun gainAt(hz: Double): Double {
        if (hz <= anchorsHz.first()) return levelsDb.first()
        if (hz >= anchorsHz.last()) return levelsDb.last()
        val upper = anchorsHz.indexOfFirst { it >= hz }
        val lower = upper - 1
        val fraction = (log10(hz) - log10(anchorsHz[lower])) /
            (log10(anchorsHz[upper]) - log10(anchorsHz[lower]))
        return levelsDb[lower] + (levelsDb[upper] - levelsDb[lower]) * fraction
    }

    fun close() {
        effect?.release()
        effect = null
        sessionId = 0
    }
}
