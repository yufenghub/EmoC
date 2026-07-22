part of '../main.dart';

class AppleMusicPlayerView extends StatefulWidget {
  const AppleMusicPlayerView({
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
  State<AppleMusicPlayerView> createState() => _AppleMusicPlayerViewState();
}

class _AppleMusicPlayerViewState extends State<AppleMusicPlayerView> {
  String _artworkRequestKey = '';

  @override
  void initState() {
    super.initState();
    _prepareArtwork();
  }

  @override
  void didUpdateWidget(covariant AppleMusicPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.player.songId != widget.player.songId) {
      _prepareArtwork();
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
      key: const ValueKey('apple-player-background'),
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight * 1.18;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: landscape
                ? _AppleLandscapePlayer(
                    key: const ValueKey('apple-landscape-player'),
                    model: widget.model,
                    player: widget.player,
                    song: widget.song,
                    lyrics: widget.lyrics,
                    lyricsLoading: widget.lyricsLoading,
                    coverUrl: _coverUrl,
                  )
                : _ApplePortraitPlayer(
                    key: const ValueKey('apple-portrait-player'),
                    model: widget.model,
                    player: widget.player,
                    song: widget.song,
                    lyrics: widget.lyrics,
                    lyricsLoading: widget.lyricsLoading,
                    coverUrl: _coverUrl,
                  ),
          );
        },
      ),
    );
  }
}

class _ApplePortraitPlayer extends StatelessWidget {
  const _ApplePortraitPlayer({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.coverUrl,
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
        final horizontalPadding = isTablet
            ? max(28.0, (constraints.maxWidth - 760) / 2)
            : 22.0;
        final contentWidth = constraints.maxWidth - horizontalPadding * 2;
        final preferredArtwork = min(
          contentWidth,
          max(170.0, constraints.maxHeight * (isTablet ? 0.44 : 0.43)),
        );
        final maxArtworkByHeight = max(
          170.0,
          constraints.maxHeight - (isTablet ? 350 : 320),
        );
        final artworkSize = min(
          preferredArtwork * (isTablet ? 1.02 : 1.06),
          min(maxArtworkByHeight, isTablet ? 520.0 : 460.0),
        ).clamp(170.0, contentWidth).toDouble();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isTablet ? 4 : 2,
            horizontalPadding,
            isTablet ? 12 : 10,
          ),
          child: Column(
            children: [
              SizedBox(
                height: artworkSize,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _AppleArtwork(
                    size: artworkSize,
                    coverUrl: coverUrl,
                    songIdentity: song.id,
                    showCover: model.showSongCovers,
                    playing: player.playing,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, infoConstraints) {
                    final lyricFontScale = isTablet ? 1.42 : 1.06;
                    final baseFontSize =
                        Theme.of(context).textTheme.titleMedium?.fontSize ?? 16;
                    final rowExtent = max(
                      32.0,
                      baseFontSize * lyricFontScale * 1.62,
                    );
                    final lyricLineCount =
                        ((infoConstraints.maxHeight - 52) / rowExtent)
                            .floor()
                            .clamp(1, isTablet ? 16 : 9)
                            .toInt();
                    return _AppleTrackInformation(
                      player: player,
                      song: song,
                      lyrics: lyrics,
                      lyricsLoading: lyricsLoading,
                      centered: false,
                      lyricFontScale: lyricFontScale,
                      lyricLineCount: lyricLineCount,
                    );
                  },
                ),
              ),
              const SizedBox(height: 5),
              _ApplePlaybackPanel(model: model, player: player),
            ],
          ),
        );
      },
    );
  }
}

