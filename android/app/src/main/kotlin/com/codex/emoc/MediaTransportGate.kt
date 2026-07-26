package com.codex.emoc

import android.os.SystemClock

object MediaTransportGate {
    @Volatile
    private var lastTransportAtMs = Long.MIN_VALUE

    fun recordTransportCommand() {
        lastTransportAtMs = SystemClock.elapsedRealtime()
    }

    fun wasTransportCommandRecent(windowMs: Long): Boolean {
        val elapsed = SystemClock.elapsedRealtime() - lastTransportAtMs
        return elapsed in 0..windowMs
    }
}
