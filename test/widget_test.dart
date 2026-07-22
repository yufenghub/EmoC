import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emoc/main.dart';

void main() {
  test('playlist mutations use the current official API contracts', () async {
    final requests =
        <({String path, Map<String, dynamic> data, bool useGet})>[];
    final client = MusicMutationApiClient(
      plainRequestOverride: (path, data, {required useGet}) async {
        requests.add((path: path, data: data, useGet: useGet));
        if (path == '/api/playlist/create') {
          return {
            'code': 200,
            'playlist': {'id': 987654321, 'name': '测试歌单'},
          };
        }
        return {'code': 200};
      },
    );

    final created = await client.createPlaylist('测试歌单');
    await client.deletePlaylist('987654321');

    expect(created.id, '987654321');
    expect(created.name, '测试歌单');
    expect(requests, hasLength(2));
    expect(requests.first.path, '/api/playlist/create');
    expect(requests.first.useGet, isFalse);
    expect(requests.first.data['name'], '测试歌单');
    expect(requests.first.data['privacy'], '0');
    expect(requests.first.data['type'], 'NORMAL');
    expect(requests.last.path, '/api/playlist/delete');
    expect(requests.last.useGet, isTrue);
    expect(requests.last.data['pid'], 987654321);
  });

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

  for (final layout in const [
    (
      size: Size(390, 844),
      label: 'phone portrait',
      widgetKey: 'portrait-player',
      portrait: true,
    ),
    (
      size: Size(844, 390),
      label: 'phone landscape',
      widgetKey: 'landscape-player',
      portrait: false,
    ),
    (
      size: Size(800, 1200),
      label: 'tablet portrait',
      widgetKey: 'portrait-player',
      portrait: true,
    ),
    (
      size: Size(1280, 800),
      label: 'tablet landscape',
      widgetKey: 'landscape-player',
      portrait: false,
    ),
  ]) {
    testWidgets('expanded lyrics player adapts to ${layout.label}', (
      tester,
    ) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final model = AppModel()..showSongCovers = false;
      addTearDown(model.dispose);
      const song = MirrorItem(
        domId: 'song_1',
        kind: 'song',
        title: '布局测试歌曲',
        subtitle: '测试歌手 · 测试专辑',
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=1',
      );
      const player = PlayerSnapshot(
        visible: true,
        songId: '1',
        title: '布局测试歌曲',
        artist: '测试歌手',
        source: '测试专辑',
        coverUrl: '',
        playing: false,
        currentSeconds: 12,
        durationSeconds: 180,
        currentMilliseconds: 12000,
        durationMilliseconds: 180000,
        volume: 0.7,
        mode: 'loop',
      );
      const lyrics = [
        LyricLine(time: 0, text: '第一句歌词'),
        LyricLine(
          time: 10,
          text:
              '当前播放歌词很长也应该保持完整布局\nThe active translated lyric remains readable',
        ),
        LyricLine(
          time: 20,
          text: '下一句歌词同样可能很长\nThe next translated line can also wrap',
        ),
      ];

      await tester.pumpWidget(
        AppScope(
          model: model,
          child: MaterialApp(
            home: Scaffold(
              body: LyricsPlayerView(
                model: model,
                player: player,
                song: song,
                lyrics: lyrics,
                lyricsLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(ValueKey(layout.widgetKey)), findsOneWidget);
      expect(find.text('布局测试歌曲'), findsOneWidget);
      expect(
        find.text(
          '当前播放歌词很长也应该保持完整布局\nThe active translated lyric remains readable',
        ),
        findsOneWidget,
      );
      if (layout.portrait) {
        final recordCenter = tester.getCenter(
          find.byKey(const ValueKey('vinyl-record-1')),
        );
        expect(recordCenter.dx, closeTo(layout.size.width / 2, 1.5));
        final controlsBottom = tester.getBottomRight(
          find.byKey(const ValueKey('vinyl-player-controls')),
        );
        expect(controlsBottom.dy, greaterThan(layout.size.height * 0.78));
      } else {
        final recordCenter = tester.getCenter(
          find.byKey(const ValueKey('vinyl-record-1')),
        );
        expect(recordCenter.dy, closeTo(layout.size.height / 2, 2));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final layout in const [
    (
      size: Size(390, 844),
      label: 'phone portrait',
      widgetKey: 'apple-portrait-player',
      landscape: false,
    ),
    (
      size: Size(844, 390),
      label: 'phone landscape',
      widgetKey: 'apple-landscape-player',
      landscape: true,
    ),
    (
      size: Size(800, 1200),
      label: 'tablet portrait',
      widgetKey: 'apple-portrait-player',
      landscape: false,
    ),
    (
      size: Size(1280, 800),
      label: 'tablet landscape',
      widgetKey: 'apple-landscape-player',
      landscape: true,
    ),
  ]) {
    testWidgets('cover player adapts to ${layout.label}', (tester) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final model = AppModel()..showSongCovers = false;
      addTearDown(model.dispose);
      const song = MirrorItem(
        domId: 'song_2',
        kind: 'song',
        title: '封面播放器布局测试歌曲',
        subtitle: '测试歌手 · 测试专辑',
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=2',
      );
      const player = PlayerSnapshot(
        visible: true,
        songId: '2',
        title: '封面播放器布局测试歌曲',
        artist: '测试歌手',
        source: '测试专辑',
        coverUrl: '',
        playing: false,
        currentSeconds: 48,
        durationSeconds: 240,
        currentMilliseconds: 48000,
        durationMilliseconds: 240000,
        volume: 0.65,
        mode: 'loop',
      );

      await tester.pumpWidget(
        AppScope(
          model: model,
          child: MaterialApp(
            home: Scaffold(
              body: AppleMusicPlayerView(
                model: model,
                player: player,
                song: song,
                lyrics: const [
                  LyricLine(time: 0, text: '第一句'),
                  LyricLine(time: 40, text: '正在播放的歌词'),
                  LyricLine(time: 80, text: '接下来播放的歌词'),
                ],
                lyricsLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(ValueKey(layout.widgetKey)), findsOneWidget);
      expect(find.text('封面播放器布局测试歌曲'), findsOneWidget);
      expect(find.text('正在播放的歌词'), findsOneWidget);
      expect(find.text('接下来播放的歌词'), findsOneWidget);
      if (layout.landscape) {
        final artworkBottom = tester
            .getBottomRight(find.byKey(const ValueKey('apple-artwork-2')))
            .dy;
        final controlsBottom = tester
            .getBottomRight(
              find.byKey(const ValueKey('apple-playback-panel-compact')),
            )
            .dy;
        expect(controlsBottom, lessThanOrEqualTo(artworkBottom + 2));
        expect(controlsBottom, greaterThan(artworkBottom - 24));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lyrics page owns the player bar and hides it with chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = _SongDetailLayoutModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SongDetailPage(model: model, song: model.testSong),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('integrated-lyrics-player-bar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chrome-visible')), findsOneWidget);
    final activeLyricBeforeFullscreen = tester.getCenter(find.text('当前歌词')).dy;
    final headerFinder = find.byKey(
      const ValueKey('lyrics-content-header-9001|详情页布局歌曲'),
    );
    final headerBeforeFullscreen = tester.getCenter(headerFinder).dy;
    final lyricViewportBeforeFullscreen = tester.getSize(
      find.byType(ScrollingLyrics),
    );

    await tester.tapAt(const Offset(195, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('integrated-lyrics-player-bar')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('chrome-hidden')), findsOneWidget);
    final activeLyricAfterFullscreen = tester.getCenter(find.text('当前歌词')).dy;
    final headerAfterFullscreen = tester.getCenter(headerFinder).dy;
    final headerTopAfterFullscreen = tester.getTopLeft(headerFinder).dy;
    final lyricViewportAfterFullscreen = tester.getSize(
      find.byType(ScrollingLyrics),
    );
    expect(
      (activeLyricAfterFullscreen - activeLyricBeforeFullscreen).abs(),
      lessThan(1),
    );
    expect(headerAfterFullscreen, lessThan(headerBeforeFullscreen - 20));
    expect(headerTopAfterFullscreen, closeTo(0, 1));
    expect(
      lyricViewportAfterFullscreen.height,
      greaterThan(lyricViewportBeforeFullscreen.height + 100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape song detail hides page titles across player styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = _SongDetailLayoutModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SongDetailPage(model: model, song: model.testSong),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('歌词'), findsNothing);
    expect(find.byKey(const ValueKey('chrome-visible')), findsOneWidget);
    final initialBackCenter = tester.getCenter(find.byTooltip('返回'));
    final initialIndicatorCenter = tester.getCenter(
      find.bySemanticsLabel('歌词页，第 1 页，共 3 页'),
    );
    expect(initialIndicatorCenter.dy, closeTo(initialBackCenter.dy, 1));
    final headerRect = tester.getRect(
      find.byKey(const ValueKey('lyrics-content-header-9001|详情页布局歌曲')),
    );
    final lyricsRect = tester.getRect(find.byType(ScrollingLyrics));
    expect(lyricsRect.top - headerRect.bottom, lessThan(10));

    await tester.fling(find.byType(PageView), const Offset(-700, 0), 1200);
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('正在播放'), findsNothing);
    expect(find.byKey(const ValueKey('landscape-player')), findsOneWidget);
    final chromeBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('chrome-visible')),
    );
    final backRect = tester.getRect(find.byTooltip('返回'));
    final recordRect = tester.getRect(
      find.byKey(const ValueKey('vinyl-record-9001')),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('landscape-player'))).dy,
      lessThan(chromeBottom.dy),
    );
    expect(recordRect.overlaps(backRect), isFalse);

    await tester.fling(find.byType(PageView), const Offset(-700, 0), 1200);
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('正在播放'), findsNothing);
    expect(
      find.byKey(const ValueKey('apple-landscape-player')),
      findsOneWidget,
    );
    final artworkRect = tester.getRect(
      find.byKey(const ValueKey('apple-artwork-9001')),
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('apple-landscape-player')))
          .dy,
      lessThan(chromeBottom.dy),
    );
    expect(artworkRect.overlaps(backRect), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player styles wrap from lyrics directly to apple', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = _SongDetailLayoutModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SongDetailPage(model: model, song: model.testSong),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(const ValueKey('lyrics-page')), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(700, 0), 1200);
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('apple-portrait-player')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet immersive lyrics use the chrome-adjacent top space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = _SongDetailLayoutModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SongDetailPage(model: model, song: model.testSong),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    final backCenter = tester.getCenter(find.byTooltip('返回'));
    final indicatorCenter = tester.getCenter(
      find.bySemanticsLabel('歌词页，第 1 页，共 3 页'),
    );
    expect((backCenter.dy - indicatorCenter.dy).abs(), lessThanOrEqualTo(1));

    await tester.tapAt(const Offset(640, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final headerTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('lyrics-content-header-9001|详情页布局歌曲')),
        )
        .dy;
    expect(headerTop, greaterThanOrEqualTo(-8));
    expect(headerTop, lessThanOrEqualTo(8));
    expect(find.byKey(const ValueKey('chrome-hidden')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SongDetailLayoutModel extends AppModel {
  _SongDetailLayoutModel() {
    player = const PlayerSnapshot(
      visible: true,
      songId: '9001',
      title: '详情页布局歌曲',
      artist: '测试歌手',
      source: '测试专辑',
      coverUrl: '',
      playing: true,
      currentSeconds: 18,
      durationSeconds: 180,
      currentMilliseconds: 18000,
      durationMilliseconds: 180000,
      volume: 0.6,
      mode: 'loop',
    );
    playerBarVisible = true;
    showSongCovers = false;
    songDetail = SongDetail(
      song: testSong,
      coverUrl: '',
      lyricLines: const ['第一句歌词', '当前歌词'],
      lyrics: const [
        LyricLine(time: 0, text: '第一句歌词'),
        LyricLine(time: 10, text: '当前歌词'),
      ],
      loading: false,
    );
  }

  final MirrorItem testSong = const MirrorItem(
    domId: 'song_detail_1',
    kind: 'song',
    title: '详情页布局歌曲',
    subtitle: '测试歌手 · 测试专辑',
    imageUrl: '',
    href: 'https://music.163.com/#/song?id=9001',
  );

  @override
  Future<void> openSongDetail(MirrorItem song) async {}
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
