part of '../main.dart';

String _highResolutionArtworkUrl(String rawUrl) {
  final normalized = rawUrl.replaceFirst(RegExp(r'^http://'), 'https://');
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.host.endsWith('music.126.net')) return normalized;
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'param': '800y800'})
      .toString();
}

class LyricsPlayerView extends StatefulWidget {
  const LyricsPlayerView({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;

  @override
  State<LyricsPlayerView> createState() => _LyricsPlayerViewState();
}

class _LyricsPlayerViewState extends State<LyricsPlayerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  String _artworkRequestKey = '';
  int _titleAlignmentIndex = 1;
  int _lyricsAlignmentIndex = 1;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 22500),
    );
    _syncRotation();
    _prepareArtwork();
    unawaited(_restoreTextAlignments());
  }

  @override
  void didUpdateWidget(covariant LyricsPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.playing != widget.player.playing) _syncRotation();
    if (oldWidget.player.songId != widget.player.songId ||
        oldWidget.song.id != widget.song.id ||
        oldWidget.player.coverUrl != widget.player.coverUrl) {
      _prepareArtwork();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncRotation() {
    if (widget.player.playing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop(canceled: false);
    }
  }

  void _prepareArtwork() {
    final key = widget.song.id.isNotEmpty
        ? widget.song.id
        : '${widget.song.title}|${widget.song.subtitle}';
    if (key.isEmpty || key == _artworkRequestKey) return;
    _artworkRequestKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.model.showSongCovers) return;
      unawaited(widget.model.prepareSongArtwork(widget.song));
    });
  }

  Future<void> _restoreTextAlignments() async {
    final values = await Future.wait([
      NativeBridge.getString('vinylTitleAlignment'),
      NativeBridge.getString('vinylLyricsAlignment'),
    ]);
    if (!mounted) return;
    setState(() {
      _titleAlignmentIndex =
          int.tryParse(values[0] ?? '')?.clamp(0, 2).toInt() ?? 1;
      _lyricsAlignmentIndex =
          int.tryParse(values[1] ?? '')?.clamp(0, 2).toInt() ?? 1;
    });
  }

  void _setTitleAlignment(int value) {
    final next = value.clamp(0, 2).toInt();
    if (next == _titleAlignmentIndex) return;
    setState(() => _titleAlignmentIndex = next);
    unawaited(NativeBridge.setString('vinylTitleAlignment', '$next'));
  }

  void _setLyricsAlignment(int value) {
    final next = value.clamp(0, 2).toInt();
    if (next == _lyricsAlignmentIndex) return;
    setState(() => _lyricsAlignmentIndex = next);
    unawaited(NativeBridge.setString('vinylLyricsAlignment', '$next'));
  }

  String get _coverUrl {
    for (final candidate in [
      widget.player.coverUrl,
      widget.song.imageUrl,
      widget.model.coverFor(widget.song),
    ]) {
      if (candidate.startsWith('http')) {
        return _highResolutionArtworkUrl(candidate);
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      key: const ValueKey('lyrics-player-background'),
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight * 1.18;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: landscape
                ? _LandscapeLyricsPlayer(
                    key: const ValueKey('landscape-player'),
                    model: widget.model,
                    player: widget.player,
                    song: widget.song,
                    lyrics: widget.lyrics,
                    lyricsLoading: widget.lyricsLoading,
                    coverUrl: _coverUrl,
                    rotation: _rotationController,
                    titleAlignmentIndex: _titleAlignmentIndex,
                    lyricsAlignmentIndex: _lyricsAlignmentIndex,
                    onTitleAlignmentChanged: _setTitleAlignment,
                    onLyricsAlignmentChanged: _setLyricsAlignment,
                  )
                : _PortraitLyricsPlayer(
                    key: const ValueKey('portrait-player'),
                    model: widget.model,
                    player: widget.player,
                    song: widget.song,
                    lyrics: widget.lyrics,
                    lyricsLoading: widget.lyricsLoading,
                    coverUrl: _coverUrl,
                    rotation: _rotationController,
                    titleAlignmentIndex: _titleAlignmentIndex,
                    lyricsAlignmentIndex: _lyricsAlignmentIndex,
                    onTitleAlignmentChanged: _setTitleAlignment,
                    onLyricsAlignmentChanged: _setLyricsAlignment,
                  ),
          );
        },
      ),
    );
  }
}

