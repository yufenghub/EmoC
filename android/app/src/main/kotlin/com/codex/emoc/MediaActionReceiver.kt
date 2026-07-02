package com.codex.emoc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        MainActivity.dispatchMediaAction(intent.action.orEmpty())
    }
}
