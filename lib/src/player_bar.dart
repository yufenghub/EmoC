part of '../main.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    required this.model,
    this.canOpenSongDetail = true,
    this.showMetadata = true,
    super.key,
  });
  final AppModel model;
  final bool canOpenSongDetail;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([model, model.playbackRevision]),
    builder: (context, _) => _PlayerBarContent(
      model: model,
      canOpenSongDetail: canOpenSongDetail,
      showMetadata: showMetadata,
    ),
  );
}

class _PlayerBarContent extends StatelessWidget {
  const _PlayerBarContent({
    required this.model,
    required this.canOpenSongDetail,
    required this.showMetadata,
  });
  final AppModel model;
  final bool canOpenSongDetail;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = model.displayPlayer;
    final song = player.asMirrorItem();
    final coverUrl = [player.coverUrl, model.coverFor(song)].firstWhere(
      (url) => url.startsWith('http') || url.startsWith('file:'),
      orElse: () => '',
    );
    if (model.showSongCovers && coverUrl.isEmpty && song.id.isNotEmpty) {
      unawaited(model.ensureSongCover(song));
    }
    Widget cover(double size) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: CoverImage(
          url: model.showSongCovers ? coverUrl : '',
          identity: player.songId,
          fallbackIcon: Icons.music_note,
        ),
      ),
    );
    if (canOpenSongDetail) {
      final bar = AppCardSurface(
        model: model,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          onTap: () => _openSongDetailPage(context, model, song),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            key: const ValueKey('compact-player-bar'),
            height: model.iconOnlyNavigation ? 48 : 56,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      cover(36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          player.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (model.controlVisible('mini.previous'))
                        IconButton(
                          tooltip: '上一首',
                          onPressed: () => model.playerControl('previous'),
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.skip_previous),
                        ),
                      if (model.controlVisible('mini.play'))
                        IconButton(
                          tooltip: player.playing ? '暂停' : '播放',
                          onPressed: () => model.playerControl('toggle'),
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            player.playing ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                      if (model.controlVisible('mini.next'))
                        IconButton(
                          tooltip: '下一首',
                          onPressed: () => model.playerControl('next'),
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.skip_next),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          key: const ValueKey('mini-progress-glow'),
          foregroundPainter: model.controlVisible('mini.progress')
              ? _ProgressGlowPainter(
                  player.progress,
                  model.progressColor(theme),
                  model.progressGlow,
                )
              : null,
          child: bar,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMetadata)
            Row(
              children: [
                cover(40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        player.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (model.controlVisible('player.progress')) ...[
            const SizedBox(height: 4),
            _ExpandedPlayerProgress(model: model, player: player),
          ],
          PlayerToolRow(model: model, player: player, twoRows: true),
        ],
      ),
    );
  }
}

class _ProgressGlowPainter extends CustomPainter {
  const _ProgressGlowPainter(this.progress, this.color, this.glow);
  final double progress;
  final Color color;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 8.0.clamp(0.0, size.width / 2);
    const inset = 0.0;
    final edge = Path()
      ..moveTo(inset, radius + inset)
      ..quadraticBezierTo(inset, inset, radius + inset, inset)
      ..lineTo(size.width - radius - inset, inset)
      ..quadraticBezierTo(
        size.width - inset,
        inset,
        size.width - inset,
        radius + inset,
      );
    final metric = edge.computeMetrics().first;
    final length = metric.length * progress.clamp(0, 1);
    if (length <= 0) return;
    final lit = metric.extractPath(0, length);
    final endX = metric.getTangentForOffset(length)?.position.dx ?? size.width;
    final fadeFraction = (10 / endX).clamp(0.0, 0.45);
    final fade = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(endX, 0),
        [color.withValues(alpha: 0), color, color, color.withValues(alpha: 0)],
        [0, fadeFraction, 1 - fadeFraction, 1],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (glow > 0) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.drawPath(
        lit,
        Paint()
          ..shader = fade.shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glow),
      );
      canvas.restore();
    }
    canvas.drawPath(lit, fade);
  }

  @override
  bool shouldRepaint(_ProgressGlowPainter old) =>
      old.progress != progress || old.color != color || old.glow != glow;
}

class PlayerToolRow extends StatelessWidget {
  const PlayerToolRow({
    required this.model,
    required this.player,
    this.twoRows = false,
    this.centerTransport = false,
    super.key,
  });
  final AppModel model;
  final PlayerSnapshot player;
  final bool twoRows;
  final bool centerTransport;

