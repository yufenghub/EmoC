part of '../main.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    required this.model,
    required this.playlist,
    this.onBack,
    super.key,
  });

  final AppModel model;
  final MirrorItem playlist;
  final VoidCallback? onBack;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  final ScrollController _controller = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  static const int _initialVisibleSongs = 60;
  static const int _visibleSongStep = 60;
  int _visibleSongCount = _initialVisibleSongs;
  int _lastSongTotal = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_loadMoreWhenNearBottom);
    _searchController.addListener(_handleSearchChanged);
    unawaited(widget.model.loadPlaylistSongs(widget.playlist));
  }

  @override
  void dispose() {
    _controller.removeListener(_loadMoreWhenNearBottom);
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _searchQuery) return;
    setState(() {
      _searchQuery = next;
      _lastSongTotal = -1;
    });
  }

  void _loadMoreWhenNearBottom() {
    if (!_controller.hasClients) return;
    if (_controller.position.extentAfter > 520) return;
    final total = _filteredSongs(widget.model.playlistSongs).length;
    if (_visibleSongCount >= total) return;
    setState(() {
      _visibleSongCount = (_visibleSongCount + _visibleSongStep).clamp(
        0,
        total,
      );
    });
  }

  void _syncVisibleCount(int total) {
    if (total != _lastSongTotal) {
      _lastSongTotal = total;
      _visibleSongCount = total < _initialVisibleSongs
          ? total
          : _initialVisibleSongs;
    } else if (_visibleSongCount > total) {
      _visibleSongCount = total;
    }
  }

  List<MirrorItem> _filteredSongs(List<MirrorItem> songs) {
    final query = _normalizeSearchText(_searchQuery);
    if (query.isEmpty) return songs;
    return songs
        .where((song) {
          final haystack = _normalizeSearchText(
            '${song.title} ${song.subtitle}',
          );
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _refreshPlaylistSongs() async {
    setState(() {
      _lastSongTotal = -1;
      _visibleSongCount = _initialVisibleSongs;
    });
    await widget.model.loadPlaylistSongs(widget.playlist);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final songs = widget.model.playlistSongs;
        final filteredSongs = _filteredSongs(songs);
        _syncVisibleCount(filteredSongs.length);
        final visibleSongs = filteredSongs
            .take(_visibleSongCount)
            .toList(growable: false);
        final searching = _searchQuery.isNotEmpty;
        return SafeArea(
          child: RefreshIndicator(
            edgeOffset: 4,
            displacement: 30,
            strokeWidth: 2.4,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            onRefresh: _refreshPlaylistSongs,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _controller,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: '返回歌单',
                            onPressed: () {
                              final onBack = widget.onBack;
                              if (onBack != null) {
                                onBack();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.playlist.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  axis: Axis.horizontal,
                                  sizeFactor: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: widget.model.playlistLoading
                                ? const Padding(
                                    key: ValueKey('playlist-loading-chip'),
                                    padding: EdgeInsets.only(left: 10),
                                    child: PlaylistLoadingChip(),
                                  )
                                : const SizedBox(
                                    key: ValueKey('playlist-loading-empty'),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.playlist.kind == 'liked'
                                  ? Icons.favorite
                                  : Icons.queue_music,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.playlist.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.playlist.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PlaylistSearchField(
                        controller: _searchController,
                        enabled: songs.isNotEmpty,
                      ),
                      const SizedBox(height: 14),
                      SectionHeader(
                        title: searching ? '搜索结果' : '歌曲列表',
                        count: filteredSongs.length,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                LazyPlaylistSongList(
                  model: widget.model,
                  playlist: widget.playlist,
                  visibleSongs: visibleSongs,
                  playbackSongs: songs,
                  sourceSongs: filteredSongs,
                  loading: widget.model.playlistLoading,
                  hasMore: _visibleSongCount < filteredSongs.length,
                  emptyText: searching ? '未找到匹配歌曲' : '无歌曲',
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PlaylistSearchField extends StatelessWidget {
  const PlaylistSearchField({
    required this.controller,
    required this.enabled,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空搜索',
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              ),
        hintText: enabled ? '在当前歌单内搜索歌曲' : '歌单加载后可搜索',
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PlaylistLoadingChip extends StatelessWidget {
  const PlaylistLoadingChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '正在加载歌单',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LazyPlaylistSongList extends StatelessWidget {
  const LazyPlaylistSongList({
    required this.model,
    required this.playlist,
    required this.visibleSongs,
    required this.playbackSongs,
    required this.sourceSongs,
    required this.loading,
    required this.hasMore,
    required this.emptyText,
    super.key,
  });

  final AppModel model;
  final MirrorItem playlist;
  final List<MirrorItem> visibleSongs;
  final List<MirrorItem> playbackSongs;
  final List<MirrorItem> sourceSongs;
  final bool loading;
  final bool hasMore;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (visibleSongs.isEmpty && loading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: 8,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SongPlaceholderTile(),
          ),
        ),
      );
    }
    if (visibleSongs.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(
          child: EmptyPanel(icon: Icons.music_off, text: emptyText),
        ),
      );
    }
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: visibleSongs.length + (hasMore ? 1 : 0),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          if (index >= visibleSongs.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                '继续向下滑动加载更多',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final song = visibleSongs[index];
          final playbackSource = playbackSongs.isNotEmpty
              ? playbackSongs
              : sourceSongs;
          return PlaylistSwipeSongTile(
            key: ValueKey(
              'playlist-song-${playlist.id}-${song.id}-${song.title}',
            ),
            model: model,
            playlist: playlist,
            song: song,
            sourceList: playbackSource,
            sourceIndex: _sourceIndexForSong(song, playbackSource, index),
          );
        },
      ),
    );
  }
}

class PlaylistSwipeSongTile extends StatefulWidget {
  const PlaylistSwipeSongTile({
    required this.model,
    required this.playlist,
    required this.song,
    required this.sourceList,
    required this.sourceIndex,
    super.key,
  });

  final AppModel model;
  final MirrorItem playlist;
  final MirrorItem song;
  final List<MirrorItem> sourceList;
  final int sourceIndex;

  @override
  State<PlaylistSwipeSongTile> createState() => _PlaylistSwipeSongTileState();
}

class _PlaylistSwipeSongTileState extends State<PlaylistSwipeSongTile> {
  static const double _deleteWidth = 82;
  double _dragOffset = 0;
  bool _removing = false;

  bool get _canDelete =>
      widget.playlist.kind == 'playlist' || widget.playlist.kind == 'liked';

  @override
  void didUpdateWidget(covariant PlaylistSwipeSongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.title != widget.song.title) {
      _dragOffset = 0;
      _removing = false;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_canDelete || _removing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_deleteWidth, 0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_canDelete || _removing) return;
    final velocity = details.primaryVelocity ?? 0;
    setState(() {
      if (velocity < -260 || _dragOffset.abs() > _deleteWidth * 0.42) {
        _dragOffset = -_deleteWidth;
      } else {
        _dragOffset = 0;
      }
    });
  }

  Future<void> _deleteWithAnimation() async {
    if (!_canDelete || _removing) return;
    setState(() {
      _removing = true;
      _dragOffset = -MediaQuery.sizeOf(context).width;
    });
    await Future<void>.delayed(const Duration(milliseconds: 230));
    if (!mounted) return;
    final deleted = await widget.model.removeSongFromPlaylist(
      widget.playlist,
      widget.song,
    );
    if (!mounted || deleted) return;
    setState(() {
      _removing = false;
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final slideFraction = _removing ? -1.18 : _dragOffset / width;
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: SizedBox(
          height: _removing ? 0 : _songTileHeight + 8,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _removing ? 0 : 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: _deleteWidth,
                        height: _songTileHeight,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer,
                            foregroundColor: theme.colorScheme.onErrorContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: !_canDelete ? null : _deleteWithAnimation,
                          child: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    offset: Offset(slideFraction, 0),
                    child: GestureDetector(
                      onHorizontalDragUpdate: _handleDragUpdate,
                      onHorizontalDragEnd: _handleDragEnd,
                      child: SongTile(
                        song: widget.song,
                        sourceList: widget.sourceList,
                        sourceIndex: widget.sourceIndex,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

int _sourceIndexForSong(
  MirrorItem song,
  List<MirrorItem> sourceSongs,
  int fallbackIndex,
) {
  if (fallbackIndex >= 0 &&
      fallbackIndex < sourceSongs.length &&
      identical(sourceSongs[fallbackIndex], song)) {
    return fallbackIndex;
  }
  final identityIndex = sourceSongs.indexWhere((item) => identical(item, song));
  if (identityIndex >= 0) return identityIndex;
  if (song.id.isNotEmpty) {
    final idIndex = sourceSongs.indexWhere((item) => item.id == song.id);
    if (idIndex >= 0) return idIndex;
  }
  if (song.href.isNotEmpty) {
    final hrefIndex = sourceSongs.indexWhere((item) => item.href == song.href);
    if (hrefIndex >= 0) return hrefIndex;
  }
  return fallbackIndex;
}
