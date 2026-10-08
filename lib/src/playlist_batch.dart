part of '../main.dart';

typedef PlaylistSongMutation = Future<void> Function(MirrorItem song);

class PlaylistBatchController extends ChangeNotifier {
  bool running = false;
  bool canceled = false;
  bool _disposed = false;
  int total = 0;
  final List<MirrorItem> succeeded = [];
  final Map<String, String> failures = {};
  int get processed => succeeded.length + failures.length;

  void cancel() {
    canceled = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> run(List<MirrorItem> songs, PlaylistSongMutation mutate) async {
    if (running || _disposed) return;
    final unique = <String, MirrorItem>{};
    for (final song in songs) {
      unique.putIfAbsent(ListeningHistory.songKey(song), () => song);
    }
    running = true;
    canceled = false;
    total = unique.length;
    succeeded.clear();
    failures.clear();
    notifyListeners();
    try {
      for (final song in unique.values) {
        if (canceled || _disposed) break;
        try {
          if (song.id.isEmpty || !RegExp(r'^\d+$').hasMatch(song.id)) {
            throw const MusicApiException('仅支持在线歌曲');
          }
          await mutate(song);
          succeeded.add(song);
        } catch (error) {
          failures[ListeningHistory.songKey(song)] = error.toString();
          if (error is MusicApiException &&
              (error.code == 301 || error.code == 401)) {
            canceled = true;
          }
        }
        if (!_disposed) notifyListeners();
      }
    } finally {
      running = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    canceled = true;
    _disposed = true;
    super.dispose();
  }
}

extension PlaylistBatchActions on AppModel {
  Future<void> mutatePlaylistSong(
    MirrorItem playlist,
    MirrorItem song, {
    required bool remove,
  }) async {
    if (playlist.id.isEmpty ||
        song.id.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(song.id)) {
      throw const MusicApiException('歌曲或歌单 ID 无效');
    }
    if (playlist.kind == 'liked') {
      await _musicMutationApiClient.setSongLiked(
        song.id,
        !remove,
        likedPlaylistId: playlist.id,
      );
    } else if (remove) {
      await _musicMutationApiClient.removeSongFromPlaylist(
        playlist.id,
        song.id,
      );
    } else {
      await _musicMutationApiClient.addSongToPlaylist(playlist.id, song.id);
    }
    final visible = selectedLibraryPlaylist?.id == playlist.id;
    final cached = visible ? playlistSongs : _playlistSongCache[playlist.id];
    await _invalidatePlaylistSongsCache(playlist.id);
    if (cached != null) {
      final next = remove
          ? cached
                .where((item) => !_sameSong(item, song))
                .toList(growable: false)
          : cached.any((item) => _sameSong(item, song))
          ? cached
          : [...cached, song];
      _playlistSongCache[playlist.id] = next;
      if (selectedLibraryPlaylist?.id == playlist.id) {
        _playlistModule.cancelLoad();
        playlistSongs = next;
        playlistLoading = false;
      }
      await _saveRecentPlaylistSongsCache(playlist.id, next);
    }
    notifyListeners();
  }
}

class PlaylistBatchPage extends StatefulWidget {
  const PlaylistBatchPage({
    required this.model,
    required this.playlist,
    required this.songs,
    super.key,
  });
  final AppModel model;
  final MirrorItem playlist;
  final List<MirrorItem> songs;

  @override
  State<PlaylistBatchPage> createState() => _PlaylistBatchPageState();
}

class _PlaylistBatchPageState extends State<PlaylistBatchPage> {
  final _batch = PlaylistBatchController();
  final _selected = <String>{};
  final _removed = <String>{};
  String _query = '';
  bool _duplicatesOnly = false;
  String _sortMode = 'playlist';
  late final Map<String, int> _counts;
  late final List<({int index, MirrorItem song})> _orderedSongs;

  @override
  void initState() {
    super.initState();
    _counts = {};
    _orderedSongs = [
      for (var index = 0; index < widget.songs.length; index++)
        (index: index, song: widget.songs[index]),
    ];
    for (final song in widget.songs) {
      final key = ListeningHistory.songKey(song);
      _counts[key] = (_counts[key] ?? 0) + 1;
    }
  }

  void _setSortMode(String mode) {
    setState(() {
      _sortMode = mode;
      _orderedSongs.sort((a, b) {
        final comparison = switch (mode) {
          'title' => a.song.title.toLowerCase().compareTo(
            b.song.title.toLowerCase(),
          ),
          'artist' => a.song.subtitle.toLowerCase().compareTo(
            b.song.subtitle.toLowerCase(),
          ),
          'reverse' => b.index.compareTo(a.index),
          _ => a.index.compareTo(b.index),
        };
        return comparison != 0 ? comparison : a.index.compareTo(b.index);
      });
    });
  }

  @override
  void dispose() {
    _batch.dispose();
    super.dispose();
  }

  Future<void> _run(bool remove) async {
    final songs = widget.songs
        .where((song) => _selected.contains(ListeningHistory.songKey(song)))
        .toList();
    if (songs.isEmpty) return;
    MirrorItem? target = widget.playlist;
    if (!remove) {
      target = await showModalBottomSheet<MirrorItem>(
        context: context,
        useSafeArea: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('添加到歌单')),
            if (widget.model.libraryPlaylists.isEmpty)
              const ListTile(title: Text('暂无可用歌单')),
            for (final playlist in widget.model.libraryPlaylists)
              if (playlist.kind == 'playlist' || playlist.kind == 'liked')
                ListTile(
                  title: Text(playlist.title),
                  leading: const Icon(Icons.queue_music),
                  onTap: () => Navigator.pop(context, playlist),
                ),
          ],
        ),
      );
    }
    if (!mounted || target == null) return;
    final destination = target;
    final count = songs.map(ListeningHistory.songKey).toSet().length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(remove ? '移除 $count 首歌曲？' : '添加 $count 首歌曲？'),
        content: Text(destination.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(remove ? '移除' : '添加'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _batch.run(
      songs,
      (song) =>
          widget.model.mutatePlaylistSong(destination, song, remove: remove),
    );
    if (!mounted) return;
    setState(() {
      final keys = _batch.succeeded.map(ListeningHistory.songKey).toSet();
      _selected.removeAll(keys);
      if (remove) _removed.addAll(keys);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _batch,
    builder: (context, _) {
      final query = _query.toLowerCase();
      final songs = _orderedSongs.map((entry) => entry.song).where((song) {
        final key = ListeningHistory.songKey(song);
        return !_removed.contains(key) &&
            (!_duplicatesOnly || _counts[key]! > 1) &&
            '${song.title} ${song.subtitle}'.toLowerCase().contains(query);
      }).toList();
      final keys = songs.map(ListeningHistory.songKey).toSet();
      final allSelected = keys.isNotEmpty && _selected.containsAll(keys);
      return PopScope(
        canPop: !_batch.running,
        child: Scaffold(
          backgroundColor: widget.model.visualStyle == 'liquid'
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text('已选 ${_selected.length} 首'),
            actions: [
              if (_batch.running)
                IconButton(
                  tooltip: '停止后续操作',
                  onPressed: _batch.cancel,
                  icon: const Icon(Icons.stop),
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchFieldSurface(
                  child: TextField(
                    enabled: !_batch.running,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索歌名或歌手',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AppCardSurface(
                  model: widget.model,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortMode,
                    decoration: const InputDecoration(
                      labelText: '排列方式',
                      prefixIcon: Icon(Icons.sort),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'playlist', child: Text('歌单顺序')),
                      DropdownMenuItem(value: 'reverse', child: Text('歌单逆序')),
                      DropdownMenuItem(value: 'title', child: Text('按歌名')),
                      DropdownMenuItem(value: 'artist', child: Text('按歌手')),
                    ],
                    onChanged: _batch.running
                        ? null
                        : (mode) {
                            if (mode != null) _setSortMode(mode);
                          },
                  ),
                ),
              ),
              CheckboxListTile(
                title: Text('全选当前结果 (${keys.length})'),
                value: allSelected,
                onChanged: _batch.running
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.addAll(keys);
                        } else {
                          _selected.removeAll(keys);
                        }
                      }),
              ),
              SwitchListTile(
                title: const Text('仅显示重复歌曲'),
                value: _duplicatesOnly,
                onChanged: _batch.running
                    ? null
                    : (value) => setState(() => _duplicatesOnly = value),
              ),
              if (_batch.total > 0)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (_batch.running)
                        LinearProgressIndicator(
                          value: _batch.processed / _batch.total,
                        ),
                      Text(
                        '成功 ${_batch.succeeded.length} · 失败 ${_batch.failures.length} · 未处理 ${_batch.total - _batch.processed}',
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: songs.isEmpty
                    ? const Center(child: Text('无匹配歌曲'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final key = ListeningHistory.songKey(song);
                          final failure = _batch.failures[key];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCardSurface(
                              model: widget.model,
                              child: CheckboxListTile(
                                value: _selected.contains(key),
                                onChanged: _batch.running
                                    ? null
                                    : (value) => setState(() {
                                        if (value == true) {
                                          _selected.add(key);
                                        } else {
                                          _selected.remove(key);
                                        }
                                      }),
                                title: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  failure ?? song.subtitle,
                                  maxLines: failure == null ? 1 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: failure == null
                                      ? null
                                      : TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selected.isEmpty || _batch.running
                          ? null
                          : () => _run(true),
                      icon: const Icon(Icons.playlist_remove),
                      label: const Text('移出歌单'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty || _batch.running
                          ? null
                          : () => _run(false),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('添加到'),
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
