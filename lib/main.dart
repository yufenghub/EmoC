import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

part 'src/native_bridge.dart';
part 'src/models.dart';
part 'src/login_api.dart';
part 'src/music_api.dart';
part 'src/theme_config.dart';
part 'src/cover_cache.dart';
part 'src/song_artwork_pipeline.dart';
part 'src/playback_order.dart';
part 'src/playlist_module.dart';
part 'src/app_model.dart';
part 'src/web_scripts.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 800;
  imageCache.maximumSizeBytes = 64 << 20;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const EmoCApp());
}

const _nativeChannel = MethodChannel('emoc/native');
