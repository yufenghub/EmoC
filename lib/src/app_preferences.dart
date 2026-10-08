part of '../main.dart';

extension AppPreferences on AppModel {
  Future<void> _restorePreferences() async {
    final values = await NativeBridge.getPreferences(const [
      'themeMode',
      'visualStyle',
      'motionLevel',
      'interfacePreferences',
      'darkMode',
      'pinnedPlaylistIds',
      'dynamicColorEnabled',
      'themeSeedColor',
      'showSongCovers',
      'lyricsPlayerStyle',
      'desktopLyricsEnabled',
      'desktopLyricsOpacity',
      'desktopLyricsFontSize',
      'desktopLyricsFontWeight',
      'desktopLyricsLocked',
      'desktopLyricsMultiLine',
      'desktopLyricsCenterLineLocked',
      'desktopLyricsAutoHideInForeground',
      'desktopLyricsAutoHideWhenPaused',
      'desktopLyricsFollowDynamicColor',
      'desktopLyricsBackgroundColor',
      'desktopLyricsTextColor',
      'desiredVolume',
      'audioQuality',
      'continuousPlayback',
      'crossfadeSeconds',
      'playbackMode',
      'allowMixedAudio',
      'volumeNormalizationEnabled',
      'equalizerSettings',
      'rememberLogin',
      'savedLoggedIn',
      'savedAccountName',
      'savedAvatarUrl',
    ]);
    bool flag(String key, [bool fallback = false]) =>
        values[key] == null ? fallback : values[key] == 'true';
    int integer(String key, int fallback) =>
        int.tryParse(values[key] ?? '') ?? fallback;
    double decimal(String key, double fallback) =>
        double.tryParse(values[key] ?? '') ?? fallback;

    final savedTheme = values['themeMode'];
    visualStyle = values['visualStyle'] == 'simple' ? 'simple' : 'liquid';
    motionLevel = integer('motionLevel', motionLevel).clamp(0, 2);
    restoreInterfacePreferences(values['interfacePreferences']);
    themeMode = const ['system', 'light', 'dark'].contains(savedTheme)
        ? savedTheme!
        : values['darkMode'] == null
        ? 'system'
        : flag('darkMode')
        ? 'dark'
        : 'light';
    await _refreshSystemThemeFromNative(notify: false);
    try {
      pinnedPlaylistIds = _listOf(
        jsonDecode(values['pinnedPlaylistIds'] ?? '[]'),
      ).map(_stringOf).where((id) => id.isNotEmpty).toList(growable: false);
    } on FormatException {
      pinnedPlaylistIds = const [];
    }
    dynamicColorEnabled = flag('dynamicColorEnabled', dynamicColorEnabled);
    if (dynamicColorEnabled) {
      themeSeedColor = Color(integer('themeSeedColor', 0xFF3F7BFF));
    }
    showSongCovers = flag('showSongCovers', true);
    continuousPlayback = flag('continuousPlayback', true);
    crossfadeSeconds = integer(
      'crossfadeSeconds',
      crossfadeSeconds,
    ).clamp(0, 8);
    lyricsPlayerStyle = integer('lyricsPlayerStyle', 0).clamp(0, 2);
    desktopLyricsEnabled = flag('desktopLyricsEnabled');
    desktopLyricsOpacity = decimal(
      'desktopLyricsOpacity',
      desktopLyricsOpacity,
    ).clamp(0, 0.85);
    desktopLyricsFontSize = decimal(
      'desktopLyricsFontSize',
      desktopLyricsFontSize,
    ).clamp(14, 32);
    desktopLyricsFontWeight = integer(
      'desktopLyricsFontWeight',
      desktopLyricsFontWeight,
    ).clamp(300, 900);
    desktopLyricsLocked = flag('desktopLyricsLocked');
    desktopLyricsMultiLine = flag('desktopLyricsMultiLine');
    desktopLyricsCenterLineLocked = flag('desktopLyricsCenterLineLocked');
    desktopLyricsAutoHideInForeground = flag(
      'desktopLyricsAutoHideInForeground',
    );
    desktopLyricsAutoHideWhenPaused = flag('desktopLyricsAutoHideWhenPaused');
    desktopLyricsFollowDynamicColor = flag('desktopLyricsFollowDynamicColor');
    desktopLyricsBackgroundColor = Color(
      integer(
        'desktopLyricsBackgroundColor',
        desktopLyricsBackgroundColor.toARGB32(),
      ),
    );
    desktopLyricsTextColor = Color(
      integer('desktopLyricsTextColor', desktopLyricsTextColor.toARGB32()),
    );
    desiredVolume = decimal('desiredVolume', desiredVolume).clamp(0, 1);
    player = _playerWith(volume: desiredVolume);
    final quality = values['audioQuality'];
    if (_validAudioQuality(quality)) audioQuality = quality!;
    final mode = values['playbackMode'];
    if (_validPlaybackMode(mode)) player = _playerWith(mode: mode);
    allowMixedAudio = flag('allowMixedAudio', allowMixedAudio);
    volumeNormalizationEnabled = flag(
      'volumeNormalizationEnabled',
      volumeNormalizationEnabled,
    );
    try {
      final equalizer = _mapOf(jsonDecode(values['equalizerSettings'] ?? '{}'));
      equalizerEnabled = equalizer['enabled'] == true;
      final preset = _stringOf(equalizer['preset']);
      equalizerPreset = equalizerPresets.containsKey(preset) ? preset : 'flat';
      final bands = _listOf(equalizer['bands']);
      if (bands.length == 5) {
        equalizerBands = bands
            .map(
              (value) => (value is num ? value.toDouble() : 0.0)
                  .clamp(-12.0, 12.0)
                  .toDouble(),
            )
            .toList(growable: false);
      } else {
        equalizerBands = List<double>.from(equalizerPresets[equalizerPreset]!);
      }
    } on FormatException {
      equalizerEnabled = false;
    }
    rememberLogin = flag('rememberLogin', true);
    if (rememberLogin && flag('savedLoggedIn')) {
      loggedIn = true;
      loginGateVisible = false;
      loginLoading = false;
      loginMessage = status = '正在恢复上次登录状态';
      accountName = values['savedAccountName'] ?? accountName;
      avatarUrl = values['savedAvatarUrl'] ?? avatarUrl;
      _restoreLoginOnLoad = _trustSavedLogin = true;
    }
    unawaited(_restoreNativePreferences());
  }

  Future<void> _restoreNativePreferences() async {
    try {
      await NativeBridge.setAllowMixedAudio(allowMixedAudio);
      await NativeBridge.setVolumeNormalization(volumeNormalizationEnabled);
      await NativeBridge.setEqualizer(equalizerEnabled, equalizerBands);
      await _applyDesktopLyricsStyle();
      if (desktopLyricsEnabled) await _restoreDesktopLyricsOverlay();
    } on PlatformException catch (error) {
      debugPrint('Native preferences: ${error.code}');
    } on MissingPluginException {
      // The native bridge is unavailable in non-Android previews.
    }
  }
}
