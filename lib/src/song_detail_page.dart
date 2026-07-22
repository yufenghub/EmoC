part of '../main.dart';

class SongDetailPage extends StatefulWidget {
  const SongDetailPage({required this.model, required this.song, super.key});

  final AppModel model;
  final MirrorItem song;

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  static const int _playerStyleCount = 3;
  static const int _initialLoopPage = 3000;

  late final PageController _pageController;
  String _requestedSongKey = '';
  bool _immersive = false;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialLoopPage);
    unawaited(NativeBridge.setAudioSpectrumEnabled(false));
    _requestSongDetail(widget.song);
  }

  @override
  void dispose() {
    unawaited(NativeBridge.setAudioSpectrumEnabled(false));
    _pageController.dispose();
    super.dispose();
  }

  void _requestSongDetail(MirrorItem song) {
    final key = _songKey(song);
    if (key.isEmpty || key == _requestedSongKey) return;
    _requestedSongKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.model.openSongDetail(song));
    });
  }

  String _songKey(MirrorItem song) {
    if (song.id.isNotEmpty) return song.id;
    if (song.href.isNotEmpty) return song.href;
    return song.title;
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
  }

  int _styleIndexForPage(int page) => page % _playerStyleCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.model,
        widget.model.playbackRevision,
      ]),
      builder: (context, _) {
        final player = widget.model.player.hasSong
            ? widget.model.player
            : widget.model.displayPlayer;
        final targetSong = player.hasSong ? player.asMirrorItem() : widget.song;
        _requestSongDetail(targetSong);
        final detail = widget.model.songDetail;
        final detailMatches =
            detail != null && _songKey(detail.song) == _songKey(targetSong);
        final song = detailMatches ? detail.song : targetSong;
        final lines = detailMatches ? detail.lyricLines : const <String>[];
        final timedLines = detailMatches ? detail.lyrics : const <LyricLine>[];
        final canScrollLyrics =
            timedLines.isNotEmpty &&
            player.hasSong &&
            (song.id == player.songId ||
                _songKey(song) == _songKey(targetSong) ||
                song.title.trim() == player.title.trim());
        final loading =
            widget.model.songDetailLoading || !detailMatches || detail.loading;
        final theme = Theme.of(context);
        final media = MediaQuery.of(context);
        final isLandscape = media.orientation == Orientation.landscape;
        final toolbarHeight = isLandscape ? 42.0 : kToolbarHeight;
        // Landscape player pages intentionally draw edge to edge. Keep the
        // two chrome controls in their own compact hit areas instead of
        // reserving a full status-bar row above the content.
        final landscapeChromeTop = max(
          20.0,
          min(30.0, 20 + media.viewPadding.top * 0.25),
        );
        final safeViewportHeight = (media.size.height - media.padding.top)
            .clamp(160.0, 10000.0)
            .toDouble();
        const normalContentTopPadding = 24.0;
        const lyricsHeaderHeight = 58.0;
        final headerToLyricsGap = isLandscape ? 6.0 : 22.0;
        final listBottomPadding = isLandscape
            ? 0.0
            : media.viewPadding.bottom + 8.0;
        final normalPortraitLyricHeight =
            (safeViewportHeight - 232.0 - listBottomPadding)
                .clamp(160.0, safeViewportHeight)
                .toDouble();
        final immersivePortraitLyricHeight =
            (safeViewportHeight -
                    lyricsHeaderHeight -
                    headerToLyricsGap -
                    listBottomPadding)
                .clamp(160.0, safeViewportHeight)
                .toDouble();
        final normalFocusedLyricY =
            toolbarHeight +
            normalContentTopPadding +
            lyricsHeaderHeight +
            headerToLyricsGap +
            normalPortraitLyricHeight * 0.48;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: ColoredBox(
            color: theme.colorScheme.surface,
            child: SafeArea(
              left: !isLandscape,
              top: !isLandscape,
              right: !isLandscape,
              bottom: false,
              child: _SongDetailResponsiveFrame(
                landscape: isLandscape,
                immersive: _immersive,
                toolbarHeight: toolbarHeight,
                chrome: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _immersive
                      ? const SizedBox.shrink(key: ValueKey('chrome-hidden'))
                      : Padding(
                          padding: EdgeInsets.only(
                            top: isLandscape ? landscapeChromeTop : 0,
                          ),
                          child: SizedBox(
                            key: const ValueKey('chrome-visible'),
                            height: toolbarHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox.square(
                                    dimension: toolbarHeight,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      style: const ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                          Colors.transparent,
                                        ),
                                        overlayColor: WidgetStatePropertyAll(
                                          Colors.transparent,
                                        ),
                                        shadowColor: WidgetStatePropertyAll(
                                          Colors.transparent,
                                        ),
                                        surfaceTintColor:
                                            WidgetStatePropertyAll(
                                              Colors.transparent,
                                            ),
                                      ),
                                      tooltip: '返回',
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                                  ),
                                ),
                                if (!isLandscape)
                                  Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: Text(
                                        _pageIndex == 0 ? '歌词' : '正在播放',
                                        key: ValueKey('portrait|$_pageIndex'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isLandscape ? 8 : 18,
                                    ),
                                    child: _LyricsPageIndicator(
                                      index: _pageIndex,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                content: PageView.builder(
                  controller: _pageController,
                  physics: const PageScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  onPageChanged: (page) {
                    if (!mounted) return;
                    final index = _styleIndexForPage(page);
                    setState(() {
                      _pageIndex = index;
                      if (index != 0) _immersive = false;
                    });
                    unawaited(NativeBridge.setAudioSpectrumEnabled(false));
                  },
                  itemBuilder: (context, page) {
                    final index = _styleIndexForPage(page);
                    final Widget child;
                    if (index == 0) {
                      child = Column(
                        key: const ValueKey('lyrics-page'),
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleImmersive,
                              child: LayoutBuilder(
                                builder: (context, contentConstraints) {
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      end: _immersive ? 1 : 0,
                                    ),
                                    duration: const Duration(milliseconds: 340),
                                    curve: Curves.easeInOutCubicEmphasized,
                                    builder: (context, immersiveProgress, _) {
                                      final previousLandscapeNormalTitleTop =
                                          max(
                                            media.viewPadding.top + 4,
                                            landscapeChromeTop +
                                                (toolbarHeight -
                                                        lyricsHeaderHeight) /
                                                    2,
                                          );
                                      final previousLandscapeImmersiveTitleTop =
                                          max(
                                            0.0,
                                            previousLandscapeNormalTitleTop -
                                                14,
                                          );
                                      final landscapeTitleLineHeight =
                                          (theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.fontSize ??
                                              24) *
                                          1.2;
                                      final landscapeNormalTitleTop =
                                          previousLandscapeImmersiveTitleTop;
                                      final landscapeImmersiveTitleTop = max(
                                        0.0,
                                        landscapeNormalTitleTop -
                                            landscapeTitleLineHeight,
                                      );
                                      final contentTopPadding = ui.lerpDouble(
                                        isLandscape
                                            ? landscapeNormalTitleTop
                                            : normalContentTopPadding,
                                        isLandscape
                                            ? landscapeImmersiveTitleTop
                                            : 0,
                                        immersiveProgress,
                                      )!;
                                      final effectiveHeaderToLyricsGap =
                                          isLandscape
                                          ? ui.lerpDouble(
                                              headerToLyricsGap,
                                              0,
                                              immersiveProgress,
                                            )!
                                          : headerToLyricsGap;
                                      final effectiveLyricHeight = isLandscape
                                          ? (contentConstraints.maxHeight -
                                                    contentTopPadding -
                                                    lyricsHeaderHeight -
                                                    effectiveHeaderToLyricsGap)
                                                .clamp(
                                                  160.0,
                                                  contentConstraints.maxHeight,
                                                )
                                                .toDouble()
                                          : ui.lerpDouble(
                                              normalPortraitLyricHeight,
                                              immersivePortraitLyricHeight,
                                              immersiveProgress,
                                            )!;
                                      final currentFrameTop = isLandscape
                                          ? 0.0
                                          : ui.lerpDouble(
                                              toolbarHeight,
                                              0,
                                              immersiveProgress,
                                            )!;
                                      final currentLyricsTop =
                                          currentFrameTop +
                                          contentTopPadding +
                                          lyricsHeaderHeight +
                                          effectiveHeaderToLyricsGap;
                                      final focusAlignment = isLandscape
                                          ? 0.48
                                          : ((normalFocusedLyricY -
                                                        currentLyricsTop) /
                                                    effectiveLyricHeight)
                                                .clamp(0.2, 0.8)
                                                .toDouble();
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          top: contentTopPadding,
                                        ),
                                        child: ListView(
                                          padding: EdgeInsets.fromLTRB(
                                            22,
                                            0,
                                            22,
                                            listBottomPadding,
                                          ),
                                          children: [
                                            _AnimatedLyricsHeader(
                                              song: song,
                                              landscape: isLandscape,
                                            ),
                                            SizedBox(
                                              height:
                                                  effectiveHeaderToLyricsGap,
                                            ),
                                            if (loading)
                                              const LoadingPanel(
                                                text: '正在展开完整歌词',
                                                framed: false,
                                              )
                                            else if (lines.isEmpty)
                                              const EmptyPanel(
                                                icon: Icons.lyrics_outlined,
                                                text: '暂无歌词',
                                              )
                                            else if (canScrollLyrics)
                                              _LyricsEdgeFade(
                                                child: ScrollingLyrics(
                                                  lines: timedLines,
                                                  currentTimeSeconds:
                                                      player.currentTimeSeconds,
                                                  height: effectiveLyricHeight,
                                                  focusAlignment:
                                                      focusAlignment,
                                                ),
                                              )
                                            else
                                              _LyricsEdgeFade(
                                                child: LyricsBlock(
                                                  lines: lines,
                                                  framed: false,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          _LyricsPlayerBarTransition(
                            visible: !_immersive && widget.model.showPlayerBar,
                            child: RepaintBoundary(
                              key: const ValueKey(
                                'integrated-lyrics-player-bar',
                              ),
                              child: PlayerBar(
                                model: widget.model,
                                canOpenSongDetail: false,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else if (index == 1) {
                      child = LyricsPlayerView(
                        key: const ValueKey('player-page'),
                        model: widget.model,
                        player: player,
                        song: song,
                        lyrics: timedLines,
                        lyricsLoading: loading,
                      );
                    } else {
                      child = AppleMusicPlayerView(
                        key: const ValueKey('apple-player-page'),
                        model: widget.model,
                        player: player,
                        song: song,
                        lyrics: timedLines,
                        lyricsLoading: loading,
                      );
                    }
                    return _LyricsPageTransition(
                      controller: _pageController,
                      pageIndex: page,
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedLyricsHeader extends StatelessWidget {
  const _AnimatedLyricsHeader({required this.song, required this.landscape});

  final MirrorItem song;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      key: ValueKey('lyrics-content-header-${song.id}|${song.title}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          song.subtitle.isEmpty ? '网易云音乐' : song.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (landscape) {
      return SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 70),
          child: content,
        ),
      );
    }
    // The list viewport clips children translated above its leading edge.
    // Portrait movement is therefore handled by the list's top padding rather
    // than a negative transform, keeping the title fully readable.
    return SizedBox(height: 58, child: content);
  }
}

class _SongDetailResponsiveFrame extends StatelessWidget {
  const _SongDetailResponsiveFrame({
    required this.landscape,
    required this.immersive,
    required this.toolbarHeight,
    required this.chrome,
    required this.content,
  });

  final bool landscape;
  final bool immersive;
  final double toolbarHeight;
  final Widget chrome;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubicEmphasized,
          left: 0,
          top: landscape ? 0 : (immersive ? 0 : toolbarHeight),
          right: 0,
          bottom: 0,
          child: content,
        ),
        Align(alignment: Alignment.topCenter, child: chrome),
      ],
    );
  }
}

class _LyricsPlayerBarTransition extends StatefulWidget {
  const _LyricsPlayerBarTransition({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<_LyricsPlayerBarTransition> createState() =>
      _LyricsPlayerBarTransitionState();
}

class _LyricsPlayerBarTransitionState extends State<_LyricsPlayerBarTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.visible ? 1 : 0,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(_curve);
  }

  @override
  void didUpdateWidget(covariant _LyricsPlayerBarTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isDismissed) {
          return const SizedBox.shrink(
            key: ValueKey('lyrics-player-bar-hidden'),
          );
        }
        return ClipRect(
          child: SizeTransition(
            sizeFactor: _curve,
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(opacity: _curve, child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

class PlayerQueueSheet extends StatelessWidget {
  const PlayerQueueSheet({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: model,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '播放列表',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: '刷新播放列表',
                        onPressed: model.loadPlayerQueue,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: model.queueLoading
                        ? const LoadingPanel(text: '正在加载播放列表')
                        : QueueSongList(
                            songs: model.playerQueue.isEmpty
                                ? model.currentPlaylist
                                : model.playerQueue,
                            currentIndex: _queueCurrentIndexFromModel(
                              songs: model.playerQueue.isEmpty
                                  ? model.currentPlaylist
                                  : model.playerQueue,
                              model: model,
                            ),
                            dynamicColorSource:
                                model._activePlaybackDynamicSource,
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class QueueSongList extends StatefulWidget {
  const QueueSongList({
    required this.songs,
    required this.currentIndex,
    required this.dynamicColorSource,
    super.key,
  });

  final List<MirrorItem> songs;
  final int currentIndex;
  final String dynamicColorSource;

  @override
  State<QueueSongList> createState() => _QueueSongListState();
}

class _QueueSongListState extends State<QueueSongList> {
  final ScrollController controller = ScrollController();
  int? _lastScrolledIndex;

  static const double _queueTileExtent = 76;

  @override
  void initState() {
    super.initState();
    _scrollCurrentToTop(animated: false);
  }

  @override
  void didUpdateWidget(covariant QueueSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.songs.length != widget.songs.length) {
      _scrollCurrentToTop(animated: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _scrollCurrentToTop({required bool animated}) {
    final index = widget.currentIndex;
    if (index < 0 || index >= widget.songs.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      if (_lastScrolledIndex == index &&
          (controller.offset - index * _queueTileExtent).abs() < 6) {
        return;
      }
      _lastScrolledIndex = index;
      final target = (index * _queueTileExtent).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      if (animated) {
        controller.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) {
      return const EmptyPanel(icon: Icons.music_off, text: '无歌曲');
    }
    return ListView.builder(
      controller: controller,
      itemExtent: _queueTileExtent,
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PreparedSongTile(
            song: widget.songs[index],
            sourceList: widget.songs,
            sourceIndex: index,
            active: index == widget.currentIndex,
            dynamicColorSource: widget.dynamicColorSource,
          ),
        );
      },
    );
  }
}

int _queueCurrentIndexFromModel({
  required List<MirrorItem> songs,
  required AppModel model,
}) {
  final modelIndex = model.currentSongIndex;
  if (modelIndex >= 0 &&
      modelIndex < songs.length &&
      _songMatchesPlayer(songs[modelIndex], model.player)) {
    return modelIndex;
  }
  return _queueCurrentIndex(songs: songs, player: model.player);
}

int _queueCurrentIndex({
  required List<MirrorItem> songs,
  required PlayerSnapshot player,
}) {
  if (songs.isEmpty || !player.hasSong) return -1;
  if (player.songId.isNotEmpty) {
    final byId = songs.indexWhere((song) => song.id == player.songId);
    if (byId >= 0) return byId;
  }
  final playerTitle = player.title.trim();
  if (playerTitle.isEmpty) return -1;
  return songs.indexWhere((song) => _songMatchesPlayer(song, player));
}

bool _songMatchesPlayer(MirrorItem song, PlayerSnapshot player) {
  if (!player.hasSong) return false;
  if (song.id.isNotEmpty && player.songId.isNotEmpty) {
    return song.id == player.songId;
  }
  final titleMatches = song.title.trim() == player.title.trim();
  if (!titleMatches) return false;
  final artist = player.displayArtist.trim();
  if (artist.isEmpty) return true;
  return song.subtitle.contains(artist) || artist.contains(song.subtitle);
}

class _LyricsEdgeFade extends StatelessWidget {
  const _LyricsEdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0, 0.09, 0.9, 1],
      ).createShader(bounds),
      child: ClipRect(child: child),
    );
  }
}

class LyricsBlock extends StatelessWidget {
  const LyricsBlock({required this.lines, this.framed = true, super.key});

  final List<String> lines;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: framed ? 22 : 8,
        horizontal: framed ? 18 : 6,
      ),
      decoration: framed
          ? BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          for (final line in lines) ...[
            Text(
              line,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.38),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class ScrollingLyrics extends StatefulWidget {
  const ScrollingLyrics({
    required this.lines,
    required this.currentTimeSeconds,
    required this.height,
    this.focusAlignment = 0.48,
    this.textAlign = TextAlign.center,
    this.horizontalPadding = 30,
    super.key,
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final double height;
  final double focusAlignment;
  final TextAlign textAlign;
  final double horizontalPadding;

  @override
  State<ScrollingLyrics> createState() => _ScrollingLyricsState();
}

class _ScrollingLyricsState extends State<ScrollingLyrics> {
  final ScrollController controller = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  List<GlobalKey> _lineKeys = const [];
  int _lastActiveIndex = -1;
  bool _needsInitialCenter = true;
  bool _isAutoScrolling = false;
  bool _userBrowsingLyrics = false;
  Timer? _resumeFollowTimer;
  Timer? _geometrySettleTimer;
  int _centerGeneration = 0;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    _ensureLineKeys();
  }

  @override
  void didUpdateWidget(covariant ScrollingLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lineSignature(widget.lines) != _lastSignature) {
      _lastActiveIndex = -1;
      _needsInitialCenter = true;
      _centerGeneration++;
      _ensureLineKeys();
      if (controller.hasClients) controller.jumpTo(0);
    }
    if ((oldWidget.height - widget.height).abs() > 0.5 ||
        (oldWidget.focusAlignment - widget.focusAlignment).abs() > 0.002) {
      _geometrySettleTimer?.cancel();
      _geometrySettleTimer = Timer(const Duration(milliseconds: 390), () {
        if (!mounted || _userBrowsingLyrics) return;
        _centerActiveLine(_activeIndex(), force: true);
      });
    }
  }

  @override
  void dispose() {
    _resumeFollowTimer?.cancel();
    _geometrySettleTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _ensureLineKeys() {
    final signature = _lineSignature(widget.lines);
    if (signature == _lastSignature &&
        _lineKeys.length == widget.lines.length) {
      return;
    }
    _lastSignature = signature;
    _needsInitialCenter = true;
    _centerGeneration++;
    _lineKeys = List<GlobalKey>.generate(
      widget.lines.length,
      (_) => GlobalKey(),
      growable: false,
    );
  }

  String _lineSignature(List<LyricLine> lines) {
    if (lines.isEmpty) return 'empty';
    return '${lines.length}:${lines.first.time}:${lines.last.time}:${lines.first.text}:${lines.last.text}';
  }

  int _activeIndex() {
    var active = 0;
    for (var i = 0; i < widget.lines.length; i++) {
      if (widget.lines[i].time <= widget.currentTimeSeconds + 0.12) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _centerActiveLine(
    int active, {
    bool force = false,
    int retry = 0,
    int? generation,
  }) {
    final centerGeneration = generation ?? _centerGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !controller.hasClients ||
          active >= _lineKeys.length ||
          centerGeneration != _centerGeneration) {
        return;
      }
      final itemContext = _lineKeys[active].currentContext;
      final viewportContext = _viewportKey.currentContext;
      if (itemContext == null || viewportContext == null) {
        _retryCenterActiveLine(active, force, retry, centerGeneration);
        return;
      }
      final itemBox = itemContext.findRenderObject();
      final viewportBox = viewportContext.findRenderObject();
      if (itemBox is! RenderBox || viewportBox is! RenderBox) {
        _retryCenterActiveLine(active, force, retry, centerGeneration);
        return;
      }
      final itemTop =
          itemBox.localToGlobal(Offset.zero).dy -
          viewportBox.localToGlobal(Offset.zero).dy;
      final itemCenter = itemTop + itemBox.size.height / 2;
      final maxExtent = controller.position.maxScrollExtent;
      final viewportHeight = viewportBox.size.height;
      if (force && maxExtent <= 0 && widget.lines.length > 6) {
        _retryCenterActiveLine(active, force, retry, centerGeneration);
        return;
      }
      final target =
          (controller.offset +
                  itemCenter -
                  viewportHeight * widget.focusAlignment.clamp(0.2, 0.8))
              .clamp(0.0, maxExtent)
              .toDouble();
      _needsInitialCenter = false;
      if ((controller.offset - target).abs() < 2) return;
      final distance = (controller.offset - target).abs();
      if ((controller.offset - target).abs() > viewportHeight * 0.8) {
        _isAutoScrolling = true;
        controller.jumpTo(target);
        _isAutoScrolling = false;
        return;
      }
      _isAutoScrolling = true;
      unawaited(
        controller
            .animateTo(
              target,
              duration: _scrollDuration(distance, force: force),
              curve: Curves.easeInOutCubic,
            )
            .whenComplete(() {
              if (mounted) _isAutoScrolling = false;
            }),
      );
    });
  }

  Duration _scrollDuration(double distance, {required bool force}) {
    final normalized = (distance / widget.height).clamp(0.0, 1.0);
    final base = force ? 240 : 420;
    final extra = (normalized * 130).round();
    return Duration(milliseconds: base + extra);
  }

  void _beginUserBrowse() {
    if (_isAutoScrolling) return;
    _resumeFollowTimer?.cancel();
    _userBrowsingLyrics = true;
  }

  void _scheduleResumeFollow() {
    if (_isAutoScrolling || !_userBrowsingLyrics) return;
    _resumeFollowTimer?.cancel();
    _resumeFollowTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _userBrowsingLyrics = false;
      _lastActiveIndex = -1;
      _centerActiveLine(_activeIndex(), force: true);
    });
  }

  void _retryCenterActiveLine(
    int active,
    bool force,
    int retry,
    int generation,
  ) {
    if (!force || retry >= 8) return;
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (!mounted || generation != _centerGeneration) return;
      _centerActiveLine(
        active,
        force: force,
        retry: retry + 1,
        generation: generation,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureLineKeys();
    final active = _activeIndex();
    if (_needsInitialCenter ||
        (!_userBrowsingLyrics && active != _lastActiveIndex)) {
      _lastActiveIndex = active;
      _centerActiveLine(active, force: _needsInitialCenter);
    } else if (_userBrowsingLyrics && active != _lastActiveIndex) {
      _lastActiveIndex = active;
    }
    return SizedBox(
      key: _viewportKey,
      width: double.infinity,
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (_isAutoScrolling) return false;
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _beginUserBrowse();
          } else if (notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle) {
            _beginUserBrowse();
          } else if (notification is ScrollEndNotification ||
              notification is UserScrollNotification &&
                  notification.direction == ScrollDirection.idle) {
            _scheduleResumeFollow();
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            max(12, widget.height * widget.focusAlignment - 24),
            0,
            max(12, widget.height * (1 - widget.focusAlignment) - 24),
          ),
          child: Column(
            children: [
              for (var index = 0; index < widget.lines.length; index++)
                LyricLineView(
                  key: _lineKeys[index],
                  line: widget.lines[index].text,
                  distanceFromActive: (index - active).abs(),
                  textAlign: widget.textAlign,
                  horizontalPadding: widget.horizontalPadding,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LyricLineView extends StatelessWidget {
  const LyricLineView({
    required this.line,
    required this.distanceFromActive,
    this.textAlign = TextAlign.center,
    this.horizontalPadding = 18,
    super.key,
  });

  final String line;
  final int distanceFromActive;
  final TextAlign textAlign;
  final double horizontalPadding;

  double get _emphasis {
    if (distanceFromActive == 0) return 1;
    if (distanceFromActive == 1) return 0.42;
    if (distanceFromActive == 2) return 0.18;
    return 0;
  }

  double get _opacity {
    if (distanceFromActive == 0) return 1;
    if (distanceFromActive == 1) return 0.72;
    if (distanceFromActive == 2) return 0.48;
    return 0.3;
  }

  double get _scale {
    if (distanceFromActive == 0) return 1.035;
    if (distanceFromActive == 1) return 0.995;
    return 0.97;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge ?? const TextStyle();
    final alignment = switch (textAlign) {
      TextAlign.left || TextAlign.start => Alignment.centerLeft,
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      _ => Alignment.center,
    };
    final color = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.primary,
      _emphasis,
    )!.withAlpha((_opacity * 255).round());

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: horizontalPadding),
      child: AnimatedScale(
        scale: _scale,
        alignment: alignment,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        child: AnimatedAlign(
          alignment: alignment,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            style: baseStyle.copyWith(
              height: 1.25,
              fontWeight: FontWeight.lerp(
                FontWeight.w600,
                FontWeight.w800,
                _emphasis,
              ),
              color: color,
            ),
            child: Text(line, textAlign: textAlign, softWrap: true),
          ),
        ),
      ),
    );
  }
}
