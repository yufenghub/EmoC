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
      if (candidate.startsWith('file:')) return candidate;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('apple-player-background'),
      color: Colors.transparent,
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
                    transitionDirection: model.artworkTransitionDirectionFor(
                      song,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _AppleTrackInformation(
                  model: model,
                  player: player,
                  song: song,
                  lyrics: lyrics,
                  lyricsLoading: lyricsLoading,
                  centered: false,
                  lyricFontScale: _responsiveLyricsFontScale(
                    MediaQuery.sizeOf(context),
                    base: 1.06,
                  ),
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
        final columnGap = isTablet ? 22.0 : 26.0;
        final artworkSize = min(
          (constraints.maxWidth - horizontalPadding * 2 - columnGap) * 9 / 20,
          contentHeight,
        ).clamp(80.0, isTablet ? 560.0 : 460.0).toDouble();
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final panelHeight = max(
          artworkSize,
          min(contentHeight, 176 * textScale),
        );
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
                    transitionDirection: model.artworkTransitionDirectionFor(
                      song,
                    ),
                  ),
                ),
              ),
              SizedBox(width: columnGap),
              Expanded(
                flex: 11,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: panelHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AppleTrackInformation(
                            model: model,
                            player: player,
                            song: song,
                            lyrics: lyrics,
                            lyricsLoading: lyricsLoading,
                            centered: false,
                            lyricFontScale: _responsiveLyricsFontScale(
                              MediaQuery.sizeOf(context),
                              base: 1.18,
                            ),
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
    required this.transitionDirection,
  });

  final double size;
  final String coverUrl;
  final String songIdentity;
  final bool showCover;
  final bool playing;
  final int transitionDirection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = min(
          size,
          min(constraints.maxWidth, constraints.maxHeight),
        );
        return SizedBox.square(
          key: const ValueKey('apple-artwork-square'),
          dimension: extent,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: playing ? 1 : 0.965,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: playing ? 0.2 : 0.13,
                        ),
                        blurRadius: playing ? 28 : 20,
                        offset: Offset(0, playing ? 14 : 9),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _SlidingCoverSwitcher(
                    identityKey: songIdentity,
                    transitionKey: '$songIdentity|$coverUrl|$showCover',
                    coverUrl: coverUrl,
                    showCover: showCover,
                    direction: transitionDirection,
                    preferredSize: 800,
                    decodeSize: 512,
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
                            child: Icon(
                              Icons.album_outlined,
                              size: size * 0.28,
                            ),
                          ),
                  ),
                ),
              ),
              IgnorePointer(
                child: SizedBox.expand(
                  key: ValueKey('apple-artwork-$songIdentity'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppleTrackInformation extends StatelessWidget {
  const _AppleTrackInformation({
    required this.model,
    required this.player,
    required this.song,
    required this.lyrics,
    required this.lyricsLoading,
    required this.centered,
    this.lyricFontScale = 1,
  });

  final AppModel model;
  final PlayerSnapshot player;
  final MirrorItem song;
  final List<LyricLine> lyrics;
  final bool lyricsLoading;
  final bool centered;
  final double lyricFontScale;

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
                  fontScale: lyricFontScale * model.playerLyricsFontScale,
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
  Widget build(BuildContext context) => Column(
    key: ValueKey(
      compact ? 'apple-playback-panel-compact' : 'apple-playback-panel-full',
    ),
    mainAxisSize: MainAxisSize.min,
    children: [
      _ExpandedPlayerProgress(model: model, player: player),
      const SizedBox(height: 6),
      PlayerToolRow(model: model, player: player, centerTransport: true),
    ],
  );
}
