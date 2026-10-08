part of '../main.dart';

const _appleLyricsMotionDuration = Duration(milliseconds: 420);
const _appleLyricsMotionCurve = Curves.easeOutCubic;

double _responsiveLyricsFontScale(Size screen, {double base = 1}) =>
    (base * screen.shortestSide / 390).clamp(0.84, 1.42).toDouble();

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

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 22500),
    );
    _prepareArtwork();
  }

  @override
  void didUpdateWidget(covariant LyricsPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRotation();
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
    final duration = Duration(
      milliseconds: (22500 / widget.model.animationSpeed).round(),
    );
    final speedChanged = _rotationController.duration != duration;
    _rotationController.duration = duration;
    if (widget.player.playing &&
        widget.model.motionLevel > 0 &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_rotationController.isAnimating || speedChanged) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop(canceled: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRotation();
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

  String get _coverUrl {
    for (final candidate in [
      widget.player.coverUrl,
      widget.song.imageUrl,
      widget.model.coverFor(widget.song),
    ]) {
      if (candidate.startsWith('http')) {
        return _highResolutionArtworkUrl(candidate);
      }
      if (candidate.startsWith('file:')) return candidate;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('lyrics-player-background'),
      color: Colors.transparent,
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
                  ),
          );
        },
      ),
    );
  }
}

const _vinylTextHorizontalInset = 22.0;

