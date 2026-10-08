package com.codex.emoc

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PlaybackWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val saved = context.getSharedPreferences("playback_widget", Context.MODE_PRIVATE)
        render(context, ids, saved.getString("title", "EmoC").orEmpty(),
            saved.getString("artist", "").orEmpty(), isPlaying)
    }

    companion object {
        const val EXTRA_ACTION = "widgetPlaybackAction"
        private var lastState = ""
        private var isPlaying = false

        fun update(context: Context, track: TrackMetadata, playing: Boolean) {
            val state = "${track.songId}|${track.title}|${track.artist}|$playing"
            if (state == lastState) return
            lastState = state
            isPlaying = playing
            context.getSharedPreferences("playback_widget", Context.MODE_PRIVATE).edit()
                .putString("title", track.title).putString("artist", track.artist).apply()
            val manager = AppWidgetManager.getInstance(context)
            render(context, manager.getAppWidgetIds(ComponentName(context, PlaybackWidget::class.java)),
                track.title, track.artist, playing)
        }

        private fun render(context: Context, ids: IntArray, title: String, artist: String, playing: Boolean) {
            if (ids.isEmpty()) return
            val views = RemoteViews(context.packageName, R.layout.playback_widget)
            views.setTextViewText(R.id.widget_title, title.ifBlank { "EmoC" })
            views.setTextViewText(R.id.widget_artist, artist)
            views.setImageViewResource(R.id.widget_play,
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
            views.setContentDescription(R.id.widget_play, if (playing) "暂停" else "播放")
            val open = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            views.setOnClickPendingIntent(R.id.widget_metadata, PendingIntent.getActivity(context, 90, open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            val actions = mapOf(
                R.id.widget_previous to SystemMediaController.ACTION_PREVIOUS,
                R.id.widget_play to if (playing) SystemMediaController.ACTION_PAUSE else SystemMediaController.ACTION_PLAY,
                R.id.widget_next to SystemMediaController.ACTION_NEXT)
            for ((id, action) in actions) {
                val pending = PendingIntent.getBroadcast(context, id,
                    Intent(context, MediaActionReceiver::class.java).setAction(action),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(id, pending)
            }
            AppWidgetManager.getInstance(context).updateAppWidget(ids, views)
        }
    }
}
