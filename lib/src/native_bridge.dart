part of '../main.dart';

typedef SystemMediaCommandHandler =
    Future<void> Function(String action, Map<String, dynamic> arguments);

@immutable
class AudioSpectrumFrame {
  const AudioSpectrumFrame({
    this.bands = const <double>[],
    this.rms = 0,
    this.centroid = 0,
  });

  factory AudioSpectrumFrame.fromMap(Map<String, dynamic> map) {
    final rawBands = map['bands'];
    return AudioSpectrumFrame(
      bands: rawBands is List
          ? rawBands
                .whereType<num>()
                .map((value) => value.toDouble().clamp(0.0, 1.0).toDouble())
                .toList(growable: false)
          : const <double>[],
      rms: _doubleOf(map['rms']).clamp(0.0, 1.0).toDouble(),
      centroid: _doubleOf(map['centroid']).clamp(0.0, 1.0).toDouble(),
    );
  }

  final List<double> bands;
  final double rms;
  final double centroid;
}

class NativeBridge {
  static final ValueNotifier<AudioSpectrumFrame> audioSpectrum =
      ValueNotifier<AudioSpectrumFrame>(const AudioSpectrumFrame());

  static void setSystemCommandHandler(SystemMediaCommandHandler handler) {
    _nativeChannel.setMethodCallHandler((call) async {
      final args = _mapOf(call.arguments);
      if (call.method == 'systemThemeChanged') {
        await handler('__systemThemeChanged', args);
        return null;
      }
      if (call.method != 'systemMediaCommand') return null;
      final action = _stringOf(args['action']);
      if (action == 'audioSpectrum') {
        audioSpectrum.value = AudioSpectrumFrame.fromMap(args);
        return null;
      }
      if (action.isNotEmpty) {
        await handler(action, args);
      }
      return null;
    });
  }

  static Future<String?> getString(String key) {
    return _nativeChannel.invokeMethod<String>('prefsGet', {'key': key});
  }

  static Future<void> setString(String key, String value) {
    return _nativeChannel.invokeMethod('prefsSet', {
      'key': key,
      'value': value,
    });
  }

  static Future<void> removeString(String key) {
    return _nativeChannel.invokeMethod('prefsRemove', {'key': key});
  }

  static Future<bool> isSystemDarkMode() async {
    return await _nativeChannel.invokeMethod<bool>('isSystemDarkMode') ?? false;
  }

  static Future<String> getCookies(String url) async {
    return await _nativeChannel.invokeMethod<String>('cookiesGet', {
          'url': url,
        }) ??
        '';
  }

  static Future<void> setCookies(String url, String cookies) {
    return _nativeChannel.invokeMethod('cookiesSet', {
      'url': url,
      'cookies': cookies,
    });
  }

  static Future<void> clearCookies() {
    return _nativeChannel.invokeMethod('cookiesClear');
  }

  static Future<void> pausePlayer() {
    return _nativeChannel.invokeMethod('pause');
  }

  static Future<void> resumePlayer() {
    return _nativeChannel.invokeMethod('resume');
  }

  static Future<void> stopPlayer() {
    return _nativeChannel.invokeMethod('stop');
  }

  static Future<void> moveTaskToBack() {
    return _nativeChannel.invokeMethod('moveTaskToBack');
  }

  static Future<bool> openExternalUrl(String url) async {
    return await _nativeChannel.invokeMethod<bool>('openExternalUrl', {
          'url': url,
        }) ??
        false;
  }

  static Future<void> playUrl(String url, PlayerSnapshot player) {
    return _nativeChannel.invokeMethod('playUrl', {
      'url': url,
      'songId': player.songId,
      'title': player.title,
      'artist': player.displayArtist,
      'coverUrl': player.coverUrl,
      'durationMs': player.durationMilliseconds,
    });
  }

  static Future<void> updatePlayerMetadata(PlayerSnapshot player) {
    return _nativeChannel.invokeMethod('updatePlayerMetadata', {
      'songId': player.songId,
      'title': player.title,
      'artist': player.displayArtist,
      'coverUrl': player.coverUrl,
      'durationMs': player.durationMilliseconds,
    });
  }

  static Future<void> restorePausedMedia(PlayerSnapshot player) {
    return _nativeChannel.invokeMethod('restorePausedMedia', {
      'songId': player.songId,
      'title': player.title,
      'artist': player.displayArtist,
      'coverUrl': player.coverUrl,
      'durationMs': player.durationMilliseconds,
    });
  }

  static Future<void> seekPlayer(Duration position) {
    return _nativeChannel.invokeMethod('seekTo', {
      'positionMs': position.inMilliseconds,
    });
  }

  static Future<void> setPlayerVolume(double value) {
    return _nativeChannel.invokeMethod('setVolume', {
      'volume': value.clamp(0, 1).toDouble(),
    });
  }

  static Future<void> setAllowMixedAudio(bool value) {
    return _nativeChannel.invokeMethod('setAllowMixedAudio', {'value': value});
  }

  static Future<void> setAudioSpectrumEnabled(bool value) {
    if (!value) {
      audioSpectrum.value = const AudioSpectrumFrame();
    }
    return _nativeChannel.invokeMethod('setAudioSpectrumEnabled', {
      'value': value,
    });
  }

  static Future<bool> setDesktopLyricsEnabled(
    bool value, {
    bool requestPermission = false,
  }) async {
    return await _nativeChannel.invokeMethod<bool>('setDesktopLyricsEnabled', {
          'value': value,
          'requestPermission': requestPermission,
        }) ??
        false;
  }

  static Future<bool> isDesktopLyricsActive() async {
    return await _nativeChannel.invokeMethod<bool>('isDesktopLyricsActive') ??
        false;
  }

  static Future<Map<String, dynamic>> currentDesktopLyricsStyle() async {
    final style = await _nativeChannel.invokeMapMethod<String, dynamic>(
      'desktopLyricsStyle',
    );
    return style ?? const <String, dynamic>{};
  }

  static Future<void> setDesktopLyricsStyle({
    required double opacity,
    required double fontSize,
    required int fontWeight,
    required bool locked,
    required bool multiLine,
    required bool centerLineLocked,
    required bool autoHideInForeground,
    required bool autoHideWhenPaused,
    required bool followDynamicColor,
    required int backgroundColor,
    required int textColor,
  }) {
    return _nativeChannel.invokeMethod('setDesktopLyricsStyle', {
      'opacity': opacity.clamp(0, 1).toDouble(),
      'fontSize': fontSize.clamp(12, 40).toDouble(),
      'fontWeight': fontWeight.clamp(300, 900),
      'locked': locked,
      'multiLine': multiLine,
      'centerLineLocked': centerLineLocked,
      'autoHideInForeground': autoHideInForeground,
      'autoHideWhenPaused': autoHideWhenPaused,
      'followDynamicColor': followDynamicColor,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
    });
  }

  static Future<void> updateDesktopLyrics({
    required String text,
    required String title,
    required String artist,
    required bool playing,
  }) {
    return _nativeChannel.invokeMethod('updateDesktopLyrics', {
      'text': text,
      'title': title,
      'artist': artist,
      'playing': playing,
    });
  }

  static Future<Map<String, dynamic>> playerState() async {
    final state = await _nativeChannel.invokeMapMethod<String, dynamic>(
      'state',
    );
    return state ?? const <String, dynamic>{};
  }
}
