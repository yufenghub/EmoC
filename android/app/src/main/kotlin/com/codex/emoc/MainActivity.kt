package com.codex.emoc

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioAttributes as PlatformAudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import kotlin.math.pow

@UnstableApi
class MainActivity : FlutterActivity() {
    private var ownedNativeChannel: MethodChannel? = null
    private var ownedSystemMediaController: SystemMediaController? = null
    private var ownedAppUpdateController: AppUpdateController? = null
    private var localMusicController: LocalMusicController? = null
    private var player: ExoPlayer?
        get() = sharedPlayer
        set(value) { sharedPlayer = value }
    private var nativeChannel: MethodChannel?
        get() = sharedNativeChannel
        set(value) { sharedNativeChannel = value }
    private var systemMediaController: SystemMediaController?
        get() = sharedSystemMediaController
        set(value) { sharedSystemMediaController = value }
    private var desktopLyricsOverlay: DesktopLyricsOverlayController?
        get() = sharedDesktopLyricsOverlay
        set(value) { sharedDesktopLyricsOverlay = value }
    private var currentTrack: TrackMetadata
        get() = sharedCurrentTrack
        set(value) { sharedCurrentTrack = value }
    private var playerVolume: Float
        get() = sharedPlayerVolume
        set(value) { sharedPlayerVolume = value }
    private var volumeNormalizationEnabled: Boolean
        get() = sharedVolumeNormalizationEnabled
        set(value) { sharedVolumeNormalizationEnabled = value }
    private val playbackEqualizer: PlaybackEqualizer
        get() = sharedPlaybackEqualizer

    private fun normalizedVolume(track: TrackMetadata): Float {
        if (!volumeNormalizationEnabled || !track.gainDb.isFinite()) return playerVolume
        val gain = 10.0.pow(track.gainDb.coerceIn(-12.0, 6.0) / 20.0)
        val peakLimit = if (track.peak.isFinite() && track.peak > 0.0)
            0.98 / track.peak else 1.0
        return (playerVolume * gain.coerceAtMost(peakLimit)).toFloat().coerceIn(0f, 1f)
    }
    private var userPaused: Boolean
        get() = sharedUserPaused
        set(value) { sharedUserPaused = value }
    private var pausedByAudioFocusLoss: Boolean
        get() = sharedPausedByAudioFocusLoss
        set(value) { sharedPausedByAudioFocusLoss = value }
    private var allowMixedAudio: Boolean
        get() = sharedAllowMixedAudio
        set(value) { sharedAllowMixedAudio = value }
    private var noisyReceiverRegistered = false
    private var audioDeviceCallbackRegistered = false
    private var audioFocusRequest: AudioFocusRequest?
        get() = sharedAudioFocusRequest
        set(value) { sharedAudioFocusRequest = value }
    private var playerPrepared: Boolean
        get() = sharedPlayerPrepared
        set(value) { sharedPlayerPrepared = value }
    private var audioSpectrumDecoder: PlaybackSpectrumDecoder?
        get() = sharedAudioSpectrumDecoder
        set(value) { sharedAudioSpectrumDecoder = value }

    private var currentPlaybackUrl: String
        get() = sharedCurrentPlaybackUrl
        set(value) { sharedCurrentPlaybackUrl = value }