Alignment _textAlignmentForIndex(int index) => switch (index) {
  0 => Alignment.centerLeft,
  2 => Alignment.centerRight,
  _ => Alignment.center,
};

TextAlign _textAlignForIndex(int index) => switch (index) {
  0 => TextAlign.left,
  2 => TextAlign.right,
  _ => TextAlign.center,
};

const _vinylTextHorizontalInset = 22.0;

CrossAxisAlignment _crossAxisAlignmentForIndex(int index) => switch (index) {
  0 => CrossAxisAlignment.start,
  2 => CrossAxisAlignment.end,
  _ => CrossAxisAlignment.center,
};

class _AlignmentSwipeRegion extends StatefulWidget {
  const _AlignmentSwipeRegion({
    required this.alignmentIndex,
    required this.onAlignmentChanged,
    required this.child,
  });

  final int alignmentIndex;
  final ValueChanged<int> onAlignmentChanged;
  final Widget child;

  @override
  State<_AlignmentSwipeRegion> createState() => _AlignmentSwipeRegionState();
}

class _AlignmentSwipeRegionState extends State<_AlignmentSwipeRegion> {
  double _dragDistance = 0;

  void _finishDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final gesture = _dragDistance.abs() >= 26
        ? _dragDistance
        : velocity.abs() >= 220
        ? velocity
        : 0.0;
    _dragDistance = 0;
    if (gesture == 0) return;
    final direction = gesture > 0 ? 1 : -1;
    widget.onAlignmentChanged(
      (widget.alignmentIndex + direction).clamp(0, 2).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: _finishDrag,
      onHorizontalDragCancel: () => _dragDistance = 0,
      child: widget.child,
    );
  }
}

class _SwipeAlignedSongInfo extends StatelessWidget {
  const _SwipeAlignedSongInfo({
    required this.title,
    required this.subtitle,
    required this.alignmentIndex,
    required this.onAlignmentChanged,
  });