  @override
  Widget build(BuildContext context) {
    final local = player.asMirrorItem().isLocal;
    final actions =
        <({String id, String label, IconData icon, VoidCallback? tap})>[
              (
                id: 'favorite',
                label: '收藏',
                icon: Icons.favorite_border,
                tap: local ? null : () => _openFavoriteSheet(context, model),
              ),
              (
                id: 'mode',
                label: _modeLabel(player.mode),
                icon: _modeIcon(player.mode),
                tap: () => model.playerControl('mode'),
              ),
              (
                id: 'previous',
                label: '上一首',
                icon: Icons.skip_previous,
                tap: () => model.playerControl('previous'),
              ),
              (
                id: 'play',
                label: player.playing ? '暂停' : '播放',
                icon: player.playing ? Icons.pause : Icons.play_arrow,
                tap: () => model.playerControl('toggle'),
              ),
              (
                id: 'next',
                label: '下一首',
                icon: Icons.skip_next,
                tap: () => model.playerControl('next'),
              ),
              (
                id: 'queue',
                label: '播放列表',
                icon: Icons.queue_music,
                tap: () => _openQueueSheet(context, model),
              ),
              (
                id: 'volume',
                label: '音量',
                icon: Icons.volume_up_outlined,
                tap: () => _openVolumeSheet(context, model),
              ),
            ]
            .where((action) => model.controlVisible('player.${action.id}'))
            .toList()
          ..sort(
            (a, b) => model.playerControlOrder
                .indexOf(a.id)
                .compareTo(model.playerControlOrder.indexOf(b.id)),
          );
    if (actions.isEmpty) return const SizedBox.shrink();
    Widget buildRow(
      List<({String id, String label, IconData icon, VoidCallback? tap})>
      rowActions,
    ) => SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final extent =
              (constraints.maxWidth / (centerTransport ? 7 : rowActions.length))
                  .clamp(34.0, 48.0);
          Widget control(
            ({String id, String label, IconData icon, VoidCallback? tap})
            action,
          ) => LongPressDraggable<String>(
            key: ValueKey('player-control-${action.id}'),
            data: action.id,
            feedback: Material(
              color: Colors.transparent,
              child: Icon(action.icon, size: 28 * model.playerButtonScale),
            ),
            childWhenDragging: SizedBox.square(dimension: extent),
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data != action.id,
              onAcceptWithDetails: (details) =>
                  model.movePlayerControl(details.data, action.id),
              builder: (context, candidates, _) => SizedBox.square(
                dimension: extent,
                child: Semantics(
                  label: action.label,
                  button: true,
                  child: IconButton(
                    onPressed: action.tap,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      minimumSize: Size.square(extent),
                    ),
                    icon: Icon(
                      action.icon,
                      size:
                          (action.id == 'play' ? 28 : 22) *
                          model.playerButtonScale,
                    ),
                  ),
                ),
              ),
            ),
          );
          if (centerTransport) {
            final transport = rowActions.where(
              (action) =>
                  const {'previous', 'play', 'next'}.contains(action.id),
            );
            final leading = rowActions.where(
              (action) => const {'favorite', 'mode'}.contains(action.id),
            );
            final trailing = rowActions.where(
              (action) => const {'queue', 'volume'}.contains(action.id),
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: max(constraints.maxWidth, extent * 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          for (final action in leading) control(action),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        for (final action in transport) control(action),
                      ],
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final action in trailing) control(action),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final action in rowActions) control(action)],
              ),
            ),
          );
        },
      ),
    );
    final primaryActions = actions.take(5).toList();
    final secondaryActions = actions.skip(5).toList();
    final content = twoRows
        ? Column(
            key: const ValueKey('two-row-player-tools'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (primaryActions.isNotEmpty) buildRow(primaryActions),
              if (secondaryActions.isNotEmpty) buildRow(secondaryActions),
            ],
          )
        : KeyedSubtree(
            key: const ValueKey('single-row-player-tools'),
            child: buildRow(actions),
          );
    return content;
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
  openAppPage<void>(context, SongDetailPage(model: model, song: song));
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
      final sheetColor = theme.colorScheme.surface.withValues(
        alpha: model.visualStyle == 'liquid' ? 0.94 : 1,
      );
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
                              child: AppCardSurface(
                                model: model,
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
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
