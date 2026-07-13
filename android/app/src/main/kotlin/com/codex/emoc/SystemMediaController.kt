package com.codex.emoc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
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
        fun onCoverColor(songId: String, coverUrl: String, color: Int)
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
    private var loadedCoverUrl = ""
    private var loadingCoverUrl = ""
    private var coverFailedAtMs = 0L
    private var coverRetryCount = 0
    private var coverBitmap: Bitmap? = null
    private var coverColor: Int? = null
    private var coverColorUrl = ""
    private var coverColorSongId = ""
    private val appIconBitmap: Bitmap? by lazy { loadAppIconBitmap() }

    @Volatile
    private var released = false

    init {
        createNotificationChannel()
    }

    fun update(
        metadata: TrackMetadata,
        playing: Boolean,
        currentMs: Long,
        durationMs: Long
    ) {
        if (released) return
        val previousSongId = this.metadata.songId
        val songChanged = metadata.songId.isNotBlank() && metadata.songId != previousSongId
        this.metadata = metadata
        this.playing = playing
        this.currentMs = if (songChanged && currentMs <= 0L) 0L else currentMs.coerceAtLeast(0L)
        this.durationMs = when {
            durationMs > 0L -> durationMs
            songChanged -> 0L
            else -> this.durationMs
        }
        if (coverColor != null && coverColorUrl == metadata.coverUrl && metadata.songId.isNotBlank()) {
            coverColorSongId = metadata.songId
        }
        updateCoverIfNeeded(metadata.coverUrl)
        updateSession()
        showNotification()
    }

    fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
        session.isActive = false
    }

    fun release() {
        if (released) return
        released = true
        cancel()
        session.release()
        coverExecutor.shutdownNow()
        coverBitmap?.let { bitmap ->
            if (bitmap !== appIconBitmap && !bitmap.isRecycled) bitmap.recycle()
        }
        coverBitmap = null
        appIconBitmap?.let { bitmap ->
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    fun currentCoverColor(): Int? {
        val url = metadata.coverUrl
        val songId = metadata.songId
        return if (
            (url.startsWith("http") && coverColorUrl == url) ||
                (songId.isNotBlank() && coverColorSongId == songId)
        ) {
            coverColor
        } else {
            null
        }
    }

    fun currentCoverColorUrl(): String {
        val url = metadata.coverUrl
        return if (url.startsWith("http") && coverColorUrl == url) {
            coverColorUrl
        } else if (url.startsWith("http") && metadata.songId.isNotBlank() && coverColorSongId == metadata.songId) {
            url
        } else {
            ""
        }
    }

    fun currentCoverColorSongId(): String {
        val songId = metadata.songId
        return if (songId.isNotBlank() && coverColorSongId == songId) coverColorSongId else ""
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
            .setState(state, currentMs, if (playing) 1.0f else 0.0f)
            .build()
        val mediaMetadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, metadata.songId)
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, metadata.title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, metadata.artist)
            .also { builder ->
                if (durationMs > 0L) {
                    builder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
                }
                effectiveCoverBitmap()?.let {
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
            .setLargeIcon(effectiveCoverBitmap())
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
        val now = System.currentTimeMillis()
        if (url == lastCoverUrl) {
            if (loadedCoverUrl == url || loadingCoverUrl == url) return
            if (coverFailedAtMs > 0L && now - coverFailedAtMs < 5_000L) return
        }
        if (url != lastCoverUrl) coverRetryCount = 0
        lastCoverUrl = url
        coverColor = null
        coverColorUrl = ""
        coverColorSongId = ""
        if (!url.startsWith("http")) {
            loadingCoverUrl = ""
            return
        }
        loadingCoverUrl = url
        coverExecutor.execute {
            val bitmap = runCatching { downloadBitmapWithFallback(url) }.getOrNull()
            val color = bitmap?.let { dominantColorFromBitmap(it) }
            mainHandler.post {
                if (released) {
                    bitmap?.let { if (!it.isRecycled) it.recycle() }
                    return@post
                }
                if (url != lastCoverUrl) {
                    bitmap?.let { if (!it.isRecycled) it.recycle() }
                    return@post
                }
                loadingCoverUrl = ""
                if (bitmap != null) {
                    val previous = coverBitmap
                    coverBitmap = bitmap
                    loadedCoverUrl = url
                    coverFailedAtMs = 0L
                    coverRetryCount = 0
                    if (
                        previous != null &&
                        previous !== bitmap &&
                        previous !== appIconBitmap &&
                        !previous.isRecycled
                    ) {
                        previous.recycle()
                    }
                    coverColor = color
                    coverColorUrl = if (color != null) url else ""
                    coverColorSongId = if (color != null) metadata.songId else ""
                    if (color != null) {
                        callbacks.onCoverColor(metadata.songId, url, color)
                    }
                } else {
                    coverFailedAtMs = System.currentTimeMillis()
                    coverRetryCount += 1
                    if (coverRetryCount <= 3) {
                        mainHandler.postDelayed({
                            if (!released && lastCoverUrl == url) {
                                updateCoverIfNeeded(url)
                            }
                        }, 5_200L * coverRetryCount)
                    }
                }
                updateSession()
                showNotification()
            }
        }
    }

    private fun effectiveCoverBitmap(): Bitmap? {
        return coverBitmap ?: appIconBitmap
    }

    private fun loadAppIconBitmap(): Bitmap? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(context.packageName)
            val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 192
            val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 192
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        } catch (_: Exception) {
            BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
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

    private fun downloadBitmapWithFallback(rawUrl: String): Bitmap? {
        val secureUrl = if (rawUrl.startsWith("http://")) {
            rawUrl.replaceFirst("http://", "https://")
        } else {
            rawUrl
        }
        val baseUrl = secureUrl.substringBefore('?')
        val candidates = linkedSetOf(
            "$baseUrl?param=360y360",
            "$baseUrl?param=180y180",
            secureUrl,
            baseUrl
        )
        for (hostIndex in 1..4) {
            val hostUrl = secureUrl.replace(Regex("p\\d\\.music\\.126\\.net"), "p$hostIndex.music.126.net")
            val hostBase = hostUrl.substringBefore('?')
            candidates.add("$hostBase?param=360y360")
            candidates.add(hostUrl)
        }
        for (candidate in candidates) {
            val bitmap = runCatching { downloadBitmap(candidate) }.getOrNull()
            if (bitmap != null) return bitmap
        }
        return null
    }

    private fun dominantColorFromBitmap(bitmap: Bitmap): Int? {
        return averageCoverColor(bitmap, strict = true)
            ?: averageCoverColor(bitmap, strict = false)
    }

    private fun averageCoverColor(bitmap: Bitmap, strict: Boolean): Int? {
        val width = bitmap.width.coerceAtLeast(1)
        val height = bitmap.height.coerceAtLeast(1)
        val stepX = (width / 28).coerceAtLeast(1)
        val stepY = (height / 28).coerceAtLeast(1)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0
        var y = 0
        while (y < height) {
            var x = 0
            while (x < width) {
                val pixel = bitmap.getPixel(x, y)
                if (Color.alpha(pixel) >= 180) {
                    val r = Color.red(pixel)
                    val g = Color.green(pixel)
                    val b = Color.blue(pixel)
                    val brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                    if (!strict || (brightness >= 0.14 && brightness <= 0.9)) {
                        red += r
                        green += g
                        blue += b
                        count += 1
                    }
                }
                x += stepX
            }
            y += stepY
        }
        if (count == 0) return null
        val hsv = FloatArray(3)
        Color.RGBToHSV(
            (red / count).toInt().coerceIn(0, 255),
            (green / count).toInt().coerceIn(0, 255),
            (blue / count).toInt().coerceIn(0, 255),
            hsv
        )
        hsv[1] = hsv[1].coerceIn(0.42f, 0.78f)
        hsv[2] = hsv[2].coerceIn(0.42f, 0.62f)
        return Color.HSVToColor(255, hsv)
    }

    private fun contentIntent(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
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
