part of '../main.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    required this.model,
    this.canOpenSongDetail = true,
    super.key,
  });

  final AppModel model;
  final bool canOpenSongDetail;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([model, model.playbackRevision]),
      builder: (context, _) =>
          _PlayerBarContent(model: model, canOpenSongDetail: canOpenSongDetail),
    );
  }
}

class _PlayerBarContent extends StatelessWidget {
  const _PlayerBarContent({
    required this.model,
    required this.canOpenSongDetail,
  });

  final AppModel model;
  final bool canOpenSongDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = model.displayPlayer;
    final song = player.asMirrorItem();
    final coverUrl = [
      player.coverUrl,
      model.coverFor(song),
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    if (model.showSongCovers &&
        !coverUrl.startsWith('http') &&
        song.id.isNotEmpty) {
      unawaited(model.ensureSongCover(song));
    }
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: canOpenSongDetail
                    ? () => _openSongDetailPage(context, model, song)
                    : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: model.showSongCovers
                      ? CoverImage(
                          key: const ValueKey('player-cover'),
                          url: coverUrl,
                          identity: player.songId.isNotEmpty
                              ? player.songId
                              : '${player.title}|${player.displayArtist}',
                          fallbackIcon: player.playing
                              ? Icons.graphic_eq
                              : Icons.music_note,
                          onAllCandidatesFailed: () => unawaited(
                            model.ensureSongCover(song, force: true),
                          ),
                        )
                      : Icon(
                          player.playing ? Icons.graphic_eq : Icons.music_note,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    PlayerSeekBar(model: model, player: player),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                player.progressText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final extent = (constraints.maxWidth / 8)
                  .clamp(36.0, 48.0)
                  .toDouble();
              final compactStyle = IconButton.styleFrom(
                minimumSize: Size.square(extent),
                maximumSize: Size.square(extent),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    style: compactStyle,
                    tooltip: '上一首',
                    onPressed: () => model.playerControl('previous'),
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton.filledTonal(
                    style: compactStyle,
                    tooltip: model.player.playing ? '暂停' : '播放',
                    onPressed: () => model.playerControl('toggle'),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        player.playing ? Icons.pause : Icons.play_arrow,
                        key: ValueKey(player.playing),
                      ),
                    ),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: '下一首',
                    onPressed: () => model.playerControl('next'),
                    icon: const Icon(Icons.skip_next),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: '歌词',
                    onPressed: canOpenSongDetail
                        ? () => _openSongDetailPage(context, model, song)
                        : null,
                    icon: const Icon(Icons.lyrics),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: '收藏',
                    onPressed: () => _openFavoriteSheet(context, model),
                    icon: const Icon(Icons.favorite_border),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: '音量',
                    onPressed: () => _openVolumeSheet(context, model),
                    icon: const Icon(Icons.volume_up),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: _modeLabel(player.mode),
                    onPressed: () => model.playerControl('mode'),
                    icon: Icon(_modeIcon(player.mode)),
                  ),
                  IconButton(
                    style: compactStyle,
                    tooltip: '播放列表',
                    onPressed: () => _openQueueSheet(context, model),
                    icon: const Icon(Icons.queue_music),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({required this.model, required this.player, super.key});

  final AppModel model;
  final PlayerSnapshot player;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.player.durationSeconds > 0;
    final value = (_dragValue ?? widget.player.progress).clamp(0, 1).toDouble();
    return SizedBox(
      height: 18,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          inactiveTrackColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.18,
          ),
        ),
        child: Slider(
          value: value,
          onChanged: enabled
              ? (next) {
                  setState(() => _dragValue = next);
                }
              : null,
          onChangeEnd: enabled
              ? (next) {
                  setState(() => _dragValue = null);
                  unawaited(widget.model.seekPlayerTo(next));
                }
              : null,
        ),
      ),
    );
  }
}

void _openSongDetailPage(
  BuildContext context,
  AppModel model,
  MirrorItem song,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SongDetailPage(model: model, song: song),
    ),
  );
}

void _openVolumeSheet(BuildContext context, AppModel model) {
  var value = model.player.volume;
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '音量',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_down),
                      Expanded(
                        child: Slider(
                          value: value,
                          onChanged: (next) {
                            setState(() => value = next);
                            unawaited(model.setPlayerVolume(next));
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _openFavoriteSheet(BuildContext context, AppModel model) {
  final playlists = model.libraryPlaylists
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
  if (playlists.isEmpty) {
    unawaited(model.likeCurrentSong());
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) {
      final theme = Theme.of(context);
      final sheetColor = theme.scaffoldBackgroundColor;
      final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
      final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 10;
      const horizontalPadding = 18.0;
      const topPadding = 14.0;
      const headerHeight = 48.0;
      const headerGap = 8.0;
      const tileHeight = 64.0;
      const tileGap = 8.0;
      final listContentHeight =
          playlists.length * tileHeight +
          (playlists.length - 1).clamp(0, playlists.length) * tileGap +
          8;
      final maxListHeight =
          (maxHeight - topPadding - headerHeight - headerGap - bottomPadding)
              .clamp(tileHeight, maxHeight)
              .toDouble();
      final listHeight = listContentHeight
          .clamp(tileHeight, maxListHeight)
          .toDouble();
      final sheetHeight =
          topPadding + headerHeight + headerGap + listHeight + bottomPadding;
      return SizedBox(
        height: sheetHeight,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: sheetColor,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '收藏到歌单',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: headerGap),
                  SizedBox(
                    height: listHeight,
                    child: ClipRect(
                      clipBehavior: Clip.hardEdge,
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: ListView.separated(
                          primary: false,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: playlists.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: tileGap),
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return SizedBox(
                              height: tileHeight,
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                tileColor: theme.cardTheme.color,
                                leading: Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    playlist.kind == 'liked'
                                        ? Icons.favorite
                                        : Icons.queue_music,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                title: Text(
                                  playlist.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  playlist.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  unawaited(
                                    model.addCurrentSongToPlaylist(playlist),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _openQueueSheet(BuildContext context, AppModel model) {
  unawaited(model.loadPlayerQueue());
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => PlayerQueueSheet(model: model),
  );
}

IconData _modeIcon(String mode) {
  if (mode == 'shuffle') return Icons.shuffle;
  if (mode == 'one') return Icons.repeat_one;
  return Icons.repeat;
}

String _modeLabel(String mode) {
  if (mode == 'shuffle') return '随机播放';
  if (mode == 'one') return '单曲循环';
  return '循环播放';
}