class _VinylSongInfo extends StatelessWidget {
  const _VinylSongInfo({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _vinylTextHorizontalInset,
      ),
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              if (AppScope.maybeOf(
                    context,
                  )?.regionTextVisible('lyrics.artist') ??
                  true)
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
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
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;
  final Animation<double> rotation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final deckSize = min(
        constraints.maxWidth - 24,
        constraints.maxHeight * 0.44,
      ).clamp(80.0, 440.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          children: [
            _RecordDeck(
              size: deckSize,
              coverUrl: coverUrl,
              songIdentity: song.id,
              showCover: model.showSongCovers,
              rotation: rotation,
              transitionDirection: model.artworkTransitionDirectionFor(song),
            ),
            _VinylSongInfo(
              title: song.title,
              subtitle: song.subtitle.isEmpty
                  ? player.displayArtist
                  : song.subtitle,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, lyricConstraints) => _VinylScrollingLyrics(
                  model: model,
                  lines: lyrics,
                  currentTimeSeconds: player.currentTimeSeconds,
                  loading: lyricsLoading,
                  height: lyricConstraints.maxHeight,
                ),
              ),
            ),
            _ExpandedPlayerProgress(model: model, player: player),
            const SizedBox(height: 6),
            KeyedSubtree(
              key: const ValueKey('vinyl-player-controls'),
              child: _ExpandedPlayerControls(model: model, player: player),
            ),
          ],
        ),
      );
    },
  );
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
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;
  final Animation<double> rotation;

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
                    transitionDirection: model.artworkTransitionDirectionFor(
                      song,
                    ),
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
                      _VinylSongInfo(
                        title: song.title,
                        subtitle: song.subtitle.isEmpty
                            ? player.displayArtist
                            : song.subtitle,
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, lyricConstraints) {
                            return _VinylScrollingLyrics(
                              model: model,
                              lines: lyrics,
                              currentTimeSeconds: player.currentTimeSeconds,
                              loading: lyricsLoading,
                              height: lyricConstraints.maxHeight,
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
    required this.transitionDirection,
  });

  final double size;
  final String coverUrl;
  final String songIdentity;
  final bool showCover;
  final Animation<double> rotation;
  final int transitionDirection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = min(
          size,
          min(constraints.maxWidth, constraints.maxHeight),
        );
        final coverSize = extent * 0.819;
        return SizedBox.square(
          dimension: extent,
          child: Center(
            child: SizedBox.square(
              dimension: coverSize,
              child: RepaintBoundary(
                child: ClipOval(
                  key: const ValueKey('vinyl-cover-clip'),
                  child: _SlidingCoverSwitcher(
                    identityKey: songIdentity,
                    transitionKey: '$songIdentity|$coverUrl|$showCover',
                    coverUrl: coverUrl,
                    showCover: showCover,
                    direction: transitionDirection,
                    preferredSize: 800,
                    decodeSize: 512,
                    child: KeyedSubtree(
                      key: ValueKey('vinyl-record-$songIdentity'),
                      child: RotationTransition(
                        turns: rotation,
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
          ),
        );
      },
    );
  }
}

class _SlidingCoverSwitcher extends StatefulWidget {
  const _SlidingCoverSwitcher({
    required this.identityKey,
    required this.transitionKey,
    required this.coverUrl,
    required this.showCover,
    required this.direction,
    required this.child,
    this.preferredSize = 800,
    this.decodeSize = 512,
  });

  final String identityKey;
  final String transitionKey;
  final String coverUrl;
  final bool showCover;
  final int direction;
  final Widget child;
  final int preferredSize;
  final int decodeSize;

  @override
  State<_SlidingCoverSwitcher> createState() => _SlidingCoverSwitcherState();
}

class _PreparedCoverTransition {
  const _PreparedCoverTransition({
    required this.identityKey,
    required this.direction,
    required this.child,
  });

  final String identityKey;
  final double direction;
  final Widget child;
}

class _SlidingCoverSwitcherState extends State<_SlidingCoverSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _motion;
  late Widget _currentChild;
  late String _currentIdentityKey;
  _PreparedCoverTransition? _incoming;
  _PreparedCoverTransition? _queued;
  int _prepareGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentIdentityKey = widget.identityKey;
    _currentChild = _keyedChild(widget.transitionKey, widget.child);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addStatusListener(_handleAnimationStatus);
    _motion = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.12, 0.82, 0.16, 1),
    );
  }

  @override
  void didUpdateWidget(covariant _SlidingCoverSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey == widget.transitionKey) {
      if (_incoming == null) {
        _currentChild = _keyedChild(widget.transitionKey, widget.child);
      }
      return;
    }
    _scheduleTransition();
  }

  @override
  void dispose() {
    _prepareGeneration += 1;
    _controller.dispose();
    super.dispose();
  }

  Widget _keyedChild(String key, Widget child) {
    return KeyedSubtree(key: ValueKey('sliding-cover-$key'), child: child);
  }

  String _normalizedCoverUrl(String value) {
    return _absoluteMusicUrl(value).trim();
  }

  void _scheduleTransition() {
    final generation = ++_prepareGeneration;
    final identityKey = widget.identityKey;
    final transitionKey = widget.transitionKey;
    final coverUrl = _normalizedCoverUrl(widget.coverUrl);
    final direction = widget.direction < 0 ? -1.0 : 1.0;
    final child = _keyedChild(transitionKey, widget.child);
    unawaited(
      _prepareTransition(
        generation: generation,
        identityKey: identityKey,
        transitionKey: transitionKey,
        coverUrl: coverUrl,
        direction: direction,
        child: child,
      ),
    );
  }

  Future<void> _prepareTransition({
    required int generation,
    required String identityKey,
    required String transitionKey,
    required String coverUrl,
    required double direction,
    required Widget child,
  }) async {
    if (widget.showCover) {
      final ready = await _preloadCover(coverUrl);
      if (!ready) return;
    }
    if (!mounted || generation != _prepareGeneration) return;
    final prepared = _PreparedCoverTransition(
      identityKey: identityKey,
      direction: direction,
      child: child,
    );

    if (_incoming?.identityKey == identityKey) {
      setState(() => _incoming = prepared);
      return;
    }
    if (_queued?.identityKey == identityKey) {
      _queued = prepared;
      return;
    }
    if (_currentIdentityKey == identityKey && _incoming == null) {
      setState(() {
        _currentChild = child;
      });
      return;
    }
    if (_controller.isAnimating || _incoming != null) {
      _queued = prepared;
      return;
    }
    _beginTransition(prepared);
  }

  Future<bool> _preloadCover(String coverUrl) async {
    final candidates = _coverImageCandidates(
      coverUrl,
      preferredSize: widget.preferredSize,
    );
    if (candidates.isEmpty) return false;
    try {
      final entry = await CoverRuntimeCache.instance
          .load(candidates)
          .timeout(const Duration(seconds: 8));
      if (entry == null || !mounted) return false;
      final provider = ResizeImage.resizeIfNeeded(
        widget.decodeSize,
        widget.decodeSize,
        MemoryImage(entry.bytes),
      );
      await precacheImage(
        provider,
        context,
      ).timeout(const Duration(seconds: 4));
      return mounted;
    } catch (_) {
      return false;
    }
  }

  void _beginTransition(_PreparedCoverTransition transition) {
    if (!mounted) return;
    setState(() => _incoming = transition);
    _controller.forward(from: 0);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final completed = _incoming;
    if (completed == null) return;
    final next = _queued;
    _queued = null;
    setState(() {
      _currentIdentityKey = completed.identityKey;
      _currentChild = completed.child;
      _incoming = null;
    });
    _controller.reset();
    if (next != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beginTransition(next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final incoming = _incoming;
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: _currentChild),
              if (incoming != null)
                FractionalTranslation(
                  translation: Offset(
                    incoming.direction * (1 - _motion.value),
                    0,
                  ),
                  child: RepaintBoundary(child: incoming.child),
                ),
            ],
          );
        },
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
  });

  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final bool loading;
  final bool compact;
  final TextAlign textAlign;
  final double fontScale;

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
          duration: _appleLyricsMotionDuration,
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
    _appleLyricsMotionCurve.transform(_controller.value),
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
    final baseSize =
        (theme.textTheme.titleMedium?.fontSize ?? 16) * widget.fontScale;
    final rowGap = max(
      widget.compact ? 32.0 : 40.0,
      MediaQuery.textScalerOf(context).scale(baseSize) * 1.18 * 1.06 + 8,
    );
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
                  key: ValueKey('apple-lyric-$index'),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleLineCount = max(
          1,
          (constraints.maxHeight / rowGap).ceil(),
        );
        return ClipRect(
          key: const ValueKey('apple-lyrics-viewport'),
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
                                    0.52 -
                                        ((index - position).abs() - 1) * 0.11,
                                  ),
                          ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _VinylScrollingLyrics extends StatelessWidget {
  const _VinylScrollingLyrics({
    required this.model,
    required this.lines,
    required this.currentTimeSeconds,
    required this.loading,
    required this.height,
  });

  final AppModel model;
  final List<LyricLine> lines;
  final double currentTimeSeconds;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeHeight = max(1.0, height);
    if (loading || lines.isEmpty) {
      return SizedBox(
        height: safeHeight,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _vinylTextHorizontalInset,
          ),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              loading ? '正在加载歌词' : '用音乐安放此刻',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }
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
        stops: [0, 0.14, 0.86, 1],
      ).createShader(bounds),
      child: ClipRect(
        child: ScrollingLyrics(
          lines: lines,
          currentTimeSeconds: currentTimeSeconds,
          height: safeHeight,
          focusAlignment: 0.25,
          pure: false,
          textAlign: TextAlign.center,
          horizontalPadding: _vinylTextHorizontalInset,
          fontScale: model.playerLyricsFontScale,
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
    if (!model.controlVisible('player.progress')) {
      return const SizedBox.shrink();
    }
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        PlayerSeekBar(model: model, player: player),
        const SizedBox(height: 6),
        if (model.regionTextVisible('lyrics.timing'))
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
  Widget build(BuildContext context) =>
      PlayerToolRow(model: model, player: player, twoRows: true);
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
