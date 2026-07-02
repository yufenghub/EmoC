part of '../main.dart';

class SongDetailPage extends StatefulWidget {
  const SongDetailPage({required this.model, required this.song, super.key});

  final AppModel model;
  final MirrorItem song;

  @override
  State<SongDetailPage> createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  String _requestedSongKey = '';
  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    _requestSongDetail(widget.song);
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
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
        final viewportHeight = (media.size.height - media.padding.top)
            .clamp(160.0, 10000.0)
            .toDouble();
        final lyricHeight = (viewportHeight - (_immersive ? 92.0 : 232.0))
            .clamp(160.0, viewportHeight)
            .toDouble();
        final listBottomPadding = 0.0;
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: ColoredBox(
            color: theme.colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AnimatedSwitcher(
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
                        : SizedBox(
                            key: const ValueKey('chrome-visible'),
                            height: kToolbarHeight,
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: '返回',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '歌词',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleImmersive,
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        padding: EdgeInsets.only(top: _immersive ? 6 : 0),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            _immersive ? 8 : 18,
                            22,
                            listBottomPadding,
                          ),
                          children: [
                            Text(
                              song.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.subtitle.isEmpty ? '网易云音乐' : song.subtitle,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              height: _immersive ? 8 : 22,
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
                              ScrollingLyrics(
                                lines: timedLines,
                                currentTimeSeconds: player.currentTimeSeconds,
                                height: lyricHeight,
                              )
                            else
                              LyricsBlock(lines: lines, framed: false),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            child: !_immersive && widget.model.showPlayerBar
                ? Builder(
                    builder: (context) {
                      return Material(
                        color: theme.colorScheme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlayerBar(
                              model: widget.model,
                              canOpenSongDetail: false,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
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
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final queueSongs = model.playerQueue.isEmpty
                                  ? model.currentPlaylist
                                  : model.playerQueue;
                              final currentIndex = _queueCurrentIndexFromModel(
                                songs: queueSongs,
                                model: model,
                              );
                              final lyric = model.queueLyricLines.isEmpty
                                  ? const EmptyPanel(
                                      icon: Icons.lyrics_outlined,
                                      text: '暂无滚动歌词',
                                    )
                                  : LyricsBlock(lines: model.queueLyricLines);
                              if (constraints.maxWidth >= 700) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: QueueSongList(
                                        songs: queueSongs,
                                        currentIndex: currentIndex,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: lyric,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  Expanded(
                                    child: QueueSongList(
                                      songs: queueSongs,
                                      currentIndex: currentIndex,
                                    ),
                                  ),
                                  if (model.queueLyricLines.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 170,
                                      child: SingleChildScrollView(
                                        child: lyric,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
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
    super.key,
  });

  final List<MirrorItem> songs;
  final int currentIndex;

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
          child: SongTile(
            song: widget.songs[index],
            sourceList: widget.songs,
            sourceIndex: index,
            active: index == widget.currentIndex,
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
    super.key,
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final double height;

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
  }

  @override
  void dispose() {
    _resumeFollowTimer?.cancel();
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
      final target = (controller.offset + itemCenter - viewportHeight * 0.44)
          .clamp(0.0, maxExtent)
          .toDouble();
      _needsInitialCenter = false;
      if ((controller.offset - target).abs() < 2) return;
      final distance = (controller.offset - target).abs();
      if ((controller.offset - target).abs() > viewportHeight * 0.8) {
        _isAutoScrolling = true;
        controller.jumpTo(target);
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted) _isAutoScrolling = false;
        });
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
              Future<void>.delayed(const Duration(milliseconds: 80), () {
                if (mounted) _isAutoScrolling = false;
              });
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
          padding: EdgeInsets.fromLTRB(12, 12, 12, widget.height / 2 - 20),
          child: Column(
            children: [
              for (var index = 0; index < widget.lines.length; index++)
                LyricLineView(
                  key: _lineKeys[index],
                  line: widget.lines[index].text,
                  distanceFromActive: (index - active).abs(),
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
    super.key,
  });

  final String line;
  final int distanceFromActive;

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
    final color = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.primary,
      _emphasis,
    )!.withAlpha((_opacity * 255).round());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
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
          child: Text(line, textAlign: TextAlign.center, softWrap: true),
        ),
      ),
    );
  }
}
