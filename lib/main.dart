import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

part 'src/native_bridge.dart';
part 'src/models.dart';
part 'src/login_api.dart';
part 'src/theme_config.dart';
part 'src/app_model.dart';
part 'src/web_scripts.dart';
part 'src/app_shell.dart';
part 'src/player_bar.dart';
part 'src/home_page.dart';
part 'src/library_page.dart';
part 'src/mine_page.dart';
part 'src/song_detail_page.dart';
part 'src/playlist_detail_page.dart';
part 'src/common_widgets.dart';
part 'src/utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const EmoCApp());
}

const _nativeChannel = MethodChannel('emoc/native');
