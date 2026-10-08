import 'package:emoc/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('emoc/native');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => messenger.setMockMethodCallHandler(channel, (_) async => null));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('unresponsive web lyrics fallback stops loading', (tester) async {
    final model = AppModel();
    const song = MirrorItem(
      domId: '',
      kind: 'song',
      title: 'Unknown',
      subtitle: '',
      imageUrl: '',
      href: '',
    );
    await model.openSongDetail(song);
    expect(model.songDetailLoading, isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(model.songDetailLoading, isFalse);
    expect(model.songDetail!.loading, isFalse);
    expect(model.status, contains('超时'));
    model.dispose();
  });

  test('local lyrics preserve the content URI and song identity', () {
    const song = MirrorItem(
      domId: '',
      kind: 'local',
      title: 'Local',
      subtitle: '',
      imageUrl: '',
      href: 'content://test/audio/1',
    );
    final detail = SongDetail.fromJson({'songId': song.id}, song);
    expect(detail.song.href, song.href);
    expect(detail.song.id, song.id);
    expect(detail.song.isLocal, isTrue);
  });

  testWidgets('mini player exposes compact transport and top progress', (
    tester,
  ) async {
    final model = AppModel()
      ..showSongCovers = false
      ..iconOnlyNavigation = false;
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerBar(model: model)),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('compact-player-bar'))).height,
      56,
    );
    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byKey(const ValueKey('mini-progress-glow')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('mini-progress-glow'))),
      tester.getTopLeft(find.byKey(const ValueKey('compact-player-bar'))),
    );
    expect(find.byType(PlayerSeekBar), findsNothing);
    expect(find.byTooltip('播放列表'), findsNothing);
    expect(find.byType(CoverImage), findsOneWidget);
  });

  testWidgets('history appears only while search is focused', (tester) async {
    final model = AppModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SearchPanel(model: model)),
      ),
    );
    expect(find.text('搜索历史'), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pump();
    expect(find.text('搜索历史'), findsNothing);
  });

  testWidgets('home and playlist search share the same field surface', (
    tester,
  ) async {
    final model = AppModel()..visualStyle = 'liquid';
    final controller = TextEditingController();
    addTearDown(model.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SearchPanel(model: model),
                PlaylistSearchField(controller: controller, enabled: true),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SearchFieldSurface), findsNWidgets(2));
    final surfaces = tester.widgetList<LiquidSurface>(
      find.byType(LiquidSurface),
    );
    expect(surfaces, hasLength(2));
    expect(surfaces.every((surface) => !surface.useOwnLayer), isTrue);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.border, InputBorder.none);
    }
    expect(find.byIcon(Icons.search), findsNWidgets(2));
    expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2));
  });

  testWidgets('in-app login has an opaque themed background', (tester) async {
    final model = AppModel()..visualStyle = 'liquid';
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(home: OfficialLoginGate(model: model)),
      ),
    );
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor,
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.surface,
    );
    expect(scaffold.backgroundColor?.a, 1);
  });

  testWidgets('account avatar always has a slot and VIP is conditional', (
    tester,
  ) async {
    final model = AppModel()..loggedIn = true;
    addTearDown(model.dispose);
    Widget build() => MaterialApp(
      home: Scaffold(body: AccountCard(model: model)),
    );
    await tester.pumpWidget(build());
    expect(find.byType(CoverImage), findsOneWidget);
    expect(find.text('VIP'), findsNothing);
    model.accountVip = true;
    await tester.pumpWidget(build());
    expect(find.text('VIP'), findsOneWidget);
    model.loggedIn = false;
    await tester.pumpWidget(build());
    expect(find.text('VIP'), findsNothing);
  });

  test('appearance changes notify theme state and persist', () async {
    final saved = <String, String>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'prefsSet') {
        final args = call.arguments as Map;
        saved[args['key'] as String] = args['value'] as String;
      }
      return null;
    });
    final model = AppModel()..visualStyle = 'simple';
    final theme = AppThemeState(model);
    var revisions = 0;
    theme.addListener(() => revisions++);
    await model.setAppearance(style: 'liquid', motion: 0);
    expect(revisions, 1);
    expect(saved['visualStyle'], 'liquid');
    expect(saved['motionLevel'], '2');
    theme.dispose();
    model.dispose();
  });

  test(
    'interface preferences preserve hidden buttons and effect values',
    () async {
      String? saved;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'prefsSet' &&
            call.arguments['key'] == 'interfacePreferences') {
          saved = call.arguments['value'] as String;
        }
        return null;
      });
      final model = AppModel();
      final restored = AppModel();
      addTearDown(model.dispose);
      addTearDown(restored.dispose);
      await model.setIconOnlyNavigation(true);
      await model.setCardFrameEnabled(false);
      await model.setControlVisible('mini.next', false);
      await model.setControlVisible('player.favorite', false);
      model.updateEffect('coverBlur', 64);
      model.updateEffect('glassDepth', 38);
      await model.saveInterfacePreferences();
      restored.restoreInterfacePreferences(saved);
      expect(restored.iconOnlyNavigation, isTrue);
      expect(restored.cardFrameEnabled, isFalse);
      expect(restored.controlVisible('mini.next'), isFalse);
      expect(restored.controlVisible('player.favorite'), isFalse);
      expect(restored.coverBlur, 64);
      expect(restored.glassDepth, 38);
    },
  );

  test('region text and role colors persist independently', () async {
    String? saved;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'prefsSet' &&
          call.arguments['key'] == 'interfacePreferences') {
        saved = call.arguments['value'] as String;
      }
      return null;
    });
    final model = AppModel();
    final restored = AppModel();
    addTearDown(model.dispose);
    addTearDown(restored.dispose);
    await model.setRegionTextVisible('home.title', false);
    await model.setUiRoleColor(
      'progress',
      followDynamic: false,
      fixedColor: const Color(0xFFEF4444),
    );
    restored.restoreInterfacePreferences(saved);
    expect(restored.regionTextVisible('home.title'), isFalse);
    expect(restored.regionTextVisible('library.title'), isTrue);
    expect(restored.uiProgressFollowsDynamic, isFalse);
    expect(restored.uiFixedProgressColor, const Color(0xFFEF4444));
  });

  test('fresh install defaults match the illustrated settings', () {
    final model = AppModel();
    addTearDown(model.dispose);
    expect(model.themeMode, 'system');
    expect(model.visualStyle, 'liquid');
    expect(model.cardStyle, 'outline');
    expect(model.cardFrameEnabled, isTrue);
    expect(model.iconOnlyNavigation, isTrue);
    expect(model.coverFirstBackground, isTrue);
    expect(model.dynamicColorEnabled, isTrue);
    expect(model.showSongCovers, isTrue);
    expect(model.continuousPlayback, isTrue);
    expect(model.crossfadeSeconds, 3);
    expect(model.volumeNormalizationEnabled, isTrue);
    expect(model.allowMixedAudio, isTrue);
    expect(model.desktopLyricsEnabled, isFalse);
    model.restoreInterfacePreferences('{"cardStyle":"solid"}');
    expect(model.cardStyle, 'solid');
    expect(model.iconOnlyNavigation, isTrue);
    expect(model.coverFirstBackground, isTrue);
  });

  testWidgets('loading cards use the shared card surface', (tester) async {
    final model = AppModel()..cardStyle = 'outline';
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [SongPlaceholderTile(), PlaylistPlaceholderCard()],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppCardSurface), findsNWidgets(2));
    expect(find.byType(SongPlaceholderTile), findsOneWidget);
    expect(find.byType(PlaylistPlaceholderCard), findsOneWidget);
  });

  testWidgets('search view keeps recommendations out of the result list', (
    tester,
  ) async {
    final model = AppModel()
      ..dailySongs = const [
        MirrorItem(
          domId: 'daily',
          kind: 'song',
          title: 'Daily song',
          subtitle: 'Artist',
          imageUrl: '',
          href: '',
        ),
      ];
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: AnimatedBuilder(
            animation: model,
            builder: (context, _) => Scaffold(body: HomePage(model: model)),
          ),
        ),
      ),
    );
    expect(find.text('每日歌曲推荐'), findsOneWidget);
    model.searchQuery = 'query';
    model.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('每日歌曲推荐'), findsNothing);
  });

  testWidgets('home song list only mounts rows near the viewport', (
    tester,
  ) async {
    final model = AppModel()
      ..showSongCovers = false
      ..dailySongs = List.generate(
        30,
        (index) => MirrorItem(
          domId: '$index',
          kind: 'song',
          title: 'Song $index',
          subtitle: 'Artist',
          imageUrl: '',
          href: '',
        ),
      );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(home: Scaffold(body: HomePage(model: model))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PreparedSongTile).evaluate().length, lessThan(30));
    expect(find.text('Song 29'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Song 29'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Song 29'), findsOneWidget);
    expect(find.byType(PreparedSongTile).evaluate().length, lessThan(30));
  });

  testWidgets('lyrics controls use two rows', (tester) async {
    final model = AppModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PlayerToolRow(
              model: model,
              player: model.player,
              twoRows: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('two-row-player-tools')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('player-control-queue'))).dy,
      greaterThan(
        tester
            .getCenter(find.byKey(const ValueKey('player-control-previous')))
            .dy,
      ),
    );
  });

  testWidgets('lyrics controls stay on two rows and hide independently', (
    tester,
  ) async {
    final model = AppModel()..showSongCovers = false;
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: PlayerBar(model: model, canOpenSongDetail: false),
          ),
        ),
      ),
    );
    final previous = tester.getCenter(
      find.byKey(const ValueKey('player-control-previous')),
    );
    final next = tester.getCenter(
      find.byKey(const ValueKey('player-control-next')),
    );
    final queue = tester.getCenter(
      find.byKey(const ValueKey('player-control-queue')),
    );
    expect(previous.dy, next.dy);
    expect(queue.dy, greaterThan(next.dy));
    await model.setControlVisible('player.next', false);
    await tester.pump();
    expect(find.byKey(const ValueKey('player-control-next')), findsNothing);
    expect(
      find.byKey(const ValueKey('player-control-previous')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('player controls center play and reorder by long drag', (
    tester,
  ) async {
    final model = AppModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PlayerToolRow(
              model: model,
              player: model.player,
              twoRows: true,
            ),
          ),
        ),
      ),
    );
    final play = tester.getCenter(
      find.byKey(const ValueKey('player-control-play')),
    );
    expect(play.dx, closeTo(160, 12));
    final from = tester.getCenter(
      find.byKey(const ValueKey('player-control-favorite')),
    );
    final to = tester.getCenter(
      find.byKey(const ValueKey('player-control-previous')),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(model.playerControlOrder.take(5), [
      'mode',
      'favorite',
      'play',
      'next',
      'previous',
    ]);
  });

  testWidgets(
    'Apple Music transport stays centered with optional tools hidden',
    (tester) async {
      final model = AppModel();
      addTearDown(model.dispose);
      model.hiddenControls.addAll({'player.favorite', 'player.queue'});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PlayerToolRow(
                model: model,
                player: model.player,
                centerTransport: true,
              ),
            ),
          ),
        ),
      );
      final previous = tester.getCenter(
        find.byKey(const ValueKey('player-control-previous')),
      );
      final play = tester.getCenter(
        find.byKey(const ValueKey('player-control-play')),
      );
      final next = tester.getCenter(
        find.byKey(const ValueKey('player-control-next')),
      );
      expect(play.dx, closeTo(160, 1));
      expect(play.dx - previous.dx, closeTo(next.dx - play.dx, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('batch playlist offers a working title sort', (tester) async {
    final model = AppModel();
    addTearDown(model.dispose);
    const songs = [
      MirrorItem(
        domId: 'z',
        kind: 'song',
        title: 'Zulu',
        subtitle: 'B',
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=11',
      ),
      MirrorItem(
        domId: 'a',
        kind: 'song',
        title: 'Alpha',
        subtitle: 'A',
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=12',
      ),
    ];
    const playlist = MirrorItem(
      domId: 'p',
      kind: 'playlist',
      title: 'Test',
      subtitle: '',
      imageUrl: '',
      href: 'https://music.163.com/#/playlist?id=99',
    );
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: PlaylistBatchPage(
            model: model,
            playlist: playlist,
            songs: songs,
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Zulu')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha')).dy),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按歌名').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Zulu')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search surface follows the shared outline card style', (
    tester,
  ) async {
    final model = AppModel()..cardStyle = 'outline';
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: const MaterialApp(
          home: Scaffold(body: SearchFieldSurface(child: Text('搜索音乐'))),
        ),
      ),
    );
    final card = find
        .descendant(
          of: find.byType(AppCardSurface),
          matching: find.byType(Material),
        )
        .first;
    expect(tester.widget<Material>(card).color, Colors.transparent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('liquid refresh hint clears after completion', (tester) async {
    final model = AppModel()..visualStyle = 'liquid';
    var refreshed = false;
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: Scaffold(
            body: PageFrame(
              title: '首页',
              onRefresh: () async {
                refreshed = true;
              },
              children: const [SizedBox(height: 1200)],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(refreshed, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('liquid refresh does not activate on upward scroll', (
    tester,
  ) async {
    final model = AppModel()..visualStyle = 'liquid';
    var refreshCount = 0;
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: Scaffold(
            body: PageFrame(
              title: '首页',
              onRefresh: () async => refreshCount++,
              children: const [SizedBox(height: 1200)],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(refreshCount, 0);
    final opacity = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(AnimatedOpacity),
    );
    if (opacity.evaluate().isNotEmpty) {
      expect(tester.widget<AnimatedOpacity>(opacity.first).opacity, 0);
    }
  });

  testWidgets('liquid player controls can be dragged to reorder', (
    tester,
  ) async {
    final model = AppModel()..visualStyle = 'liquid';
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: model,
            builder: (context, _) => SizedBox(
              width: 320,
              child: PlayerToolRow(
                model: model,
                player: model.player,
                twoRows: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final from = tester.getCenter(
      find.byKey(const ValueKey('player-control-favorite')),
    );
    final to = tester.getCenter(
      find.byKey(const ValueKey('player-control-previous')),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(model.playerControlOrder.take(5), [
      'mode',
      'favorite',
      'play',
      'next',
      'previous',
    ]);
    final secondFrom = tester.getCenter(
      find.byKey(const ValueKey('player-control-favorite')),
    );
    final secondTo = tester.getCenter(
      find.byKey(const ValueKey('player-control-mode')),
    );
    final secondGesture = await tester.startGesture(secondFrom);
    await tester.pump(const Duration(milliseconds: 650));
    await secondGesture.moveTo(secondTo);
    await tester.pump();
    await secondGesture.up();
    await tester.pump();
    expect(model.playerControlOrder.take(5), [
      'favorite',
      'mode',
      'play',
      'next',
      'previous',
    ]);
  });

  testWidgets('create playlist sheet closes without disposing live fields', (
    tester,
  ) async {
    final model = AppModel();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          home: Scaffold(body: LibraryPage(model: model)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('新建歌单'));
    await tester.pumpAndSettle();
    expect(find.text('歌单名称'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('歌单名称'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon-only navigation centers icons lower without labels', (
    tester,
  ) async {
    final model = _UiTestModel()
      ..showSongCovers = false
      ..iconOnlyNavigation = false
      ..visualStyle = 'simple';
    addTearDown(model.dispose);
    await tester.pumpWidget(
      AppScope(
        model: model,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    final originalY = tester
        .getCenter(find.byIcon(Icons.library_music_outlined))
        .dy;
    await model.setIconOnlyNavigation(true);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    expect(
      tester.getCenter(find.byIcon(Icons.library_music_outlined)).dy,
      greaterThan(originalY),
    );
  });

  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('pages fit $size at text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = _UiTestModel()
          ..showSongCovers = false
          ..visualStyle = 'liquid'
          ..loggedIn = true;
        addTearDown(model.dispose);
        Widget host(Widget child) => AppScope(
          model: model,
          child: MaterialApp(
            theme: liquidTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        );
        for (final page in [
          HomePage(model: model),
          LibraryPage(model: model),
          MinePage(model: model),
        ]) {
          await tester.pumpWidget(host(page));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final scroll = find.byType(Scrollable).first;
          await tester.drag(scroll, const Offset(0, -450));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        for (var style = 0; style < 3; style++) {
          model.lyricsPlayerStyle = style;
          await tester.pumpWidget(
            host(
              SongDetailPage(
                key: ValueKey(style),
                model: model,
                song: model.displayPlayer.asMirrorItem(),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('播放页自定义'), findsOneWidget);
          expect(find.byType(CoverGlowBackground), findsOneWidget);
          if (style == 1) {
            final cover = tester.getSize(
              find.byKey(const ValueKey('vinyl-cover-clip')),
            );
            expect(cover.width, closeTo(cover.height, 0.01));
          }
          if (style == 2) {
            final cover = tester.getSize(
              find.byKey(const ValueKey('apple-artwork-square')),
            );
            expect(cover.width, closeTo(cover.height, 0.01));
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

class _UiTestModel extends AppModel {
  _UiTestModel() {
    playerBarVisible = true;
  }

  @override
  Future<void> openSongDetail(MirrorItem song) async {
    songDetail = SongDetail(
      song: song,
      coverUrl: '',
      lyricLines: const ['Test lyric'],
      lyrics: const [LyricLine(time: 0, text: 'Test lyric')],
      loading: false,
    );
    notifyListeners();
  }
}
