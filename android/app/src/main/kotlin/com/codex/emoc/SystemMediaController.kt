package com.codex.emoc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

data class TrackMetadata(
    val songId: String = "",
    val title: String = "EmoC",
    val artist: String = "网易云音乐",
    val coverUrl: String = ""
)

class SystemMediaController(
    private val context: Context,
    private val callbacks: Callbacks
) {
    interface Callbacks {
        fun onPlay()
        fun onPause()
        fun onPrevious()
        fun onNext()
        fun onSeekTo(positionMs: Long)
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private val coverExecutor = Executors.newSingleThreadExecutor()
    private val session = MediaSessionCompat(context, SESSION_TAG).apply {
        setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() = callbacks.onPlay()
            override fun onPause() = callbacks.onPause()
            override fun onSkipToPrevious() = callbacks.onPrevious()
            override fun onSkipToNext() = callbacks.onNext()
            override fun onSeekTo(pos: Long) = callbacks.onSeekTo(pos)
        })
        isActive = true
    }

    private var metadata = TrackMetadata()
    private var playing = false
    private var currentMs = 0L
    private var durationMs = 0L
    private var lastCoverUrl = ""
    private var coverBitmap: Bitmap? = null

    init {
        createNotificationChannel()
    }

    fun update(
        metadata: TrackMetadata,
        playing: Boolean,
        currentMs: Long,
        durationMs: Long
    ) {
        this.metadata = metadata
        this.playing = playing
        this.currentMs = currentMs.coerceAtLeast(0L)
        this.durationMs = durationMs.coerceAtLeast(0L)
        updateCoverIfNeeded(metadata.coverUrl)
        updateSession()
        showNotification()
    }

    fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
        session.isActive = false
    }

    fun release() {
        cancel()
        session.release()
        coverExecutor.shutdownNow()
    }

    private fun updateSession() {
        session.isActive = true
        val state = if (playing) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                    PlaybackStateCompat.ACTION_SEEK_TO
            )
            .setState(state, currentMs, 1.0f)
            .build()
        val mediaMetadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, metadata.songId)
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, metadata.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, metadata.artist)
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
            .also { builder ->
                coverBitmap?.let {
                    builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it)
                    builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, it)
                }
            }
            .build()
        session.setMetadata(mediaMetadata)
        session.setPlaybackState(playbackState)
    }

    private fun showNotification() {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music_note)
            .setContentTitle(metadata.title)
            .setContentText(metadata.artist)
            .setSubText("EmoC")
            .setLargeIcon(coverBitmap)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setContentIntent(contentIntent())
            .addAction(
                android.R.drawable.ic_media_previous,
                "上一首",
                actionIntent(ACTION_PREVIOUS)
            )
            .addAction(
                if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (playing) "暂停" else "播放",
                actionIntent(ACTION_PLAY_PAUSE)
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "下一首",
                actionIntent(ACTION_NEXT)
            )
            .setStyle(
                MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Android 13+ may block non-exempt notifications when permission is denied.
            // MediaSession still exposes playback state to compatible system surfaces.
        }
    }

    private fun updateCoverIfNeeded(url: String) {
        if (url == lastCoverUrl) return
        lastCoverUrl = url
        coverBitmap = null
        if (!url.startsWith("http")) return
        coverExecutor.execute {
            val bitmap = runCatching { downloadBitmap(url) }.getOrNull()
            mainHandler.post {
                if (url != lastCoverUrl) return@post
                coverBitmap = bitmap
                updateSession()
                showNotification()
            }
        }
    }

    private fun downloadBitmap(url: String): Bitmap? {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 8000
        connection.readTimeout = 12000
        connection.instanceFollowRedirects = true
        connection.setRequestProperty("User-Agent", MainActivity.USER_AGENT)
        connection.inputStream.use { stream ->
            return BitmapFactory.decodeStream(stream)
        }
    }

    private fun contentIntent(): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        return PendingIntent.getActivity(context, 0, intent, pendingIntentFlags())
    }

    private fun actionIntent(action: String): PendingIntent {
        val intent = Intent(context, MediaActionReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(context, action.hashCode(), intent, pendingIntentFlags())
    }

    private fun pendingIntentFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "EmoC 播放控制",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "显示当前播放歌曲和系统媒体控制"
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_PLAY = "com.codex.emoc.action.PLAY"
        const val ACTION_PAUSE = "com.codex.emoc.action.PAUSE"
        const val ACTION_PLAY_PAUSE = "com.codex.emoc.action.PLAY_PAUSE"
        const val ACTION_PREVIOUS = "com.codex.emoc.action.PREVIOUS"
        const val ACTION_NEXT = "com.codex.emoc.action.NEXT"

        private const val CHANNEL_ID = "emoc_media"
        private const val NOTIFICATION_ID = 16301
        private const val SESSION_TAG = "EmoCPlayer"
    }
}
