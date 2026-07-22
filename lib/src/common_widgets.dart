part of '../main.dart';

const double _songTileHeight = 68;

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.children,
    this.subtitle = '',
    this.trailing,
    this.onRefresh,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
    if (onRefresh == null) return content;
    return RefreshIndicator(
      edgeOffset: 4,
      displacement: 30,
      strokeWidth: 2.4,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      onRefresh: onRefresh!,
      child: content,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.count, super.key});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text('$count 项', style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class SongList extends StatefulWidget {
  const SongList({
    required this.songs,
    required this.loading,
    this.emptyText = '无歌曲',
    super.key,
  });

  final List<MirrorItem> songs;
  final bool loading;
  final String emptyText;

  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  String _scheduledSignature = '';

  void _scheduleArtworkPreload(AppModel model) {
    final signature = [
      model.showSongCovers,
      widget.songs.length,
      for (final song in widget.songs) _songArtworkIdentity(song),
    ].join('|');
    if (_scheduledSignature == signature) return;
    _scheduledSignature = signature;
    if (!model.showSongCovers || widget.songs.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduledSignature != signature) return;
      unawaited(model.prepareSongArtworkBatch(widget.songs));
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    _scheduleArtworkPreload(model);
    return Column(
      children: [
        if (widget.songs.isEmpty && widget.loading)
          for (var i = 0; i < 8; i++) ...[
            const SongPlaceholderTile(),
            const SizedBox(height: 8),
          ]
        else if (widget.songs.isEmpty)
          EmptyPanel(icon: Icons.music_off, text: widget.emptyText)
        else
          for (var i = 0; i < widget.songs.length; i++) ...[
            PreparedSongTile(
              key: ValueKey(
                'song-${widget.songs[i].id}-${widget.songs[i].title}-${widget.songs[i].href}',
              ),
              song: widget.songs[i],
              sourceList: widget.songs,
              sourceIndex: i,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class SongPlaceholderTile extends StatelessWidget {
  const SongPlaceholderTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _songTileHeight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SkeletonLine(widthFactor: 0.55),
                  const SizedBox(height: 7),
                  const _SkeletonLine(widthFactor: 0.42, muted: true),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_arrow, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class PreparedSongTile extends StatefulWidget {
  const PreparedSongTile({
    required this.song,
    required this.sourceList,
    required this.sourceIndex,
    this.active = false,
    this.dynamicColorSource = 'daily',
    super.key,
  });

  final MirrorItem song;
  final List<MirrorItem> sourceList;
  final int sourceIndex;
  final bool active;
  final String dynamicColorSource;

  @override
  State<PreparedSongTile> createState() => _PreparedSongTileState();
}

class _PreparedSongTileState extends State<PreparedSongTile> {
  bool _preparing = false;
  bool _allowArtworkFallback = false;
  int _generation = 0;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant PreparedSongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_songArtworkIdentity(oldWidget.song) !=
        _songArtworkIdentity(widget.song)) {
      _generation += 1;
      _preparing = false;
      _allowArtworkFallback = false;
      _retryCount = 0;
      _retryTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _prepare(AppModel model) {
    if (_preparing || !model.showSongCovers) return;
    _preparing = true;
    final generation = _generation;
    unawaited(
      model
          .prepareSongArtwork(widget.song)
          .timeout(const Duration(milliseconds: 1800), onTimeout: () => false)
          .then((ready) {
            if (!mounted || generation != _generation) return;
            _preparing = false;
            if (ready) {
              _retryCount = 0;
              setState(() {});
              return;
            }
            _allowArtworkFallback = true;
            setState(() {});
            _retryCount += 1;
            final retryDelay = Duration(
              milliseconds: (1100 * (1 << _retryCount.clamp(0, 3)))
                  .clamp(1100, 12000)
                  .toInt(),
            );
            _retryTimer?.cancel();
            _retryTimer = Timer(retryDelay, () {
              if (mounted && generation == _generation) {
                _prepare(model);
              }
            });
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final ready =
        !model.showSongCovers || model.isSongArtworkReady(widget.song);
    if (!ready && !_allowArtworkFallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare(model);
      });
      return const SongPlaceholderTile();
    }
    return SongTile(
      song: widget.song,
      sourceList: widget.sourceList,
      sourceIndex: widget.sourceIndex,
      active: widget.active,
      dynamicColorSource: widget.dynamicColorSource,
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    required this.song,
    required this.sourceList,
    required this.sourceIndex,
    this.active = false,
    this.dynamicColorSource = 'daily',
    super.key,
  });

  final MirrorItem song;
  final List<MirrorItem> sourceList;
  final int sourceIndex;
  final bool active;
  final String dynamicColorSource;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final titleColor = active ? activeColor : theme.colorScheme.onSurface;
    final subtitleColor = active
        ? activeColor.withAlpha(210)
        : theme.colorScheme.onSurfaceVariant;
    final tileColor = active
        ? Color.alphaBlend(
            activeColor.withAlpha(18),
            theme.cardTheme.color ?? theme.colorScheme.surface,
          )
        : theme.cardTheme.color;
    final coverUrl = model.coverFor(song);
    if (model.showSongCovers && !coverUrl.startsWith('http')) {
      unawaited(model.ensureSongCover(song));
    }
    return SizedBox(
      height: _songTileHeight,
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => model.clickSong(
            song,
            fromList: sourceList,
            sourceIndex: sourceIndex,
            dynamicColorSource: dynamicColorSource,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SongArtwork(
                  url: coverUrl,
                  active: active,
                  showCover: model.showSongCovers,
                  onCoverError: () =>
                      unawaited(model.ensureSongCover(song, force: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: active
                              ? FontWeight.w900
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.subtitle.isEmpty ? '来自网易云音乐官网' : song.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.play_arrow, color: active ? activeColor : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SongArtwork extends StatelessWidget {
  const SongArtwork({
    required this.url,
    this.active = false,
    this.showCover = true,
    this.onCoverError,
    super.key,
  });

  final String url;
  final bool active;
  final bool showCover;
  final VoidCallback? onCoverError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: showCover
            ? CoverImage(
                url: url,
                fallbackIcon: active ? Icons.graphic_eq : Icons.music_note,
                onAllCandidatesFailed: onCoverError,
              )
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  active ? Icons.graphic_eq : Icons.music_note,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class PlaylistGrid extends StatelessWidget {
  const PlaylistGrid({
    required this.playlists,
    this.loading = false,
    super.key,
  });

  final List<MirrorItem> playlists;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final orderKey = playlists
        .map((playlist) => playlist.id.isEmpty ? playlist.title : playlist.id)
        .join('|');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Column(
        key: ValueKey('playlist-grid-$loading-$orderKey'),
        children: [
          if (playlists.isEmpty && loading)
            for (var i = 0; i < 5; i++) ...[
              const PlaylistPlaceholderCard(),
              const SizedBox(height: 8),
            ]
          else if (playlists.isEmpty)
            const EmptyPanel(icon: Icons.queue_music, text: '暂无我喜欢的音乐或创建歌单')
          else
            for (final playlist in playlists) ...[
              PlaylistCard(
                key: ValueKey(
                  'playlist-card-${playlist.id.isEmpty ? playlist.title : playlist.id}',
                ),
                playlist: playlist,
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class PlaylistPlaceholderCard extends StatelessWidget {
  const PlaylistPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.queue_music,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonLine(widthFactor: 0.62),
                const SizedBox(height: 7),
                const _SkeletonLine(widthFactor: 0.38, muted: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.widthFactor, this.muted = false});

  final double? widthFactor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Container(
      height: muted ? 9 : 12,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: muted ? 0.48 : 0.78,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
    );
    if (widthFactor == null) return line;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: line,
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({required this.playlist, super.key});

  final MirrorItem playlist;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final theme = Theme.of(context);
    final pinned = model.isPlaylistPinned(playlist);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => model.openLibraryPlaylist(playlist),
        onLongPress: () => _openPlaylistActionSheet(context, model, playlist),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  playlist.kind == 'liked' ? Icons.favorite : Icons.queue_music,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.subtitle.isEmpty
                          ? (playlist.kind == 'liked' ? '我喜欢的音乐' : '创建的歌单')
                          : playlist.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (pinned) ...[
                Icon(
                  Icons.push_pin,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

void _openPlaylistActionSheet(
  BuildContext context,
  AppModel model,
  MirrorItem playlist,
) {
  final pinned = model.isPlaylistPinned(playlist);
  final launcherContext = context;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                pinned ? Icons.vertical_align_center : Icons.push_pin_outlined,
              ),
              title: Text(pinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  pinned
                      ? model.unpinPlaylist(playlist)
                      : model.pinPlaylist(playlist),
                );
              },
            ),
            ListTile(
              enabled: playlist.kind == 'playlist',
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: playlist.kind != 'playlist'
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _confirmDeletePlaylist(launcherContext, model, playlist);
                    },
            ),
          ],
        ),
      );
    },
  );
}

void _confirmDeletePlaylist(
  BuildContext context,
  AppModel model,
  MirrorItem playlist,
) {
  final needsSecondConfirm = _playlistDeleteNeedsSecondConfirm(playlist);
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('删除歌单'),
        content: Text(
          needsSecondConfirm
              ? '“${playlist.title}”内有歌曲，继续后需要再次确认。'
              : '确定删除空歌单“${playlist.title}”？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (needsSecondConfirm) {
                _confirmDeletePlaylistAgain(context, model, playlist);
              } else {
                unawaited(model.deletePlaylist(playlist));
              }
            },
            child: Text(needsSecondConfirm ? '继续' : '删除'),
          ),
        ],
      );
    },
  );
}

void _confirmDeletePlaylistAgain(
  BuildContext context,
  AppModel model,
  MirrorItem playlist,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('再次确认删除'),
        content: Text('此歌单内有歌曲，删除后不可恢复。确认删除“${playlist.title}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(model.deletePlaylist(playlist));
            },
            child: const Text('确认删除'),
          ),
        ],
      );
    },
  );
}

bool _playlistDeleteNeedsSecondConfirm(MirrorItem playlist) {
  final count = _playlistSongCount(playlist);
  if (count == 0) return false;
  return count == null || count > 0;
}

int? _playlistSongCount(MirrorItem playlist) {
  final text = '${playlist.title} ${playlist.subtitle}';
  final matches = RegExp(r'(\d+)\s*首').allMatches(text);
  if (matches.isEmpty) return null;
  return int.tryParse(matches.last.group(1) ?? '');
}

class CoverImage extends StatefulWidget {
  const CoverImage({
    required this.url,
    this.identity = '',
    this.fallbackIcon = Icons.music_note,
    this.preferredSize = 360,
    this.decodeSize = 192,
    this.onAllCandidatesFailed,
    super.key,
  });

  final String url;
  final String identity;
  final IconData fallbackIcon;
  final int preferredSize;
  final int decodeSize;
  final VoidCallback? onAllCandidatesFailed;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  late List<String> _candidates;
  final Set<String> _decodeFailures = <String>{};
  Uint8List? _bytes;
  String _loadedUrl = '';
  int _loadGeneration = 0;
  int _retryCount = 0;
  bool _failureNotified = false;
  Timer? _staleHoldTimer;
  Timer? _externalRetryTimer;
  int _externalResolveRetryCount = 0;

  @override
  void initState() {
    super.initState();
    CoverRuntimeCache.instance.addListener(_handleRuntimeCacheChanged);
    _resetLoader();
  }

  @override
  void dispose() {
    _staleHoldTimer?.cancel();
    _externalRetryTimer?.cancel();
    CoverRuntimeCache.instance.removeListener(_handleRuntimeCacheChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url &&
        oldWidget.identity == widget.identity &&
        oldWidget.preferredSize == widget.preferredSize &&
        oldWidget.decodeSize == widget.decodeSize) {
      return;
    }
    _resetLoader(keepPrevious: true);
  }

  void _resetLoader({bool keepPrevious = false}) {
    _staleHoldTimer?.cancel();
    _externalRetryTimer?.cancel();
    _loadGeneration += 1;
    _candidates = _coverImageCandidates(
      widget.url,
      preferredSize: widget.preferredSize,
    );
    _decodeFailures.clear();
    if (!keepPrevious) {
      _bytes = null;
      _loadedUrl = '';
    }
    _retryCount = 0;
    _failureNotified = false;
    _externalResolveRetryCount = 0;
    _startLoad();
    if (keepPrevious && _candidates.isEmpty && _bytes != null) {
      final generation = _loadGeneration;
      _staleHoldTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted ||
            generation != _loadGeneration ||
            _candidates.isNotEmpty) {
          return;
        }
        setState(() {
          _bytes = null;
          _loadedUrl = '';
        });
      });
    }
  }

  void _handleRuntimeCacheChanged() {
    if (!mounted || _candidates.isEmpty) return;
    final cached = CoverRuntimeCache.instance.lookup(_candidates);
    if (cached == null || (_bytes != null && _loadedUrl == cached.url)) return;
    _staleHoldTimer?.cancel();
    setState(() {
      _bytes = cached.bytes;
      _loadedUrl = cached.url;
    });
  }

  void _startLoad() {
    final available = _candidates
        .where((url) => !_decodeFailures.contains(url))
        .toList(growable: false);
    final cached = CoverRuntimeCache.instance.lookup(available);
    if (cached != null) {
      _bytes = cached.bytes;
      _loadedUrl = cached.url;
      return;
    }
    if (available.isEmpty) {
      _notifyAllCandidatesFailed();
      return;
    }
    final generation = ++_loadGeneration;
    unawaited(
      CoverRuntimeCache.instance.load(available).then((entry) {
        if (!mounted || generation != _loadGeneration) return;
        if (entry == null) {
          _scheduleRetryOrNotify();
          return;
        }
        setState(() {
          _staleHoldTimer?.cancel();
          _bytes = entry.bytes;
          _loadedUrl = entry.url;
        });
      }),
    );
  }

  void _scheduleRetryOrNotify() {
    if (_retryCount >= 2) {
      _notifyAllCandidatesFailed();
      return;
    }
    _retryCount += 1;
    final generation = _loadGeneration;
    final delay = _retryCount == 1
        ? const Duration(milliseconds: 700)
        : const Duration(milliseconds: 1500);
    unawaited(
      Future<void>.delayed(delay, () {
        if (!mounted || generation != _loadGeneration) return;
        _decodeFailures.clear();
        _failureNotified = false;
        _startLoad();
      }),
    );
  }

  void _handleDecodeFailure() {
    if (_loadedUrl.isEmpty || _decodeFailures.contains(_loadedUrl)) return;
    _decodeFailures.add(_loadedUrl);
    CoverRuntimeCache.instance.evict(_loadedUrl);
    _bytes = null;
    _loadedUrl = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_startLoad);
    });
  }

  void _notifyAllCandidatesFailed() {
    if (_failureNotified || widget.onAllCandidatesFailed == null) return;
    _failureNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAllCandidatesFailed?.call();
    });
    if (_candidates.isEmpty && _externalResolveRetryCount < 2) {
      _externalResolveRetryCount += 1;
      final generation = _loadGeneration;
      final delay = _externalResolveRetryCount == 1
          ? const Duration(milliseconds: 1600)
          : const Duration(milliseconds: 3800);
      _externalRetryTimer?.cancel();
      _externalRetryTimer = Timer(delay, () {
        if (!mounted ||
            generation != _loadGeneration ||
            _candidates.isNotEmpty) {
          return;
        }
        _failureNotified = false;
        _notifyAllCandidatesFailed();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final bytes = _bytes;
    if (_candidates.isEmpty) {
      _notifyAllCandidatesFailed();
      if (bytes == null) return placeholder;
    }
    if (bytes == null) return placeholder;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Image.memory(
        bytes,
        key: ValueKey('cover-bytes-$_loadedUrl'),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: widget.decodeSize,
        cacheHeight: widget.decodeSize,
        filterQuality: widget.decodeSize > 256
            ? FilterQuality.high
            : FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          _handleDecodeFailure();
          return placeholder;
        },
      ),
    );
  }
}

List<String> _coverImageCandidates(String rawUrl, {int preferredSize = 360}) {
  var normalized = _absoluteMusicUrl(rawUrl).trim();
  if (normalized.startsWith('//')) normalized = 'https:$normalized';
  if (!normalized.startsWith('http')) return const [];
  final candidates = <String>{};

  void addVariants(String value) {
    final https = value.startsWith('http://')
        ? value.replaceFirst('http://', 'https://')
        : value;
    final base = https.split('?').first;
    candidates
      ..add('$base?param=${preferredSize}y$preferredSize')
      ..add('$base?param=360y360')
      ..add('$base?param=180y180')
      ..add(https)
      ..add(base);
  }

  addVariants(normalized);
  for (final host in const [
    'p1.music.126.net',
    'p2.music.126.net',
    'p3.music.126.net',
    'p4.music.126.net',
  ]) {
    addVariants(normalized.replaceFirst(RegExp(r'p\d\.music\.126\.net'), host));
  }
  return candidates.toList(growable: false);
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({required this.text, this.framed = true, super.key});

  final String text;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42),
      decoration: framed
          ? BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