    private var playGeneration: Int
        get() = sharedPlayGeneration
        set(value) { sharedPlayGeneration = value }

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                pauseForAudioRouteLoss()
            }
        }
    }

    private val audioDeviceCallback: AudioDeviceCallback? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            object : AudioDeviceCallback() {
                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                    if (removedDevices.any { isHeadphoneRoute(it) }) {
                        pauseForAudioRouteLoss()
                    }
                }
            }
        } else {
            null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeActivity?.get()
            ?.takeIf { it !== this }
            ?.unregisterAudioRouteWatchers()
        activeActivity = WeakReference(this)
        allowMixedAudio = prefs().getString("allowMixedAudio", "false") == "true"
        volumeNormalizationEnabled = prefs().getString("volumeNormalizationEnabled", "false") == "true"
        if (desktopLyricsOverlay == null) {
            desktopLyricsOverlay = DesktopLyricsOverlayController(applicationContext)
        }
        registerAudioRouteWatchers()
    }

    override fun onResume() {
        super.onResume()
        activeActivity = WeakReference(this)
        sharedAppInForeground = true
        ownedAppUpdateController?.onHostResumed(this)
        desktopLyricsOverlay?.setAppInForeground(true)
        notifySystemThemeChanged()
    }

    override fun onPause() {
        if (activeActivity?.get() === this) {
            sharedAppInForeground = false
        }
        desktopLyricsOverlay?.setAppInForeground(false)
        keepPlaybackServiceAliveIfNeeded()
        super.onPause()
    }

    override fun onStop() {
        keepPlaybackServiceAliveIfNeeded()
        super.onStop()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (localMusicController?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        activeActivity = WeakReference(this)
        if (intent.hasExtra(PlaybackWidget.EXTRA_ACTION)) notifyFlutter("widgetAction")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeActivity = WeakReference(this)
        val engineChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "emoc/native")
        ownedNativeChannel = engineChannel
        nativeChannel = engineChannel
        if (sharedNetworkMonitor == null) {
            sharedNetworkMonitor = NetworkStateMonitor(applicationContext) { state ->
                sharedNativeChannel?.invokeMethod("systemMediaCommand", state + ("action" to "networkChanged"))
            }.also { it.start() }
        }
        val mediaController = systemMediaController
            ?: SystemMediaController(applicationContext, mediaSessionCallbacks).also {
                systemMediaController = it
            }
        ownedSystemMediaController = mediaController
        ownedAppUpdateController?.close()
        val updateController = AppUpdateController(applicationContext) { action, payload ->
            notifyFlutter(action, payload)
        }
        ownedAppUpdateController = updateController
        localMusicController?.close()
        localMusicController = LocalMusicController(this)
        engineChannel.setMethodCallHandler { call, result ->
                if (localMusicController?.handle(call, result) == true) return@setMethodCallHandler
                when (call.method) {
                    "networkState" -> result.success(sharedNetworkMonitor?.snapshot() ?: emptyMap<String, Any>())
                    "clearQueuedTrack" -> {
                        clearQueuedTrack()
                        result.success(null)
                    }
                    "queueNextTrack" -> {
                        val expected = call.argument<String>("expectedSongId").orEmpty()
                        val metadata = TrackMetadata(
                            songId = call.argument<String>("songId").orEmpty(),
                            title = call.argument<String>("title").orEmpty(),
                            artist = call.argument<String>("artist").orEmpty(),
                            coverUrl = call.argument<String>("coverUrl").orEmpty(),
                            gainDb = call.argument<Number>("gainDb")?.toDouble() ?: 0.0,
                            peak = call.argument<Number>("peak")?.toDouble() ?: 0.0
                        )
                        result.success(queueNextTrack(expected, call.argument<String>("url").orEmpty(),
                            metadata, (call.argument<Number>("crossfadeMs")?.toLong() ?: 0L).coerceIn(0, 8000)))
                    }
                    "playUrl" -> {
                        val url = call.argument<String>("url").orEmpty()
                        if (url.isBlank()) {
                            result.error("EMPTY_URL", "播放地址为空", null)
                        } else {
                            val metadata = TrackMetadata(
                                songId = call.argument<String>("songId").orEmpty(),
                                title = call.argument<String>("title").orEmpty().ifBlank { "EmoC" },
                                artist = call.argument<String>("artist").orEmpty().ifBlank { "网易云音乐" },
                                coverUrl = call.argument<String>("coverUrl").orEmpty(),
                                gainDb = call.argument<Number>("gainDb")?.toDouble() ?: 0.0,
                                peak = call.argument<Number>("peak")?.toDouble() ?: 0.0
                            )
                            playUrl(url, metadata, result)
                        }
                    }
                    "restorePausedMedia" -> {
                        val metadata = TrackMetadata(
                            songId = call.argument<String>("songId").orEmpty(),
                            title = call.argument<String>("title").orEmpty().ifBlank { "EmoC" },
                            artist = call.argument<String>("artist").orEmpty().ifBlank { "网易云音乐" },
                            coverUrl = call.argument<String>("coverUrl").orEmpty()
                        )
                        restorePausedMedia(
                            metadata,
                            call.argument<Number>("durationMs")?.toLong() ?: 0L
                        )
                        result.success(null)
                    }
                    "updatePlayerMetadata" -> {
                        currentTrack = TrackMetadata(
                            songId = call.argument<String>("songId").orEmpty(),
                            title = call.argument<String>("title").orEmpty().ifBlank { "EmoC" },
                            artist = call.argument<String>("artist").orEmpty().ifBlank { "网易云音乐" },
                            coverUrl = call.argument<String>("coverUrl").orEmpty()
                        )
                        val current = player
                        if (current == null) {
                            systemMediaController?.update(
                                metadata = currentTrack,
                                playing = false,
                                currentMs = 0L,
                                durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                            )
                        } else {
                            updateSystemMedia()
                        }
                        result.success(null)
                    }
                    "pause" -> {
                        userPaused = true
                        pausedByAudioFocusLoss = false
                        player?.playWhenReady = false
                        player?.pause()
                        updateSystemMedia()
                        PlaybackKeepAliveService.stop(this)
                        result.success(null)
                    }
                    "resume" -> {
                        if (!allowMixedAudio && !requestAudioFocus()) {
                            result.error("AUDIO_FOCUS_DENIED", "音频焦点被其他应用占用", null)
                            return@setMethodCallHandler
                        }
                        val current = player
                        if (current == null) {
                            result.error("NO_ACTIVE_PLAYER", "原生播放器尚未建立", null)
                            return@setMethodCallHandler
                        }
                        userPaused = false
                        pausedByAudioFocusLoss = false
                        current.playWhenReady = true
                        current.play()
                        PlaybackKeepAliveService.start(this, currentTrack)
                        updateSystemMedia()
                        result.success(null)
                    }
                    "seekTo" -> {
                        clearQueuedTrack()
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        player?.seekTo(positionMs.coerceAtLeast(0).toLong())
                        audioSpectrumDecoder?.seekTo(positionMs.toLong())
                        updateSystemMedia()
                        result.success(null)
                    }
                    "setVolume" -> {
                        playerVolume = (call.argument<Double>("volume") ?: 0.7).toFloat()
                            .coerceIn(0f, 1f)
                        player?.volume = normalizedVolume(currentTrack)
                        result.success(null)
                    }
                    "setVolumeNormalization" -> {
                        volumeNormalizationEnabled = call.argument<Boolean>("value") ?: false
                        prefs().edit().putString("volumeNormalizationEnabled", volumeNormalizationEnabled.toString()).apply()
                        player?.volume = normalizedVolume(currentTrack)
                        result.success(null)
                    }
                    "setEqualizer" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val bands = (call.argument<List<Number>>("bands") ?: emptyList())
                            .map { it.toDouble() }
                        try {
                            playbackEqualizer.configure(enabled, bands, player?.audioSessionId ?: 0)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("EQUALIZER_UNAVAILABLE", error.message, null)
                        }
                    }
                    "setAudioSpectrumEnabled" -> {
                        sharedAudioSpectrumEnabled =
                            call.argument<Boolean>("value") ?: false
                        if (sharedAudioSpectrumEnabled) {
                            startSpectrumDecoderIfNeeded()
                        } else {
                            stopSpectrumDecoder()
                        }
                        result.success(null)
                    }
                    "setAllowMixedAudio" -> {
                        val wasMixedAudio = allowMixedAudio
                        allowMixedAudio = call.argument<Boolean>("value") ?: false
                        prefs().edit()
                            .putString("allowMixedAudio", allowMixedAudio.toString())
                            .apply()
                        if (allowMixedAudio && !wasMixedAudio) {
                            abandonAudioFocus(force = true)
                        }
                        if (!allowMixedAudio && player?.isPlaying == true && !requestAudioFocus()) {
                            pauseForExternalAudio()
                        }
                        result.success(null)
                    }
                    "setDesktopLyricsEnabled" -> {
                        val enabled = call.argument<Boolean>("value") ?: false
                        val requestPermission =
                            call.argument<Boolean>("requestPermission") ?: false
                        val applied = desktopLyricsOverlay
                            ?.setEnabled(enabled, requestPermission)
                            ?: false
                        prefs().edit()
                            .putString("desktopLyricsEnabled", applied.toString())
                            .apply()
                        result.success(applied)
                    }
                    "isDesktopLyricsActive" -> {
                        result.success(desktopLyricsOverlay?.isActive() == true)
                    }
                    "desktopLyricsStyle" -> {
                        result.success(
                            desktopLyricsOverlay?.currentStyle()
                                ?: emptyMap<String, Any>()
                        )
                    }
                    "setDesktopLyricsStyle" -> {
                        val opacity = (call.argument<Double>("opacity") ?: 0.42).toFloat()
                        val fontSize = (call.argument<Double>("fontSize") ?: 18.0).toFloat()
                        val fontWeight = call.argument<Number>("fontWeight")
                            ?.toInt()
                            ?: 800
                        val locked = call.argument<Boolean>("locked") ?: false
                        val multiLine = call.argument<Boolean>("multiLine") ?: false
                        val centerLineLocked =
                            call.argument<Boolean>("centerLineLocked") ?: false
                        val autoHideInForeground =
                            call.argument<Boolean>("autoHideInForeground") ?: false
                        val autoHideWhenPaused =
                            call.argument<Boolean>("autoHideWhenPaused") ?: false
                        val followDynamicColor =
                            call.argument<Boolean>("followDynamicColor") ?: false
                        val backgroundColor = call.argument<Number>("backgroundColor")
                            ?.toInt()
                            ?: android.graphics.Color.BLACK
                        val textColor = call.argument<Number>("textColor")
                            ?.toInt()
                            ?: android.graphics.Color.WHITE
                        desktopLyricsOverlay?.updateStyle(
                            opacity = opacity,
                            fontSize = fontSize,
                            fontWeight = fontWeight,
                            locked = locked,
                            multiLine = multiLine,
                            centerLineLocked = centerLineLocked,
                            autoHideInForeground = autoHideInForeground,
                            autoHideWhenPaused = autoHideWhenPaused,
                            followDynamicColor = followDynamicColor,
                            backgroundColor = backgroundColor,
                            textColor = textColor
                        )
                        result.success(null)
                    }
                    "updateDesktopLyrics" -> {
                        desktopLyricsOverlay?.updateText(
                            text = call.argument<String>("text").orEmpty(),
                            title = call.argument<String>("title").orEmpty(),
                            artist = call.argument<String>("artist").orEmpty(),
                            playing = call.argument<Boolean>("playing") ?: false
                        )
                        result.success(null)
                    }
                    "state" -> {
                        val current = player
                        if (current == null) {
                            result.success(stateMap(false, false, 0L, 0L))
                        } else {
                            val duration = current.duration
                                .takeIf { it != C.TIME_UNSET && it > 0L } ?: 0L
                            val position = current.currentPosition.coerceAtLeast(0L)
                            val ended = current.playbackState == Player.STATE_ENDED
                            // STATE_ENDED is a hand-off state while Dart resolves the
                            // next playable item. Keep the public playback state alive
                            // unless the user explicitly paused.
                            val waitingForNext = ended && !userPaused
                            val wantsPlayback =
                                !userPaused && (current.playWhenReady || waitingForNext)
                            result.success(
                                stateMap(
                                    active = true,
                                    playing = wantsPlayback,
                                    currentMs = if (playerPrepared) position else 0L,
                                    durationMs = if (playerPrepared) duration else 0L,
                                    ended = ended
                                )
                            )
                        }
                    }
                    "stop" -> {
                        playGeneration += 1
                        userPaused = false
                        releasePlayer()
                        result.success(null)
                    }
                    "moveTaskToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "openExternalUrl" -> {
                        val url = call.argument<String>("url").orEmpty()
                        result.success(openExternalUrl(url))
                    }
                    "getAppVersion" -> {
                        result.success(updateController.installedVersion())
                    }
                    "getDownloadedUpdate" -> {
                        result.success(updateController.downloadedUpdate())
                    }
                    "checkLatestRelease" -> {
                        updateController.checkLatestRelease(
                            onSuccess = { release -> result.success(release) },
                            onError = { code, message ->
                                result.error(code, message, null)
                            }
                        )
                    }
                    "downloadUpdate" -> {
                        val release = (call.arguments as? Map<*, *>)
                            ?.entries
                            ?.associate { entry -> entry.key.toString() to entry.value }
                            ?: emptyMap()
                        updateController.downloadUpdate(
                            release = release,
                            onSuccess = { downloaded -> result.success(downloaded) },
                            onError = { code, message ->
                                result.error(code, message, null)
                            }
                        )
                    }
                    "installDownloadedUpdate" -> {
                        try {
                            result.success(updateController.installDownloaded(this))
                        } catch (error: Exception) {
                            result.error(
                                "UPDATE_INSTALL_FAILED",
                                error.message ?: "无法打开系统安装界面",
                                null
                            )
                        }
                    }
                    "consumeWidgetAction" -> {
                        result.success(intent.getStringExtra(PlaybackWidget.EXTRA_ACTION))
                        intent.removeExtra(PlaybackWidget.EXTRA_ACTION)
                    }
                    "prefsGetMany" -> {
                        val values = prefs().all
                        val keys = call.argument<List<String>>("keys").orEmpty()
                        result.success(keys.associateWith { values[it]?.toString() })
                    }
                    "prefsGet" -> {
                        val key = call.argument<String>("key").orEmpty()
                        result.success(prefs().all[key]?.toString())
                    }
                    "prefsSet" -> {
                        val key = call.argument<String>("key").orEmpty()
                        val value = call.argument<String>("value").orEmpty()
                        prefs().edit().putString(key, value).apply()
                        result.success(null)
                    }
                    "isSystemDarkMode" -> {
                        result.success(isSystemDarkMode())
                    }
                    "prefsRemove" -> {
                        val key = call.argument<String>("key").orEmpty()
                        prefs().edit().remove(key).apply()
                        result.success(null)
                    }
                    "cookiesGet" -> {
                        val url = call.argument<String>("url").orEmpty().ifBlank { "https://music.163.com/" }
                        result.success(CookieManager.getInstance().getCookie(url).orEmpty())
                    }
                    "cookiesSet" -> {
                        val url = call.argument<String>("url").orEmpty().ifBlank { "https://music.163.com/" }
                        val cookies = call.argument<String>("cookies").orEmpty()
                        restoreCookies(url, cookies, result)
                    }
                    "cookiesClear" -> {
                        clearCookies(result)
                    }
                    else -> result.notImplemented()
                }
        }
        if (player != null) {
            updateSystemMedia()
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        desktopLyricsOverlay?.refreshLayoutForDisplayChange()
        Handler(Looper.getMainLooper()).postDelayed({
            desktopLyricsOverlay?.refreshLayoutForDisplayChange()
        }, 250L)
        notifySystemThemeChanged()
    }

    private fun openExternalUrl(url: String): Boolean {
        if (url.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addCategory(Intent.CATEGORY_BROWSABLE)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun restoreCookies(url: String, cookies: String, result: MethodChannel.Result) {
        val manager = CookieManager.getInstance()
        manager.setAcceptCookie(true)
        manager.removeAllCookies {
            cookies.split(";")
                .map { it.trim() }
                .filter { it.isNotBlank() && it.contains("=") }
                .forEach { cookie ->
                    manager.setCookie(url, cookie)
                }
            manager.flush()
            result.success(null)
        }
    }

    private fun clearCookies(result: MethodChannel.Result) {
        val manager = CookieManager.getInstance()
        manager.removeAllCookies {
            manager.flush()
            result.success(null)
        }
    }

    private fun createPlayer(): ExoPlayer {
        val renderers = DefaultRenderersFactory(applicationContext).setEnableDecoderFallback(true)
        return ExoPlayer.Builder(applicationContext, renderers).build().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(), false)
            volume = normalizedVolume(currentTrack)
            setWakeMode(C.WAKE_MODE_NETWORK)
        }
    }

    private fun mediaSource(url: String, metadata: TrackMetadata): androidx.media3.exoplayer.source.MediaSource {
        val http = DefaultHttpDataSource.Factory().setUserAgent(USER_AGENT)
            .setDefaultRequestProperties(requestHeaders()).setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(12000).setReadTimeoutMs(25000)
        val item = MediaItem.Builder().setUri(url).setMediaId(metadata.songId).setTag(metadata).build()
        return ProgressiveMediaSource.Factory(DefaultDataSource.Factory(applicationContext, http))
            .createMediaSource(item)
    }

    private fun playUrl(url: String, metadata: TrackMetadata, result: MethodChannel.Result?) {
        if (sharedAppInForeground) ensureNotificationPermission()
        playGeneration += 1
        clearQueuedTrack()
        sharedPlayResult?.error("PLAY_CANCELLED", "播放请求已取消", null)
        sharedPlayResult = result
        stopSpectrumDecoder()
        userPaused = false
        pausedByAudioFocusLoss = false
        currentTrack = metadata
        currentPlaybackUrl = url
        try {
            if (!allowMixedAudio && !requestAudioFocus()) {
                sharedPlayResult?.error("AUDIO_FOCUS_DENIED", "音频焦点被其他应用占用", null)
                sharedPlayResult = null
                releasePlayer()
                return
            }
            val current = player ?: createPlayer().also { player = it }
            sharedPlayerListener?.let { current.removeListener(it) }
            attachPlayerListener(current)
            playerPrepared = false
            current.volume = normalizedVolume(metadata)
            current.setMediaSource(mediaSource(url, metadata))
            current.prepare()
            current.playWhenReady = true
            PlaybackKeepAliveService.start(this, currentTrack)
        } catch (error: Exception) {
            sharedPlayResult?.error("PLAYER_SOURCE_ERROR", "播放地址加载失败：${error.message}", null)
            sharedPlayResult = null
            releasePlayer(clearSystemMedia = false)
        }
    }

    private fun attachPlayerListener(current: ExoPlayer) {
        val generation = playGeneration
        var endedNotified = false
        val listener = object : Player.Listener {
            override fun onAudioSessionIdChanged(audioSessionId: Int) {
                if (current !== player) return
                runCatching { playbackEqualizer.attach(audioSessionId) }
            }

            override fun onPlaybackStateChanged(state: Int) {
                if (generation != playGeneration || current !== player) return
                if (state == Player.STATE_READY) {
                    playerPrepared = true
                    if (!userPaused) current.play()
                    sharedPlayResult?.success(null)
                    sharedPlayResult = null
                    updateSystemMedia()
                    startSpectrumDecoderIfNeeded()
                } else if (state == Player.STATE_ENDED) {
                    // A prepared crossfade owns the hand-off; otherwise Dart advances.
                    if (sharedCrossfade != null) return
                    updateSystemMedia()
                    if (!endedNotified) {
                        endedNotified = true
                        notifyTrackEndedWithRetries(generation, currentTrack.songId)
                    }
                }
            }

            override fun onMediaItemTransition(item: MediaItem?, reason: Int) {
                if (current !== player || reason != Player.MEDIA_ITEM_TRANSITION_REASON_AUTO) return
                val metadata = item?.localConfiguration?.tag as? TrackMetadata ?: return
                endedNotified = false
                val previousId = currentTrack.songId
                currentTrack = metadata
                current.volume = normalizedVolume(metadata)
                currentPlaybackUrl = item.localConfiguration?.uri.toString()
                stopSpectrumDecoder()
                updateSystemMedia()
                startSpectrumDecoderIfNeeded()
                notifyFlutter("trackTransition", mapOf("previousSongId" to previousId, "songId" to metadata.songId))
                mainThreadHandler.post {
                    if (current === player && current.currentMediaItemIndex > 0) {
                        current.removeMediaItems(0, current.currentMediaItemIndex)
                    }
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                if (generation != playGeneration || current !== player) return
                sharedPlayResult?.error("PLAYER_ERROR", "播放器错误：${error.errorCodeName}", null)
                sharedPlayResult = null
                releasePlayer(clearSystemMedia = false)
                notifyFlutter("playbackError", mapOf("message" to error.errorCodeName))
            }

            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (generation != playGeneration || current !== player) return
                updateSystemMedia()
            }
        }
        sharedPlayerListener = listener
        current.addListener(listener)
    }

    private fun clearQueuedTrack() {
        sharedCrossfade?.cancel()
        sharedCrossfade = null
        val current = player ?: return
        if (current.currentMediaItemIndex + 1 < current.mediaItemCount) {
            current.removeMediaItems(current.currentMediaItemIndex + 1, current.mediaItemCount)
        }
    }

    private fun queueNextTrack(expected: String, url: String, metadata: TrackMetadata, fadeMs: Long): Boolean {
        val current = player ?: return false
        if (currentTrack.songId != expected || url.isBlank() || current.playbackState == Player.STATE_ENDED) return false
        clearQueuedTrack()
        if (fadeMs == 0L) {
            current.addMediaSource(mediaSource(url, metadata))
        } else {
            val incoming = createPlayer()
            incoming.setMediaSource(mediaSource(url, metadata))
            incoming.prepare()
            sharedCrossfade = PlaybackCrossfade(current, incoming, fadeMs,
                { normalizedVolume(currentTrack) }, { normalizedVolume(metadata) }, {
                sharedCrossfade = null
                if (current.playbackState == Player.STATE_ENDED) {
                    notifyFlutter("ended", mapOf("songId" to currentTrack.songId))
                }
            }) { next ->
                val previousId = currentTrack.songId
                sharedCrossfade = null
                stopSpectrumDecoder()
                sharedPlayerListener?.let { current.removeListener(it) }
                player = next
                currentTrack = metadata
                currentPlaybackUrl = url
                playerPrepared = true
                runCatching { playbackEqualizer.attach(next.audioSessionId) }
                attachPlayerListener(next)
                updateSystemMedia()
                startSpectrumDecoderIfNeeded()
                notifyFlutter("trackTransition", mapOf("previousSongId" to previousId, "songId" to metadata.songId))
            }
        }
        return true
    }

    private fun startSpectrumDecoderIfNeeded() {
        if (!sharedAudioSpectrumEnabled || !playerPrepared) return
        val current = player ?: return
        val url = currentPlaybackUrl
        if (url.isBlank()) return
        if (!url.startsWith("http")) return
        val existing = audioSpectrumDecoder
        if (existing?.sourceUrl == url) {
            ensureSpectrumClockRunning()
            return
        }

        stopSpectrumDecoder()
        val generation = playGeneration
        lateinit var decoder: PlaybackSpectrumDecoder
        decoder = PlaybackSpectrumDecoder(
            sourceUrl = url,
            headers = requestHeaders() + ("User-Agent" to USER_AGENT)
        ) spectrum@{ frame ->
            if (
                generation != playGeneration ||
                audioSpectrumDecoder !== decoder ||
                !sharedAudioSpectrumEnabled
            ) {
                return@spectrum
            }
            mainThreadHandler.post {
                activeActivity?.get()?.notifyFlutter(
                    "audioSpectrum",
                    mapOf(
                        "bands" to frame.bands.map { it.toDouble() },
                        "rms" to frame.rms.toDouble(),
                        "centroid" to frame.centroid.toDouble()
                    )
                )
            }
        }
        audioSpectrumDecoder = decoder
        decoder.start(
            initialPositionMs = current.currentPosition.coerceAtLeast(0L),
            playing = current.isPlaying && !userPaused
        )
        ensureSpectrumClockRunning()
    }

    private fun stopSpectrumDecoder() {
        audioSpectrumDecoder?.stop()
        audioSpectrumDecoder = null
    }

    private fun ensureSpectrumClockRunning() {
        if (sharedSpectrumClockScheduled) return
        sharedSpectrumClockScheduled = true
        mainThreadHandler.post(spectrumClockRunnable)
    }

    private fun restorePausedMedia(metadata: TrackMetadata, durationMs: Long) {
        if (player != null) return
        currentTrack = metadata
        userPaused = true
        pausedByAudioFocusLoss = false
        systemMediaController?.update(
            metadata = currentTrack,
            playing = false,
            currentMs = 0L,
            durationMs = durationMs.coerceAtLeast(0L)
        )
    }

    fun handleSystemMediaAction(action: String) {
        when (action) {
            SystemMediaController.ACTION_PLAY -> {
                if (allowMixedAudio || requestAudioFocus()) {
                    userPaused = false
                    pausedByAudioFocusLoss = false
                    player?.playWhenReady = true
                    player?.play()
                    PlaybackKeepAliveService.start(this, currentTrack)
                    updateSystemMedia()
                    notifyFlutter("play")
                }
            }
            SystemMediaController.ACTION_PAUSE -> {
                userPaused = true
                pausedByAudioFocusLoss = false
                player?.playWhenReady = false
                player?.pause()
                updateSystemMedia()
                PlaybackKeepAliveService.stop(this)
                notifyFlutter("pause")
            }
            SystemMediaController.ACTION_PLAY_PAUSE -> {
                val current = player
                if (current != null && current.playWhenReady && !userPaused) {
                    handleSystemMediaAction(SystemMediaController.ACTION_PAUSE)
                } else {
                    handleSystemMediaAction(SystemMediaController.ACTION_PLAY)
                }
            }
            SystemMediaController.ACTION_PREVIOUS -> notifyFlutter("previous")
            SystemMediaController.ACTION_NEXT -> notifyFlutter("next")
        }
    }

    private fun handleSystemMediaSeek(positionMs: Long) {
        clearQueuedTrack()
        val targetMs = positionMs.coerceAtLeast(0L)
        player?.seekTo(targetMs)
        audioSpectrumDecoder?.seekTo(targetMs)
        updateSystemMedia()
        notifyFlutter("seek", mapOf("positionMs" to targetMs))
    }

    private fun notifyFlutter(action: String, arguments: Map<String, Any> = emptyMap()) {
        dispatchFlutterCommand(action, arguments)
    }

    private fun notifyTrackEndedWithRetries(generation: Int, songId: String) {
        // A stopped Flutter UI can take a moment to resume its isolate. Keep the
        // foreground service alive and retry the hand-off until a new player
        // generation starts. Dart de-duplicates these events.
        val delays = longArrayOf(0L, 1_500L, 4_000L, 8_000L, 14_000L)
        delays.forEach { delayMs ->
            Handler(Looper.getMainLooper()).postDelayed({
                val current = player ?: return@postDelayed
                if (generation != playGeneration ||
                    current.playbackState != Player.STATE_ENDED ||
                    currentTrack.songId != songId ||
                    userPaused
                ) {
                    return@postDelayed
                }
                PlaybackKeepAliveService.start(this, currentTrack)
                notifyFlutter("ended", mapOf("songId" to songId))
            }, delayMs)
        }
    }

    private fun notifySystemThemeChanged() {
        Handler(Looper.getMainLooper()).post {
            nativeChannel?.invokeMethod(
                "systemThemeChanged",
                mapOf("dark" to isSystemDarkMode())
            )
        }
    }

    private fun isSystemDarkMode(): Boolean {
        return (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    }

    private fun updateSystemMedia() {
        val current = player ?: return
        val duration = current.duration.takeIf { it != C.TIME_UNSET && it > 0L } ?: 0L
        val position = current.currentPosition.coerceAtLeast(0L)
        val ended = current.playbackState == Player.STATE_ENDED
        // Keep the media session and foreground service alive while Flutter
        // resolves the next playable item (including VIP skip chains).
        val waitingForNext = ended && !userPaused
        val playing = !userPaused && (current.playWhenReady || waitingForNext)
        PlaybackWidget.update(this, currentTrack, playing)
        systemMediaController?.update(
            metadata = currentTrack,
            playing = playing,
            currentMs = if (playerPrepared) position else 0L,
            durationMs = if (playerPrepared) duration else 0L
        )
        if (playing || waitingForNext) {
            PlaybackKeepAliveService.start(this, currentTrack)
        }
    }

    private fun keepPlaybackServiceAliveIfNeeded() {
        val current = player ?: return
        if (current.playWhenReady && !userPaused) {
            PlaybackKeepAliveService.start(this, currentTrack)
            updateSystemMedia()
        }
    }

    private fun stateMap(
        active: Boolean,
        playing: Boolean,
        currentMs: Long,
        durationMs: Long,
        ended: Boolean = false
    ): Map<String, Any> {
        val transitioning = sharedCrossfade != null && ended && !userPaused
        val state = mutableMapOf<String, Any>(
            "active" to active,
            "playing" to (playing || transitioning),
            "currentMs" to currentMs.coerceAtLeast(0L),
            "durationMs" to durationMs.coerceAtLeast(0L),
            "songId" to currentTrack.songId,
            "title" to currentTrack.title,
            "artist" to currentTrack.artist,
            "coverUrl" to currentTrack.coverUrl,
            "coverSongId" to if (currentTrack.coverUrl.startsWith("http")) {
                currentTrack.songId
            } else {
                ""
            },
            "ended" to (ended && !transitioning)
        )
        val colorUrl = systemMediaController?.currentCoverColorUrl().orEmpty()
        val colorSongId = systemMediaController?.currentCoverColorSongId().orEmpty()
        val color = systemMediaController?.currentCoverColor()
        if (color != null && (colorUrl.isNotEmpty() || colorSongId.isNotEmpty())) {
            state["coverColor"] = color
            state["coverColorUrl"] = colorUrl
            state["coverColorSongId"] = colorSongId
        }
        return state
    }

    private fun requestHeaders(): Map<String, String> {
        return mapOf(
            "Referer" to "https://music.163.com/",
            "Origin" to "https://music.163.com",
            "Accept" to "*/*",
            "Connection" to "keep-alive"
        )
    }

    private fun prefs() = getSharedPreferences("emoc", MODE_PRIVATE)

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (allowMixedAudio) return@OnAudioFocusChangeListener
        val current = player ?: return@OnAudioFocusChangeListener
        when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                current.volume = normalizedVolume(currentTrack)
                if (pausedByAudioFocusLoss && !userPaused) {
                    pausedByAudioFocusLoss = false
                    current.playWhenReady = true
                    current.play()
                    PlaybackKeepAliveService.start(this, currentTrack)
                    notifyFlutter("play")
                }
                updateSystemMedia()
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                if (current.isPlaying || current.playWhenReady) {
                    pausedByAudioFocusLoss = true
                }
                current.pause()
                updateSystemMedia()
                notifyFlutter("audioFocusPaused")
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                if (current.isPlaying) {
                    pausedByAudioFocusLoss = true
                }
                current.pause()
                updateSystemMedia()
                notifyFlutter("audioFocusPaused")
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                current.volume = normalizedVolume(currentTrack) * 0.25f
            }
        }
    }

    private fun audioManager(): AudioManager {
        return getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    private fun requestAudioFocus(): Boolean {
        if (allowMixedAudio) return true
        val manager = audioManager()
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = audioFocusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    PlatformAudioAttributes.Builder()
                        .setUsage(PlatformAudioAttributes.USAGE_MEDIA)
                        .setContentType(PlatformAudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()
                .also { audioFocusRequest = it }
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
        return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus(force: Boolean = false) {
        if (allowMixedAudio && !force) return
        val manager = audioManager()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(audioFocusChangeListener)
        }
    }

    private fun releasePlayer(
        clearSystemMedia: Boolean = true,
        preserveAudioFocus: Boolean = false
    ) {
        sharedCrossfade?.cancel()
        sharedCrossfade = null
        sharedPlayResult?.error("PLAY_CANCELLED", "播放请求已取消", null)
        sharedPlayResult = null
        sharedPlayerListener = null
        playerPrepared = false
        pausedByAudioFocusLoss = false
        stopSpectrumDecoder()
        playbackEqualizer.close()
        player?.release()
        player = null
        currentPlaybackUrl = ""
        PlaybackWidget.update(this, currentTrack, false)
        if (clearSystemMedia) {
            systemMediaController?.cancel()
            PlaybackKeepAliveService.stop(this)
        }
        if (!preserveAudioFocus) {
            abandonAudioFocus()
        }
    }

    private fun pauseForExternalAudio() {
        val current = player ?: return
        userPaused = true
        pausedByAudioFocusLoss = false
        current.playWhenReady = false
        current.pause()
        updateSystemMedia()
        PlaybackKeepAliveService.stop(this)
        notifyFlutter("pause")
    }

    private fun pauseForAudioRouteLoss() {
        val current = player ?: return
        if (!current.isPlaying && !current.playWhenReady) return
        userPaused = true
        pausedByAudioFocusLoss = false
        current.playWhenReady = false
        current.pause()
        updateSystemMedia()
        PlaybackKeepAliveService.stop(this)
        notifyFlutter("headsetDisconnected")
    }

    private fun registerAudioRouteWatchers() {
        if (!noisyReceiverRegistered) {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(noisyReceiver, filter)
            }
            noisyReceiverRegistered = true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            audioDeviceCallback != null &&
            !audioDeviceCallbackRegistered
        ) {
            audioManager().registerAudioDeviceCallback(
                audioDeviceCallback,
                Handler(Looper.getMainLooper())
            )
            audioDeviceCallbackRegistered = true
        }
    }

    private fun unregisterAudioRouteWatchers() {
        if (noisyReceiverRegistered) {
            try {
                unregisterReceiver(noisyReceiver)
            } catch (_: Exception) {
            }
            noisyReceiverRegistered = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            audioDeviceCallback != null &&
            audioDeviceCallbackRegistered
        ) {
            audioManager().unregisterAudioDeviceCallback(audioDeviceCallback)
            audioDeviceCallbackRegistered = false
        }
    }

    private fun isHeadphoneRoute(device: AudioDeviceInfo): Boolean {
        return when (device.type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_HEADSET -> true
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    device.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                        device.type == AudioDeviceInfo.TYPE_BLE_SPEAKER
                } else {
                    false
                }
            }
        }
    }

    private fun shouldKeepPlaybackAliveOnDestroy(): Boolean {
        val current = player ?: return false
        return current.playWhenReady && !userPaused
    }

    override fun onDestroy() {
        localMusicController?.close()
        localMusicController = null
        ownedAppUpdateController?.close()
          ownedAppUpdateController = null
        val isActiveActivity = activeActivity?.get() === this
        if (isActiveActivity && shouldKeepPlaybackAliveOnDestroy()) {
            PlaybackKeepAliveService.start(this, currentTrack)
            updateSystemMedia()
            super.onDestroy()
            return
        }
        if (!isActiveActivity) {
            unregisterAudioRouteWatchers()
            ownedNativeChannel?.setMethodCallHandler(null)
            ownedNativeChannel = null
            ownedSystemMediaController = null
            super.onDestroy()
            return
        }
        playGeneration += 1
        releasePlayer()
        unregisterAudioRouteWatchers()
        sharedNetworkMonitor?.close()
        sharedNetworkMonitor = null
        desktopLyricsOverlay?.release()
        desktopLyricsOverlay = null
        systemMediaController?.release()
        systemMediaController = null
        ownedNativeChannel?.setMethodCallHandler(null)
        ownedNativeChannel = null
        ownedSystemMediaController = null
        activeActivity = null
        nativeChannel = null
        super.onDestroy()
    }

    companion object {
        private var sharedPlayerListener: Player.Listener? = null
        private var sharedPlayResult: MethodChannel.Result? = null
        private var sharedCrossfade: PlaybackCrossfade? = null
        fun hasPlaybackSession(): Boolean = sharedNativeChannel != null && sharedPlayer != null
        private var sharedNetworkMonitor: NetworkStateMonitor? = null
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 16303
        const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

        // Playback state belongs to the process, not to one FlutterActivity.
        // Android can recreate the task while the foreground playback service
        // keeps the process alive; sharing this state lets the new Activity
        // reconnect to the existing player instead of creating a second media
        // session or losing controls for the track that is still playing.
        private var sharedPlayer: ExoPlayer? = null
        private val sharedPlaybackEqualizer = PlaybackEqualizer()
        private var sharedNativeChannel: MethodChannel? = null
        private var sharedSystemMediaController: SystemMediaController? = null
        private var sharedDesktopLyricsOverlay: DesktopLyricsOverlayController? = null
        @Volatile
        private var sharedAppInForeground = false
        private var sharedCurrentTrack = TrackMetadata()
        private var sharedPlayerVolume = 0.7f
        private var sharedVolumeNormalizationEnabled = false
        private var sharedUserPaused = false
        private var sharedPausedByAudioFocusLoss = false
        private var sharedAllowMixedAudio = false
        private var sharedAudioFocusRequest: AudioFocusRequest? = null
        @Volatile
        private var sharedPlayerPrepared = false
        @Volatile
        private var sharedAudioSpectrumDecoder: PlaybackSpectrumDecoder? = null
        private var sharedCurrentPlaybackUrl = ""
        @Volatile
        private var sharedAudioSpectrumEnabled = false
        private val mainThreadHandler = Handler(Looper.getMainLooper())
        private val mediaSessionCallbacks = object : SystemMediaController.Callbacks {
            override fun onPlay() = dispatchMediaAction(SystemMediaController.ACTION_PLAY)

            override fun onPause() = dispatchMediaAction(SystemMediaController.ACTION_PAUSE)

            override fun onPrevious() =
                dispatchMediaAction(SystemMediaController.ACTION_PREVIOUS)

            override fun onNext() = dispatchMediaAction(SystemMediaController.ACTION_NEXT)

            override fun onSeekTo(positionMs: Long) {
                activeActivity?.get()?.handleSystemMediaSeek(positionMs)
            }

            override fun onCoverColor(songId: String, coverUrl: String, color: Int) {
                dispatchFlutterCommand(
                    "coverColorChanged",
                    mapOf("songId" to songId, "coverUrl" to coverUrl, "color" to color)
                )
            }
        }
        private var sharedSpectrumClockScheduled = false
        private val spectrumClockRunnable = object : Runnable {
            override fun run() {
                val decoder = sharedAudioSpectrumDecoder
                val current = sharedPlayer
                if (decoder == null || current == null || !sharedAudioSpectrumEnabled) {
                    sharedSpectrumClockScheduled = false
                    return
                }
                runCatching {
                    decoder.updatePlaybackState(
                        positionMs = current.currentPosition.coerceAtLeast(0L),
                        playing = current.isPlaying && !sharedUserPaused
                    )
                }
                mainThreadHandler.postDelayed(this, 35L)
            }
        }

        @Volatile
        private var sharedPlayGeneration = 0

        private var activeActivity: WeakReference<MainActivity>? = null

        fun dispatchMediaAction(action: String) {
            when (action) {
                SystemMediaController.ACTION_PREVIOUS -> {
                    MediaTransportGate.recordTransportCommand()
                    dispatchFlutterCommand("previous")
                }
                SystemMediaController.ACTION_NEXT -> {
                    MediaTransportGate.recordTransportCommand()
                    dispatchFlutterCommand("next")
                }
                else -> activeActivity?.get()?.handleSystemMediaAction(action)
            }
        }

        private fun dispatchFlutterCommand(
            action: String,
            arguments: Map<String, Any> = emptyMap()
        ) {
            val payload = HashMap<String, Any>(arguments)
            payload["action"] = action
            mainThreadHandler.post {
                sharedNativeChannel?.invokeMethod("systemMediaCommand", payload)
            }
        }
    }
}
