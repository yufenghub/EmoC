package com.codex.emoc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.net.wifi.WifiManager
import androidx.core.app.NotificationCompat

class PlaybackKeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var lastTitle = "EmoC"
    private var lastArtist = "正在播放"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "EmoC" }
        val artist = intent?.getStringExtra(EXTRA_ARTIST).orEmpty().ifBlank { "正在播放" }
        lastTitle = title
        lastArtist = artist
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_music_note)
                .setContentTitle(title)
                .setContentText(artist)
                .setSubText("EmoC")
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        )
        acquireWakeLock()
        acquireWifiLock()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        acquireWakeLock()
        try {
            val restartIntent = Intent(applicationContext, PlaybackKeepAliveService::class.java)
                .putExtra(EXTRA_TITLE, lastTitle)
                .putExtra(EXTRA_ARTIST, lastArtist)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartIntent)
            } else {
                applicationContext.startService(restartIntent)
            }
        } catch (_: RuntimeException) {
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        releaseWakeLock()
        releaseWifiLock()
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        val existing = wakeLock
        if (existing?.isHeld == true) return
        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = manager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "EmoC:PlaybackKeepAlive"
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { lock ->
            if (lock.isHeld) {
                lock.release()
            }
        }
        wakeLock = null
    }

    private fun acquireWifiLock() {
        val existing = wifiLock
        if (existing?.isHeld == true) return
        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiLock = manager.createWifiLock(
            WifiManager.WIFI_MODE_FULL_HIGH_PERF,
            "EmoC:PlaybackWifi"
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWifiLock() {
        wifiLock?.let { lock ->
            if (lock.isHeld) lock.release()
        }
        wifiLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "EmoC 后台播放",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "保持后台播放不中断"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "emoc_playback_keep_alive"
        private const val NOTIFICATION_ID = 16302
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_ARTIST = "artist"

        fun start(context: Context, metadata: TrackMetadata) {
            val intent = Intent(context, PlaybackKeepAliveService::class.java)
                .putExtra(EXTRA_TITLE, metadata.title)
                .putExtra(EXTRA_ARTIST, metadata.artist)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: RuntimeException) {
                runCatching { context.startService(intent) }
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, PlaybackKeepAliveService::class.java))
        }
    }
}
