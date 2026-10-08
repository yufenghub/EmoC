import 'dart:async';
import 'dart:math';

import 'package:emoc/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const channel = MethodChannel('emoc/native');
final songs = List.generate(
  4,
  (index) => MirrorItem(
    domId: '$index',
    kind: 'local',
    title: 'Track $index',
    subtitle: 'Test',
    imageUrl: '',
    href: 'content://test/audio/$index',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('preferences cross the platform channel once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'themeMode': 'dark', 'crossfadeSeconds': '3', 'missing': null};
    });
    final values = await NativeBridge.getPreferences([
      'themeMode',
      'crossfadeSeconds',
      'missing',
    ]);
    expect(values['themeMode'], 'dark');
    expect(values['missing'], isNull);
    expect(calls.single.method, 'prefsGetMany');
  });

  test('missing preference plugin uses defaults', () async {
    expect(await NativeBridge.getPreferences(['themeMode']), isEmpty);
  });

  test('shuffle preview is stable and does not skip a song', () {
    final order = PlaybackOrderController(random: Random(14));
    var current = 0;
    for (var count = 0; count < 12; count++) {
      final preview = order.peekNextIndex(
        songs: songs,
        currentIndex: current,
        mode: 'shuffle',
      );
      expect(
        order.peekNextIndex(
          songs: songs,
          currentIndex: current,
          mode: 'shuffle',
        ),
        preview,
      );
      expect(
        order.nextIndex(songs: songs, currentIndex: current, mode: 'shuffle'),
        preview,
      );
      expect(preview, isNot(current));
      current = preview;
    }
  });

  test('repeat-one preview preserves the current song', () {
    final order = PlaybackOrderController();
    expect(order.peekNextIndex(songs: songs, currentIndex: 2, mode: 'one'), 2);
    expect(order.peekNextIndex(songs: songs, currentIndex: 3, mode: 'loop'), 0);
    expect(order.peekNextIndex(songs: [], currentIndex: 0, mode: 'loop'), -1);
  });

  test(
    'local playback preloads one next track and coalesces player polling',
    () async {
      final calls = <MethodCall>[];
      final pendingState = Completer<Map<String, dynamic>>();
      var holdState = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'state') {
          return holdState
              ? pendingState.future
              : {
                  'active': true,
                  'playing': true,
                  'songId': songs.first.id,
                  'durationMs': 120000,
                };
        }
        if (call.method == 'queueNextTrack') return true;
        return null;
      });
      final model = AppModel(history: ListeningHistory(write: (_, _) async {}));
      addTearDown(model.dispose);
      model.crossfadeSeconds = 3;
      await model.clickSong(songs.first, fromList: songs);
      await Future<void>.delayed(Duration.zero);
      final queued = calls
          .where((call) => call.method == 'queueNextTrack')
          .single;
      expect(queued.arguments['songId'], songs[1].id);
      expect(queued.arguments['crossfadeMs'], 3000);
      holdState = true;
      calls.clear();
      final first = model.refreshPlayerState();
      final second = model.refreshPlayerState();
      expect(identical(first, second), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((call) => call.method == 'state'), hasLength(1));
      pendingState.complete({
        'active': true,
        'playing': true,
        'songId': songs.first.id,
        'currentMs': 1234,
        'durationMs': 120000,
      });
      await Future.wait([first, second]);
      expect(model.player.currentMilliseconds, 1234);
    },
  );

  test('stale player reply cannot overwrite a new selection', () async {
    final pendingState = Completer<Map<String, dynamic>>();
    var holdState = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'state') {
        return holdState
            ? pendingState.future
            : {
                'active': true,
                'playing': true,
                'songId': songs.first.id,
                'durationMs': 120000,
              };
      }
      if (call.method == 'queueNextTrack') return true;
      return null;
    });
    final model = AppModel(history: ListeningHistory(write: (_, _) async {}));
    addTearDown(model.dispose);
    await model.clickSong(songs.first, fromList: songs);
    holdState = true;
    final refresh = model.refreshPlayerState();
    await Future<void>.delayed(Duration.zero);
    final selection = model.clickSong(songs[2], fromList: songs);
    await Future<void>.delayed(Duration.zero);
    pendingState.complete({
      'active': true,
      'playing': true,
      'songId': songs.first.id,
      'currentMs': 6000,
      'durationMs': 120000,
    });
    await refresh;
    await selection;
    expect(model.player.songId, songs[2].id);
    expect(model.player.currentMilliseconds, 0);
  });
}