class _AppleLandscapePlayer extends StatelessWidget {
  const _AppleLandscapePlayer({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.coverUrl,
    super.key,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
        final horizontalPadding = isTablet
            ? max(20.0, constraints.maxWidth * 0.025)
            : 34.0;
        final verticalPadding = isTablet ? 14.0 : 10.0;
        final contentHeight = max(
          140.0,
          constraints.maxHeight - verticalPadding * 2,
        );
        final artworkSize = min(
          constraints.maxWidth * (isTablet ? 0.40 : 0.43),
          contentHeight,
        ).clamp(140.0, isTablet ? 560.0 : 460.0).toDouble();
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 9,
                child: Center(
                  child: _AppleArtwork(
                    size: artworkSize,
                    coverUrl: coverUrl,
                    songIdentity: song.id,
                    showCover: model.showSongCovers,
                    playing: player.playing,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 22 : 26),
              Expanded(
                flex: 11,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: artworkSize,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, infoConstraints) {
                              final lyricFontScale = isTablet ? 1.40 : 1.18;
                              final baseFontSize =
                                  Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.fontSize ??
                                  16;
                              final rowExtent = max(
                                32.0,
                                baseFontSize * lyricFontScale * 1.62,
                              );
                              final lyricLineCount =
                                  ((infoConstraints.maxHeight - 50) / rowExtent)
                                      .floor()
                                      .clamp(1, isTablet ? 16 : 10)
                                      .toInt();
                              return _AppleTrackInformation(
                                player: player,
                                song: song,
                                lyrics: lyrics,
                                lyricsLoading: lyricsLoading,
                                centered: false,
                                lyricFontScale: lyricFontScale,
                                lyricLineCount: lyricLineCount,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ApplePlaybackPanel(
                          model: model,
                          player: player,
                          compact: true,
                        ),
                      ],
                    ),
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

class _AppleArtwork extends StatelessWidget {
  const _AppleArtwork({
    required this.size,
    required this.coverUrl,
    required this.songIdentity,
    required this.showCover,
    required this.playing,
  });

  final double size;
  final String coverUrl;
  final String songIdentity;
  final bool showCover;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedScale(
      key: ValueKey('apple-artwork-$songIdentity'),
      scale: playing ? 1 : 0.965,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: playing ? 0.2 : 0.13),
              blurRadius: playing ? 28 : 20,
              offset: Offset(0, playing ? 14 : 9),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                  color: colors.surfaceContainerHighest,
                  child: Icon(Icons.album_outlined, size: size * 0.28),
                ),
        ),
      ),
    );
  }
}

class _AppleTrackInformation extends StatelessWidget {
  const _AppleTrackInformation({
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.centered,
    this.lyricFontScale = 1,
    this.lyricLineCount = 2,
  });

  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final bool centered;
  final double lyricFontScale;
  final int lyricLineCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.left;
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: alignment,
            children: [
              Text(
                song.title,
                maxLines: constraints.maxHeight < 150 ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                song.subtitle.isEmpty ? player.displayArtist : song.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _AppleFocusLyrics(
                  lines: lyrics,
                  currentTimeSeconds: player.currentTimeSeconds,
                  loading: lyricsLoading,
                  compact: true,
                  textAlign: textAlign,
                  fontScale: lyricFontScale,
                  visibleLineCount: lyricLineCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ApplePlaybackPanel extends StatelessWidget {
  const _ApplePlaybackPanel({
    required this.model,
    required this.player,
    this.compact = false,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(
        compact ? 'apple-playback-panel-compact' : 'apple-playback-panel-full',
      ),
      mainAxisSize: MainAxisSize.min,
      children: [
        _ExpandedPlayerProgress(model: model, player: player),
        SizedBox(height: compact ? 4 : 10),
        _AppleTransportControls(model: model, player: player),
        SizedBox(height: compact ? 4 : 10),
        if (!compact) ...[
          Row(
            children: [
              const Icon(Icons.volume_down, size: 20),
              Expanded(
                child: Slider(
                  value: player.volume.clamp(0.0, 1.0),
                  onChanged: (value) => unawaited(model.setPlayerVolume(value)),
                ),
              ),
              const Icon(Icons.volume_up, size: 20),
            ],
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: '收藏',
              onPressed: () => _openFavoriteSheet(context, model),
              icon: const Icon(Icons.favorite_border),
            ),
            IconButton(
              tooltip: _modeLabel(player.mode),
              onPressed: () => model.playerControl('mode'),
              icon: Icon(_modeIcon(player.mode)),
            ),
            IconButton(
              tooltip: '播放列表',
              onPressed: () => _openQueueSheet(context, model),
              icon: const Icon(Icons.queue_music),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppleTransportControls extends StatelessWidget {
  const _AppleTransportControls({required this.model, required this.player});

  final AppModel model;
  final PlayerSnapshot player;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: '上一首',
          iconSize: 34,
          onPressed: () => model.playerControl('previous'),
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          tooltip: player.playing ? '暂停' : '播放',
          style: IconButton.styleFrom(
            minimumSize: const Size.square(68),
            maximumSize: const Size.square(68),
            backgroundColor: colors.onSurface,
            foregroundColor: colors.surface,
          ),
          onPressed: () => model.playerControl('toggle'),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(player.playing),
              size: 40,
            ),
          ),
        ),
        IconButton(
          tooltip: '下一首',
          iconSize: 34,
          onPressed: () => model.playerControl('next'),
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
