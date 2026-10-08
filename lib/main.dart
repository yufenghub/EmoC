import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:pointycastle/export.dart' as pc;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

part 'src/native_bridge.dart';
part 'src/models.dart';
part 'src/login_api.dart';
part 'src/music_api.dart';
part 'src/theme_config.dart';
part 'src/liquid_theme.dart';
part 'src/interface_preferences.dart';
part 'src/card_style_page.dart';
part 'src/cover_cache.dart';
part 'src/network_utils.dart';
part 'src/network_policy.dart';
part 'src/song_artwork_pipeline.dart';
part 'src/playback_order.dart';
part 'src/playback_transitions.dart';
part 'src/listening_history.dart';
part 'src/local_music.dart';
part 'src/history_page.dart';
part 'src/lyrics_cache.dart';
part 'src/cache_management_page.dart';
part 'src/playlist_module.dart';
part 'src/playlist_batch.dart';
part 'src/app_update.dart';
part 'src/app_model.dart';
part 'src/app_preferences.dart';
part 'src/equalizer_page.dart';
part 'src/web_scripts.dart';
part 'src/app_update_ui.dart';
part 'src/app_shell.dart';
part 'src/player_bar.dart';
part 'src/home_page.dart';
part 'src/library_page.dart';
part 'src/mine_page.dart';
part 'src/song_detail_page.dart';
part 'src/lyrics_player_view.dart';
part 'src/apple_music_player_view.dart';
part 'src/playlist_detail_page.dart';
part 'src/common_widgets.dart';
part 'src/utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['liquid_glass_widgets - vendored components'],
      await rootBundle.loadString(
        'third_party/liquid-glass-widgets/THIRD_PARTY_NOTICES.txt',
      ),
    );
    final license = await rootBundle.loadString(
      'third_party/lyricify-backgrounds/LICENSE.txt',
    );
    final notice = await rootBundle.loadString(
      'third_party/lyricify-backgrounds/NOTICE.txt',
    );
    yield LicenseEntryWithLineBreaks([
      'Lyricify-Backgrounds',
    ], '$notice\n\n$license');
  });
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 800;
  imageCache.maximumSizeBytes = 64 << 20;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final model = AppModel();
  var preferencesRestored = false;
  try {
    await model._restorePreferences();
    preferencesRestored = true;
    if (model.visualStyle == 'liquid') await _initializeGlass();
  } catch (error) {
    debugPrint('Startup appearance: $error');
  }
  runApp(
    glass.LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: EmoCApp(model: model, preferencesRestored: preferencesRestored),
    ),
  );
}

const _nativeChannel = MethodChannel('emoc/native');