  final String title;
  final String subtitle;
  final int alignmentIndex;
  final ValueChanged<int> onAlignmentChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = _textAlignmentForIndex(alignmentIndex);
    final textAlign = _textAlignForIndex(alignmentIndex);
    return _AlignmentSwipeRegion(
      alignmentIndex: alignmentIndex,
      onAlignmentChanged: onAlignmentChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _vinylTextHorizontalInset,
        ),
        child: AnimatedAlign(
          alignment: alignment,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubicEmphasized,
          child: FractionallySizedBox(
            widthFactor: 0.86,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: _crossAxisAlignmentForIndex(alignmentIndex),
              children: [
                Text(
                  title,
                  textAlign: textAlign,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: textAlign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitLyricsPlayer extends StatelessWidget {
  const _PortraitLyricsPlayer({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.coverUrl,
    required this.rotation,
    required this.titleAlignmentIndex,
    required this.lyricsAlignmentIndex,
    required this.onTitleAlignmentChanged,
    required this.onLyricsAlignmentChanged,
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;
  final Animation<double> rotation;
  final int titleAlignmentIndex;
  final int lyricsAlignmentIndex;
  final ValueChanged<int> onTitleAlignmentChanged;
  final ValueChanged<int> onLyricsAlignmentChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleLineHeight =
            (theme.textTheme.headlineSmall?.fontSize ?? 24) * 1.2;
        final titleAndLyricsLift = titleLineHeight * 0.5;
        final lyricsViewportLift =
            titleAndLyricsLift + max(0.0, titleLineHeight - 2);
        final topLyricFadeLift =
            (theme.textTheme.bodyLarge?.fontSize ?? 16) * 1.25 / 3;
        final deckSize = min(
          constraints.maxWidth - 12,
          constraints.maxHeight * 0.49,
        ).clamp(200.0, 440.0).toDouble();
        return Transform.translate(
          offset: const Offset(0, -7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Column(
              children: [
                Transform.translate(
                  offset: Offset(0, -titleLineHeight),
                  child: _RecordDeck(
                    size: deckSize,
                    coverUrl: coverUrl,
                    songIdentity: song.id,
                    showCover: model.showSongCovers,
                    rotation: rotation,
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 7 - titleLineHeight - titleAndLyricsLift),
                  child: _SwipeAlignedSongInfo(
                    title: song.title,
                    subtitle: song.subtitle.isEmpty
                        ? player.displayArtist
                        : song.subtitle,
                    alignmentIndex: titleAlignmentIndex,
                    onAlignmentChanged: onTitleAlignmentChanged,
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, lyricConstraints) {
                      final shiftedHeight =
                          lyricConstraints.maxHeight + lyricsViewportLift;
                      return Transform.translate(
                        offset: Offset(0, -lyricsViewportLift),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: shiftedHeight,
                          maxHeight: shiftedHeight,
                          child: _VinylScrollingLyrics(
                            lines: lyrics,
                            currentTimeSeconds: player.currentTimeSeconds,
                            loading: lyricsLoading,
                            height: shiftedHeight,
                            alignmentIndex: lyricsAlignmentIndex,
                            onAlignmentChanged: onLyricsAlignmentChanged,
                            topFadeLift: topLyricFadeLift,
                            bottomFadeGap: 6,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                _ExpandedPlayerProgress(model: model, player: player),
                const SizedBox(height: 6),
                KeyedSubtree(
                  key: const ValueKey('vinyl-player-controls'),
                  child: _ExpandedPlayerControls(model: model, player: player),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LandscapeLyricsPlayer extends StatelessWidget {
  const _LandscapeLyricsPlayer({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.coverUrl,
    required this.rotation,
    required this.titleAlignmentIndex,
    required this.lyricsAlignmentIndex,
    required this.onTitleAlignmentChanged,
    required this.onLyricsAlignmentChanged,
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;
  final Animation<double> rotation;
  final int titleAlignmentIndex;
  final int lyricsAlignmentIndex;
  final ValueChanged<int> onTitleAlignmentChanged;
  final ValueChanged<int> onLyricsAlignmentChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deckSize = min(
          constraints.maxWidth * 0.52,
          max(150.0, constraints.maxHeight - 8),
        ).clamp(150.0, 500.0).toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(52, 4, 52, 4),
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: Center(
                  child: _RecordDeck(
                    size: deckSize,
                    coverUrl: coverUrl,
                    songIdentity: song.id,
                    showCover: model.showSongCovers,
                    rotation: rotation,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SwipeAlignedSongInfo(
                        title: song.title,
                        subtitle: song.subtitle.isEmpty
                            ? player.displayArtist
                            : song.subtitle,
                        alignmentIndex: titleAlignmentIndex,
                        onAlignmentChanged: onTitleAlignmentChanged,
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, lyricConstraints) {
                            return _VinylScrollingLyrics(
                              lines: lyrics,
                              currentTimeSeconds: player.currentTimeSeconds,
                              loading: lyricsLoading,
                              height: lyricConstraints.maxHeight,
                              alignmentIndex: lyricsAlignmentIndex,
                              onAlignmentChanged: onLyricsAlignmentChanged,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ExpandedPlayerProgress(model: model, player: player),
                      const SizedBox(height: 4),
                      _ExpandedPlayerControls(
                        model: model,
                        player: player,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordDeck extends StatelessWidget {
  const _RecordDeck({
    required this.size,
    required this.coverUrl,
    required this.songIdentity,
    required this.showCover,
    required this.rotation,
  });

  final double size;
  final String coverUrl;
  final String songIdentity;
  final bool showCover;
  final Animation<double> rotation;

  @override
  Widget build(BuildContext context) {
    final coverSize = size * 0.819;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: SizedBox.square(
          dimension: coverSize,
          child: RepaintBoundary(
            child: RotationTransition(
              key: ValueKey('vinyl-record-$songIdentity'),
              turns: rotation,
              child: ClipOval(
                child: _SlidingCoverSwitcher(
                  transitionKey: '$songIdentity|$coverUrl|$showCover',
                  child: showCover
                      ? CoverImage(
                          url: coverUrl,
                          identity: songIdentity,
                          fallbackIcon: Icons.album_outlined,
                          preferredSize: 800,
                          decodeSize: 512,
                        )
                      : ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.album_outlined,
                            size: coverSize * 0.34,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidingCoverSwitcher extends StatelessWidget {
  const _SlidingCoverSwitcher({
    required this.transitionKey,
    required this.child,
  });

  final String transitionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey('sliding-cover-$transitionKey');
    final direction = transitionKey.hashCode.isEven ? 1.0 : -1.0;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        reverseDuration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (transitionChild, animation) {
          final incoming = transitionChild.key == currentKey;
          final offset = incoming
              ? Tween<Offset>(begin: Offset(direction, 0), end: Offset.zero)
              : Tween<Offset>(
                  begin: Offset(-direction * 0.12, 0),
                  end: Offset.zero,
                );
          return SlideTransition(
            position: offset.animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: transitionChild,
          );
        },
        child: KeyedSubtree(key: currentKey, child: child),
      ),
    );
  }
}

// Kept temporarily for compatibility with older golden tests.
// ignore: unused_element
class _CurrentLyricPreview extends StatelessWidget {
  const _CurrentLyricPreview({
    required this.lines,
    required this.currentTimeSeconds,
    required this.loading,
    required this.compact,
    required this.textAlign,
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final bool loading;
  final bool compact;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _activeLyricsPlayerLine(lines, currentTimeSeconds);
    final current = index >= 0 ? lines[index].text.trim() : '';
    final primaryText = loading && current.isEmpty
        ? '正在加载歌词'
        : current.isEmpty
        ? '用音乐安放此刻'
        : current;
    final visibleLines = <({int index, String text})>[];
    if (index < 0 || lines.isEmpty) {
      visibleLines.add((index: -1, text: primaryText));
    } else {
      final availableCount = min(2, lines.length - index);
      final maxStart = max(0, lines.length - availableCount);
      final start = index.clamp(0, maxStart);
      for (
        var lineIndex = start;
        lineIndex < start + availableCount;
        lineIndex++
      ) {
        final text = lines[lineIndex].text.trim();
        if (text.isNotEmpty) {
          visibleLines.add((index: lineIndex, text: text));
        }
      }
      if (visibleLines.isEmpty) {
        visibleLines.add((index: index, text: primaryText));
      }
    }
    final alignment = textAlign == TextAlign.left
        ? Alignment.centerLeft
        : textAlign == TextAlign.right
        ? Alignment.centerRight
        : Alignment.center;
    return SizedBox(
      width: double.infinity,
      height: compact ? 56 : 70,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: alignment,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, animatedChild) {
              final exiting = animation.status == AnimationStatus.reverse;
              final remaining = 1 - animation.value;
              return Transform.translate(
                offset: Offset(0, (exiting ? -1 : 1) * 18 * remaining),
                child: FadeTransition(opacity: animation, child: animatedChild),
              );
            },
          );
        },
        child: SizedBox(
          key: ValueKey(
            '$index|${visibleLines.map((line) => line.text).join('|')}',
          ),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: textAlign == TextAlign.left
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var visibleIndex = 0;
                visibleIndex < visibleLines.length;
                visibleIndex++
              ) ...[
                if (visibleIndex > 0) SizedBox(height: compact ? 5 : 7),
                Builder(
                  builder: (context) {
                    final line = visibleLines[visibleIndex];
                    final active = line.index == index || line.index < 0;
                    return Text(
                      line.text,
                      textAlign: textAlign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: active
                          ? theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              height: 1.22,
                            )
                          : (compact
                                    ? theme.textTheme.bodyMedium
                                    : theme.textTheme.bodyLarge)
                                ?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.62),
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppleFocusLyrics extends StatefulWidget {
  const _AppleFocusLyrics({
    required this.lines,
    required this.currentTimeSeconds,
    required this.loading,
    required this.compact,
    this.textAlign = TextAlign.left,
    this.fontScale = 1,
    this.visibleLineCount = 2,
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final bool loading;
  final bool compact;
  final TextAlign textAlign;
  final double fontScale;
  final int visibleLineCount;

  @override
  State<_AppleFocusLyrics> createState() => _AppleFocusLyricsState();
}

class _AppleFocusLyricsState extends State<_AppleFocusLyrics>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _fromPosition;
  late double _targetPosition;
  String _signature = '';

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _fromPosition = _targetPosition;
          }
        });
    _signature = _lineSignature(widget.lines);
    final activeIndex = _activeLyricsPlayerLine(
      widget.lines,
      widget.currentTimeSeconds,
    ).toDouble();
    _fromPosition = activeIndex;
    _targetPosition = activeIndex;
  }

  @override
  void didUpdateWidget(covariant _AppleFocusLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _lineSignature(widget.lines);
    final nextIndex = _activeLyricsPlayerLine(
      widget.lines,
      widget.currentTimeSeconds,
    );
    if (signature != _signature) {
      _signature = signature;
      _fromPosition = nextIndex.toDouble();
      _targetPosition = _fromPosition;
      _controller.value = 1;
      return;
    }
    if (nextIndex.toDouble() == _targetPosition) return;
    _fromPosition = _animatedPosition;
    _targetPosition = nextIndex.toDouble();
    _controller.forward(from: 0);
  }

  double get _animatedPosition => ui.lerpDouble(
    _fromPosition,
    _targetPosition,
    Curves.easeOutCubic.transform(_controller.value),
  )!;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _lineSignature(List<LyricLine> lines) {
    if (lines.isEmpty) return 'empty';
    return '${lines.length}|${lines.first.time}|${lines.last.time}|${lines.first.text}|${lines.last.text}';
  }

  String _textAt(int index) {
    if (index >= 0 && index < widget.lines.length) {
      final text = widget.lines[index].text.trim();
      if (text.isNotEmpty) return text;
    }
    if (widget.loading) return '正在加载歌词';
    return '用音乐安放此刻';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowGap = widget.compact ? 32.0 : 40.0;
    final visibleLineCount = widget.visibleLineCount.clamp(1, 5);
    final height = rowGap * visibleLineCount + 2;
    final baseSize =
        (theme.textTheme.titleMedium?.fontSize ?? 16) * widget.fontScale;
    final alignment = widget.textAlign == TextAlign.center
        ? Alignment.topCenter
        : widget.textAlign == TextAlign.right
        ? Alignment.topRight
        : Alignment.topLeft;

    Widget lineLayer({
      required int index,
      required double offsetY,
      required double emphasis,
      required double opacity,
    }) {
      final color = Color.lerp(
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
        theme.colorScheme.primary,
        emphasis,
      );
      return Positioned.fill(
        child: Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: ui.lerpDouble(0.92, 1.06, emphasis)!,
                alignment: alignment,
                child: Text(
                  _textAt(index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: widget.textAlign,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: baseSize,
                    height: 1.18,
                    color: color,
                    fontWeight: FontWeight.lerp(
                      FontWeight.w600,
                      FontWeight.w900,
                      emphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRect(
        child: widget.lines.isEmpty
            ? Stack(
                children: [
                  lineLayer(index: -1, offsetY: 0, emphasis: 1, opacity: 1),
                ],
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final position = _animatedPosition.clamp(
                    0.0,
                    max(0, widget.lines.length - 1).toDouble(),
                  );
                  final startIndex = max(0, position.floor() - 1);
                  final endIndex = min(
                    widget.lines.length - 1,
                    position.ceil() + visibleLineCount,
                  );
                  return Stack(
                    children: [
                      for (var index = startIndex; index <= endIndex; index++)
                        lineLayer(
                          index: index,
                          offsetY: (index - position) * rowGap,
                          emphasis: (1 - (index - position).abs()).clamp(
                            0.0,
                            1.0,
                          ),
                          opacity: (index - position).abs() < 1
                              ? ui.lerpDouble(
                                  1,
                                  0.52,
                                  (index - position).abs(),
                                )!
                              : max(
                                  0.18,
                                  0.52 - ((index - position).abs() - 1) * 0.11,
                                ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _VinylScrollingLyrics extends StatelessWidget {
  const _VinylScrollingLyrics({
    required this.lines,
    required this.currentTimeSeconds,
    required this.loading,
    required this.height,
    required this.alignmentIndex,
    required this.onAlignmentChanged,
    this.topFadeLift = 0,
    this.bottomFadeGap = 0,
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final bool loading;
  final double height;
  final int alignmentIndex;
  final ValueChanged<int> onAlignmentChanged;
  final double topFadeLift;
  final double bottomFadeGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeHeight = max(1.0, height);
    final topFadeStop = (0.14 - topFadeLift / safeHeight)
        .clamp(0.02, 0.14)
        .toDouble();
    final bottomFadeGapFraction = (bottomFadeGap / safeHeight)
        .clamp(0.0, 0.08)
        .toDouble();
    final bottomFadeStart = (0.86 - bottomFadeGapFraction)
        .clamp(topFadeStop + 0.02, 0.96)
        .toDouble();
    final bottomFadeEnd = (1 - bottomFadeGapFraction)
        .clamp(bottomFadeStart + 0.02, 1.0)
        .toDouble();
    final alignment = _textAlignmentForIndex(alignmentIndex);
    final textAlign = _textAlignForIndex(alignmentIndex);
    if (loading || lines.isEmpty) {
      return _AlignmentSwipeRegion(
        alignmentIndex: alignmentIndex,
        onAlignmentChanged: onAlignmentChanged,
        child: SizedBox(
          height: safeHeight,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _vinylTextHorizontalInset,
            ),
            child: AnimatedAlign(
              alignment: alignment,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: Text(
                loading ? '正在加载歌词' : '用音乐安放此刻',
                textAlign: textAlign,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _AlignmentSwipeRegion(
      alignmentIndex: alignmentIndex,
      onAlignmentChanged: onAlignmentChanged,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, topFadeStop, bottomFadeStart, bottomFadeEnd],
        ).createShader(bounds),
        child: ClipRect(
          child: ScrollingLyrics(
            lines: lines,
            currentTimeSeconds: currentTimeSeconds,
            height: safeHeight,
            focusAlignment: 0.5,
            textAlign: textAlign,
            horizontalPadding: _vinylTextHorizontalInset,
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlayerProgress extends StatelessWidget {
  const _ExpandedPlayerProgress({required this.model, required this.player});

  final AppModel model;
  final PlayerSnapshot player;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        PlayerSeekBar(model: model, player: player),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                _formatSeconds(player.currentTimeSeconds.floor()),
                style: style,
              ),
              const Spacer(),
              Text(
                player.durationSeconds > 0
                    ? _formatSeconds(player.durationSeconds)
                    : '--:--',
                style: style,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedPlayerControls extends StatelessWidget {
  const _ExpandedPlayerControls({
    required this.model,
    required this.player,
    this.compact = false,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playExtent = compact ? 52.0 : 60.0;
    final sideExtent = compact ? 38.0 : 40.0;
    final sideIconSize = compact ? 22.0 : 24.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: '收藏',
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => _openFavoriteSheet(context, model),
          icon: Icon(Icons.favorite_border, size: sideIconSize),
        ),
        IconButton(
          tooltip: _modeLabel(player.mode),
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => model.playerControl('mode'),
          icon: Icon(_modeIcon(player.mode), size: sideIconSize),
        ),
        IconButton(
          tooltip: '上一首',
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => model.playerControl('previous'),
          icon: Icon(Icons.skip_previous, size: compact ? 28 : 32),
        ),
        SizedBox.square(
          dimension: playExtent,
          child: IconButton.filled(
            tooltip: player.playing ? '暂停' : '播放',
            onPressed: () => model.playerControl('toggle'),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                player.playing ? Icons.pause : Icons.play_arrow,
                key: ValueKey(player.playing),
                size: compact ? 30 : 36,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '下一首',
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => model.playerControl('next'),
          icon: Icon(Icons.skip_next, size: compact ? 28 : 32),
        ),
        IconButton(
          tooltip: '播放列表',
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => _openQueueSheet(context, model),
          icon: Icon(Icons.queue_music, size: sideIconSize),
        ),
        IconButton(
          tooltip: '音量',
          constraints: BoxConstraints.tightFor(
            width: sideExtent,
            height: sideExtent,
          ),
          padding: EdgeInsets.zero,
          onPressed: () => _openVolumeSheet(context, model),
          icon: Icon(Icons.volume_up_outlined, size: sideIconSize),
        ),
      ],
    );
  }
}

class _LyricsPageTransition extends StatelessWidget {
  const _LyricsPageTransition({
    required this.controller,
    required this.pageIndex,
    required this.child,
  });

  final PageController controller;
  final int pageIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var page = controller.initialPage.toDouble();
        if (controller.hasClients && controller.position.hasContentDimensions) {
          page = controller.page ?? page;
        }
        final distance = (page - pageIndex).abs().clamp(0.0, 1.0).toDouble();
        final easedDistance = Curves.easeOutCubic.transform(distance);
        final scale = 1.0 - easedDistance * 0.008;
        final opacity = 1.0 - easedDistance * 0.08;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: pageIndex % 3 == 0
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _LyricsPageIndicator extends StatelessWidget {
  const _LyricsPageIndicator({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pageName = switch (index) {
      0 => '歌词页',
      1 => '黑胶播放器页',
      _ => '封面播放器页',
    };
    return Semantics(
      label: '$pageName，第 ${index + 1} 页，共 3 页',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (dotIndex) {
          final selected = index == dotIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: selected ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primary
                  : colors.onSurfaceVariant.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

int _activeLyricsPlayerLine(List<LyricLine> lines, double currentTimeSeconds) {
  if (lines.isEmpty) return -1;
  var active = 0;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].time <= currentTimeSeconds + 0.12) {
      active = index;
    } else {
      break;
    }
  }
  return active;
}
