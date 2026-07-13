import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoc/main.dart';

void main() {
  testWidgets('renders the main shell before login probing', (tester) async {
    final model = AppModel()..showSongCovers = false;
    addTearDown(model.dispose);

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();

    expect(find.text('首页'), findsWidgets);
    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('每日歌曲推荐'), findsOneWidget);
  });

  test('app theme state ignores unrelated model notifications', () {
    final model = AppModel();
    final themeState = AppThemeState(model);
    addTearDown(themeState.dispose);
    addTearDown(model.dispose);
    var notifications = 0;
    themeState.addListener(() => notifications++);

    model.noticeMessage = 'unrelated';
    model.notifyListeners();
    expect(notifications, 0);

    model.themeSeedColor = const Color(0xFF985F3E);
    model.notifyListeners();
    expect(notifications, 1);

    model.notifyListeners();
    expect(notifications, 1);
  });

  test('player progress is clamped and formatted', () {
    const snapshot = PlayerSnapshot(
      visible: true,
      songId: '1',
      title: 'Song',
      artist: 'Artist',
      source: 'Album',
      coverUrl: '',
      playing: true,
      currentSeconds: 200,
      durationSeconds: 100,
      currentMilliseconds: 200000,
      durationMilliseconds: 100000,
      volume: 0.7,
      mode: 'loop',
    );

    expect(snapshot.progress, 1);
    expect(snapshot.progressText, '3:20 / 1:40');
  });

  test('playback order handles repeat-one and a complete shuffle cycle', () {
    final songs = List<MirrorItem>.generate(
      5,
      (index) => MirrorItem(
        domId: 'song_$index',
        kind: 'song',
        title: 'Song $index',
        subtitle: 'Artist',
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=$index',
      ),
    );
    final order = PlaybackOrderController(random: Random(7));

    expect(
      order.nextIndex(
        songs: songs,
        currentIndex: 2,
        mode: 'one',
        naturalEnd: true,
      ),
      2,
    );
    expect(order.nextIndex(songs: songs, currentIndex: 2, mode: 'one'), 3);

    var current = 0;
    final visited = <int>{current};
    for (var step = 0; step < songs.length - 1; step++) {
      current = order.nextIndex(
        songs: songs,
        currentIndex: current,
        mode: 'shuffle',
      );
      visited.add(current);
    }
    expect(visited, hasLength(songs.length));
  });

  testWidgets('cover-disabled artwork uses the local icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SongArtwork(url: '', showCover: false)),
      ),
    );

    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byType(CoverImage), findsNothing);
  });

  testWidgets('player queue only displays the song list', (tester) async {
    final model = AppModel()
      ..showSongCovers = false
      ..playerQueue = const [
        MirrorItem(
          domId: 'song_1',
          kind: 'song',
          title: 'Song',
          subtitle: 'Artist',
          imageUrl: '',
          href: 'https://music.163.com/#/song?id=1',
        ),
      ]
      ..queueLyricLines = const ['第一句歌词', '第二句歌词'];
    addTearDown(model.dispose);

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: Scaffold(body: PlayerQueueSheet(model: model)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('Song'), findsOneWidget);
    expect(find.text('第一句歌词'), findsNothing);
    expect(find.text('第二句歌词'), findsNothing);
  });

  testWidgets('slow artwork cannot block playlist rows indefinitely', (
    tester,
  ) async {
    final model = _SlowArtworkModel()..showSongCovers = true;
    final viewport = SongViewportController(batchSize: 6, eager: false);
    addTearDown(model.dispose);
    addTearDown(viewport.dispose);
    final songs = List<MirrorItem>.generate(
      6,
      (index) => MirrorItem(
        domId: 'slow_$index',
        kind: 'song',
        title: 'Slow $index',
        subtitle: 'Artist',
        imageUrl: 'https://invalid.example/$index.jpg',
        href: 'https://music.163.com/#/song?id=${index + 10}',
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    viewport.synchronize(model, songs);
    await tester.pump();
    expect(viewport.readyCount, 0);

    await tester.pump(const Duration(milliseconds: 950));
    expect(viewport.readyCount, songs.length);
  });

  testWidgets('playlist viewport restores its revealed high-water mark', (
    tester,
  ) async {
    final model = _SlowArtworkModel()..showSongCovers = true;
    final viewport = SongViewportController(
      batchSize: 36,
      eager: true,
      automaticBatchCount: 2,
    );
    addTearDown(model.dispose);
    addTearDown(viewport.dispose);
    final songs = List<MirrorItem>.generate(
      120,
      (index) => MirrorItem(
        domId: 'restored_$index',
        kind: 'song',
        title: 'Restored $index',
        subtitle: 'Artist',
        imageUrl: 'https://invalid.example/restored_$index.jpg',
        href: 'https://music.163.com/#/song?id=${index + 1000}',
      ),
    );
    model.rememberPlaylistRevealCount('restored_playlist', 108);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    viewport.synchronize(
      model,
      songs,
      initialReadyCount: model.playlistRevealCount('restored_playlist'),
    );
    await tester.pump();
    expect(viewport.readyCount, 108);

    model.showSongCovers = false;
    viewport.synchronize(
      model,
      songs,
      initialReadyCount: model.playlistRevealCount('restored_playlist'),
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(viewport.readyCount, songs.length);

    model.showSongCovers = true;
    viewport.synchronize(
      model,
      songs,
      initialReadyCount: model.playlistRevealCount('restored_playlist'),
    );
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(viewport.readyCount, 108);
    await tester.pump(const Duration(milliseconds: 400));
  });

  test('forced playlist colour refresh reuses the in-flight request', () {
    final model = _SlowPlaylistColorModel()..dynamicColorEnabled = true;
    final module = PlaylistModule(model);
    addTearDown(model.dispose);
    const song = MirrorItem(
      domId: 'playlist_colour',
      kind: 'song',
      title: 'Playlist colour',
      subtitle: 'Artist',
      imageUrl: '',
      href: 'https://music.163.com/#/song?id=88',
    );

    final first = module.refreshPlaybackColor(
      requestId: 0,
      song: song,
      songId: song.id,
    );
    final forced = module.refreshPlaybackColor(
      requestId: 0,
      song: song,
      songId: song.id,
      force: true,
    );

    expect(identical(first, forced), isTrue);
  });

  testWidgets('a stalled cover still reveals the playable song row', (
    tester,
  ) async {
    final model = _StalledSongArtworkModel()..showSongCovers = true;
    addTearDown(model.dispose);
    const song = MirrorItem(
      domId: 'stalled_song',
      kind: 'song',
      title: 'Playable while cover retries',
      subtitle: 'Artist',
      imageUrl: '',
      href: 'https://music.163.com/#/song?id=99',
    );

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: const MaterialApp(
          home: Scaffold(
            body: PreparedSongTile(
              song: song,
              sourceList: [song],
              sourceIndex: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(song.title), findsNothing);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump();
    expect(find.text(song.title), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final size in const [Size(320, 720), Size(800, 1200)]) {
    testWidgets('main shell has no layout overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final model = AppModel()
        ..showSongCovers = false
        ..playerBarVisible = true
        ..player = const PlayerSnapshot(
          visible: true,
          songId: '1',
          title: 'A deliberately long song title for layout verification',
          artist: 'Artist with a long display name',
          source: 'Album',
          coverUrl: '',
          playing: false,
          currentSeconds: 12,
          durationSeconds: 180,
          currentMilliseconds: 12000,
          durationMilliseconds: 180000,
          volume: 0.7,
          mode: 'loop',
        );
      addTearDown(model.dispose);

      await tester.pumpWidget(
        AppScope(
          model: model,
          child: const MaterialApp(home: MainShell()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(PlayerBar), findsOneWidget);
    });
  }
}

class _SlowArtworkModel extends AppModel {
  final Completer<bool> _neverCompletes = Completer<bool>();

  @override
  Future<bool> prepareSongArtworkBatch(
    List<MirrorItem> songs, {
    bool forceMissingMetadata = false,
  }) {
    return _neverCompletes.future;
  }
}

class _StalledSongArtworkModel extends AppModel {
  final Completer<bool> _neverCompletes = Completer<bool>();

  @override
  bool isSongArtworkReady(MirrorItem song) => false;

  @override
  Future<bool> prepareSongArtwork(
    MirrorItem song, {
    bool forceMetadata = false,
  }) {
    return _neverCompletes.future;
  }

  @override
  Future<String> ensureSongCover(MirrorItem song, {bool force = false}) {
    return Future<String>.value('');
  }
}

class _SlowPlaylistColorModel extends AppModel {
  final Completer<String> _neverCompletes = Completer<String>();

  @override
  Future<String> ensureSongCover(MirrorItem song, {bool force = false}) {
    return _neverCompletes.future;
  }
}
