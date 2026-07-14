package com.codex.emoc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.net.wifi.WifiManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import android.content.pm.ServiceInfo

class PlaybackKeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var lastTitle = "EmoC"
    private var lastArtist = "正在播放"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val prefs = playbackPrefs()
        val shouldStayActive = intent != null || prefs.getBoolean(KEY_ACTIVE, false)
        if (!shouldStayActive) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank {
            prefs.getString(KEY_TITLE, "EmoC").orEmpty().ifBlank { "EmoC" }
        }
        val artist = intent?.getStringExtra(EXTRA_ARTIST).orEmpty().ifBlank {
            prefs.getString(KEY_ARTIST, "正在播放").orEmpty().ifBlank { "正在播放" }
        }
        lastTitle = title
        lastArtist = artist
        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putString(KEY_TITLE, title)
            .putString(KEY_ARTIST, artist)
            .apply()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music_note)
            .setContentTitle(title)
            .setContentText(artist)
            .setSubText("EmoC")
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                }
            }
            .build()
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            } else {
                0
            }
        )
        acquireWakeLock()
        acquireWifiLock()
        return START_REDELIVER_INTENT
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
        val shouldRestart = playbackPrefs().getBoolean(KEY_ACTIVE, false)
        releaseWakeLock()
        releaseWifiLock()
        super.onDestroy()
        if (shouldRestart) {
            mainHandler.postDelayed({ restartIfRequired() }, RESTART_DELAY_MS)
        }
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

    private fun contentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .setAction(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        return PendingIntent.getActivity(this, 0, intent, flags)
    }

    private fun playbackPrefs() =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun restartIfRequired() {
        val prefs = playbackPrefs()
        if (!prefs.getBoolean(KEY_ACTIVE, false)) return
        start(
            applicationContext,
            TrackMetadata(
                title = prefs.getString(KEY_TITLE, "EmoC").orEmpty(),
                artist = prefs.getString(KEY_ARTIST, "正在播放").orEmpty()
            )
        )
    }

    companion object {
        private const val CHANNEL_ID = "emoc_playback_keep_alive"
        private const val NOTIFICATION_ID = 16302
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_ARTIST = "artist"
        private const val PREFS_NAME = "emoc_playback_service"
        private const val KEY_ACTIVE = "active"
        private const val KEY_TITLE = "title"
        private const val KEY_ARTIST = "artist"
        private const val RESTART_DELAY_MS = 800L

        fun start(context: Context, metadata: TrackMetadata) {
            context.applicationContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, true)
                .putString(KEY_TITLE, metadata.title)
                .putString(KEY_ARTIST, metadata.artist)
                .apply()
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
            context.applicationContext
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, false)
                .apply()
            context.stopService(Intent(context, PlaybackKeepAliveService::class.java))
        }
    }
}
