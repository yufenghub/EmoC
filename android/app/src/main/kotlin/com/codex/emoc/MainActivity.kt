package com.codex.emoc

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

@UnstableApi
class MainActivity : FlutterActivity() {
    private var player: ExoPlayer? = null
    private var nativeChannel: MethodChannel? = null
    private var systemMediaController: SystemMediaController? = null
    private var desktopLyricsOverlay: DesktopLyricsOverlayController? = null
    private var currentTrack = TrackMetadata()
    private var playerVolume = 0.7f
    private var userPaused = false
    private var pausedByAudioFocusLoss = false
    private var allowMixedAudio = false
    private var noisyReceiverRegistered = false
    private var audioDeviceCallbackRegistered = false
    private var audioFocusRequest: AudioFocusRequest? = null

    @Volatile
    private var playerPrepared = false

    @Volatile
    private var playGeneration = 0

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
        activeActivity = WeakReference(this)
        allowMixedAudio = prefs().getString("allowMixedAudio", "false") == "true"
        desktopLyricsOverlay = DesktopLyricsOverlayController(this)
        registerAudioRouteWatchers()
    }

    override fun onResume() {
        super.onResume()
        activeActivity = WeakReference(this)
        desktopLyricsOverlay?.setAppInForeground(true)
        notifySystemThemeChanged()
    }

    override fun onPause() {
        desktopLyricsOverlay?.setAppInForeground(false)
        keepPlaybackServiceAliveIfNeeded()
        super.onPause()
    }

    override fun onStop() {
        keepPlaybackServiceAliveIfNeeded()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        activeActivity = WeakReference(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeActivity = WeakReference(this)
        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "emoc/native")
        systemMediaController = SystemMediaController(this, object : SystemMediaController.Callbacks {
            override fun onPlay() = handleSystemMediaAction(SystemMediaController.ACTION_PLAY)
            override fun onPause() = handleSystemMediaAction(SystemMediaController.ACTION_PAUSE)
            override fun onPrevious() = handleSystemMediaAction(SystemMediaController.ACTION_PREVIOUS)
            override fun onNext() = handleSystemMediaAction(SystemMediaController.ACTION_NEXT)
            override fun onSeekTo(positionMs: Long) {
                player?.seekTo(positionMs.coerceAtLeast(0L))
                updateSystemMedia()
                notifyFlutter("seek", mapOf("positionMs" to positionMs.coerceAtLeast(0L)))
            }
        })
        nativeChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "playUrl" -> {
                        val url = call.argument<String>("url").orEmpty()
                        if (url.isBlank()) {
                            result.error("EMPTY_URL", "播放地址为空", null)
                        } else {
                            val metadata = TrackMetadata(
                                songId = call.argument<String>("songId").orEmpty(),
                                title = call.argument<String>("title").orEmpty().ifBlank { "EmoC" },
                                artist = call.argument<String>("artist").orEmpty().ifBlank { "网易云音乐" },
                                coverUrl = call.argument<String>("coverUrl").orEmpty()
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
                        userPaused = false
                        pausedByAudioFocusLoss = false
                        player?.playWhenReady = true
                        player?.play()
                        updateSystemMedia()
                        result.success(null)
                    }
                    "seekTo" -> {
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        player?.seekTo(positionMs.coerceAtLeast(0).toLong())
                        updateSystemMedia()
                        result.success(null)
                    }
                    "setVolume" -> {
                        playerVolume = (call.argument<Double>("volume") ?: 0.7).toFloat()
                            .coerceIn(0f, 1f)
                        player?.volume = playerVolume
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
                            artist = call.argument<String>("artist").orEmpty()
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
                            val wantsPlayback = current.playWhenReady && !ended
                            result.success(
                                stateMap(
                                    active = true,
                                    playing = wantsPlayback && !userPaused,
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
                    "prefsGet" -> {
                        val key = call.argument<String>("key").orEmpty()
                        result.success(prefs().getString(key, null))
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

    private fun playUrl(url: String, metadata: TrackMetadata, result: MethodChannel.Result) {
        val generation = playGeneration + 1
        playGeneration = generation
        val previousPlayer = player
        val keepPreviousSystemMedia =
            previousPlayer != null &&
                previousPlayer.playWhenReady &&
                !userPaused &&
                previousPlayer.playbackState != Player.STATE_ENDED
        if (keepPreviousSystemMedia) {
            updateSystemMedia()
        }
        userPaused = false
        pausedByAudioFocusLoss = false
        if (playerVolume <= 0.02f) {
            playerVolume = 0.7f
        }
        releasePlayer(clearSystemMedia = !keepPreviousSystemMedia)
        currentTrack = metadata
        if (!keepPreviousSystemMedia) {
            PlaybackKeepAliveService.start(this, currentTrack)
        }

        var replied = false
        fun successOnce() {
            if (!replied) {
                replied = true
                result.success(null)
            }
        }
        fun errorOnce(code: String, message: String) {
            if (!replied) {
                replied = true
                result.error(code, message, null)
            }
        }

        try {
            if (!allowMixedAudio && !requestAudioFocus()) {
                systemMediaController?.cancel()
                PlaybackKeepAliveService.stop(this)
                errorOnce("AUDIO_FOCUS_DENIED", "音频焦点被其他应用占用")
                return
            }
            val renderersFactory = DefaultRenderersFactory(this)
                .setEnableDecoderFallback(true)
            val exoPlayer = ExoPlayer.Builder(this, renderersFactory).build()
            player = exoPlayer
            playerPrepared = false

            exoPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                false
            )
            exoPlayer.volume = playerVolume
            exoPlayer.setWakeMode(C.WAKE_MODE_NETWORK)
            exoPlayer.playbackParameters = PlaybackParameters(1.0f)
            exoPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    if (generation != playGeneration) return
                    if (playbackState == Player.STATE_READY) {
                        playerPrepared = true
                        exoPlayer.playbackParameters = PlaybackParameters(1.0f)
                        if (!userPaused && !exoPlayer.isPlaying) {
                            exoPlayer.play()
                        }
                        PlaybackKeepAliveService.start(this@MainActivity, currentTrack)
                        updateSystemMedia()
                        successOnce()
                    }
                    if (playbackState == Player.STATE_ENDED) {
                        updateSystemMedia()
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    if (generation != playGeneration) {
                        successOnce()
                        return
                    }
                    playerPrepared = false
                    releasePlayer()
                    errorOnce("PLAYER_ERROR", "播放器错误：${error.errorCodeName}")
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (generation == playGeneration && isPlaying) {
                        exoPlayer.playbackParameters = PlaybackParameters(1.0f)
                    }
                    if (generation == playGeneration) {
                        updateSystemMedia()
                    }
                }
            })

            val dataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(USER_AGENT)
                .setDefaultRequestProperties(requestHeaders())
                .setAllowCrossProtocolRedirects(true)
                .setConnectTimeoutMs(12000)
                .setReadTimeoutMs(25000)
            val mediaSource = ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(url))
            exoPlayer.setMediaSource(mediaSource)
            exoPlayer.prepare()
            exoPlayer.playWhenReady = true
        } catch (error: Exception) {
            releasePlayer()
            errorOnce("PLAYER_SOURCE_ERROR", "播放地址加载失败：${error.message}")
        }
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

    private fun notifyFlutter(action: String, arguments: Map<String, Any> = emptyMap()) {
        val payload = HashMap<String, Any>(arguments)
        payload["action"] = action
        Handler(Looper.getMainLooper()).post {
            nativeChannel?.invokeMethod("systemMediaCommand", payload)
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
        val playing = current.playWhenReady && !userPaused && !ended
        systemMediaController?.update(
            metadata = currentTrack,
            playing = playing,
            currentMs = if (playerPrepared) position else 0L,
            durationMs = if (playerPrepared) duration else 0L
        )
        if (playing) {
            PlaybackKeepAliveService.start(this, currentTrack)
        }
    }

    private fun keepPlaybackServiceAliveIfNeeded() {
        val current = player ?: return
        val ended = current.playbackState == Player.STATE_ENDED
        if (current.playWhenReady && !userPaused && !ended) {
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
        val state = mutableMapOf<String, Any>(
            "active" to active,
            "playing" to playing,
            "currentMs" to currentMs.coerceAtLeast(0L),
            "durationMs" to durationMs.coerceAtLeast(0L),
            "songId" to currentTrack.songId,
            "title" to currentTrack.title,
            "artist" to currentTrack.artist,
            "coverUrl" to currentTrack.coverUrl,
            "ended" to ended
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
                current.volume = playerVolume
                if (pausedByAudioFocusLoss && !userPaused) {
                    pausedByAudioFocusLoss = false
                    current.playWhenReady = true
                    current.play()
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
                current.volume = playerVolume * 0.25f
            }
        }
    }

    private fun audioManager(): AudioManager {
        return getSystemService(Context.AUDIO_SERVICE) as AudioManager
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

    private fun releasePlayer(clearSystemMedia: Boolean = true) {
        playerPrepared = false
        pausedByAudioFocusLoss = false
        player?.release()
        player = null
        if (clearSystemMedia) {
            systemMediaController?.cancel()
            PlaybackKeepAliveService.stop(this)
        }
        abandonAudioFocus()
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
        val ended = current.playbackState == Player.STATE_ENDED
        return current.playWhenReady && !userPaused && !ended
    }

    override fun onDestroy() {
        if (shouldKeepPlaybackAliveOnDestroy()) {
            PlaybackKeepAliveService.start(this, currentTrack)
            updateSystemMedia()
            super.onDestroy()
            return
        }
        playGeneration += 1
        releasePlayer()
        unregisterAudioRouteWatchers()
        desktopLyricsOverlay?.release()
        desktopLyricsOverlay = null
        systemMediaController?.release()
        systemMediaController = null
        if (activeActivity?.get() == this) {
            activeActivity = null
        }
        super.onDestroy()
    }

    companion object {
        const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

        private var activeActivity: WeakReference<MainActivity>? = null

        fun dispatchMediaAction(action: String) {
            activeActivity?.get()?.handleSystemMediaAction(action)
        }
    }
}
