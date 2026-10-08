part of '../main.dart';

class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.songIds,
  });
  final String id;
  final String name;
  final List<String> songIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
}

class LocalMusicLibrary extends ChangeNotifier {
  LocalMusicLibrary({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : _read = read ?? NativeBridge.getString,
       _write = write ?? NativeBridge.setString;
  static const storageKey = 'localMusic.v1';
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  final Map<String, MirrorItem> _tracks = {};
  final Map<String, String> _lyrics = {};
  final Map<String, LocalPlaylist> _playlists = {};
  final Set<String> _roots = {};
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool busy = false;
  String message = '';
  List<MirrorItem> get tracks => List.unmodifiable(_tracks.values);
  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists.values);
  List<String> get roots => List.unmodifiable(_roots);
  String lyricsFor(String id) => _lyrics[id] ?? '';
  List<MirrorItem> playlistSongs(String id) => [
    for (final key in _playlists[id]?.songIds ?? <String>[])
      if (_tracks[key] != null) _tracks[key]!,
  ];

  Future<void> restore() async {
    try {
      final raw = await _read(storageKey).timeout(const Duration(seconds: 2));
      if (_disposed || raw == null) return;
      final data = _mapOf(jsonDecode(raw));
      for (final value in _listOf(data['tracks']).take(5000)) {
        final song = MirrorItem.fromJson(_mapOf(value));
        if (song.isLocal) _tracks[song.id] = song;
      }
      _roots.addAll(
        _listOf(data['roots'])
            .whereType<String>()
            .where((uri) => uri.startsWith('content://'))
            .take(20),
      );
      for (final entry in _mapOf(data['lyrics']).entries) {
        if (_tracks.containsKey(entry.key) &&
            entry.value is String &&
            (entry.value as String).length <= 256 * 1024) {
          _lyrics[entry.key] = entry.value;
        }
      }
      for (final value in _listOf(data['playlists']).take(200)) {
        final item = _mapOf(value);
        final id = _stringOf(item['id']);
        if (id.isEmpty) continue;
        _playlists[id] = LocalPlaylist(
          id: id,
          name: _stringOf(item['name']),
          songIds: _listOf(
            item['songIds'],
          ).whereType<String>().where(_tracks.containsKey).toSet().toList(),
        );
      }
      notifyListeners();
    } catch (_) {
      message = '本地音乐资料读取失败';
    }
  }

  Future<void> importMusic({bool folder = false, bool rescan = false}) async {
    if (busy || _disposed) return;
    busy = true;
    message = rescan ? '正在扫描已授权文件夹' : '正在导入';
    notifyListeners();
    try {
      final result = rescan
          ? await NativeBridge.scanLocalMusic(roots)
          : await NativeBridge.pickLocalMusic(folder: folder);
      if (!_disposed && result != null) {
        await mergeImport(result);
      } else if (!_disposed) {
        message = '已取消导入';
      }
    } catch (error) {
      if (!_disposed) {
        message = '导入失败：${error is PlatformException ? error.message : error}';
      }
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> mergeImport(Map<String, dynamic> result) async {
    var added = 0;
    for (final value in _listOf(result['tracks'])) {
      final song = MirrorItem.fromJson(_mapOf(value));
      if (!song.isLocal || song.title.isEmpty) continue;
      if (!_tracks.containsKey(song.id)) {
        if (_tracks.length >= 5000) break;
        added++;
      }
      _tracks[song.id] = song;
    }
    _roots.addAll(
      _listOf(result['roots'])
          .whereType<String>()
          .where((uri) => uri.startsWith('content://'))
          .take(20 - _roots.length),
    );
    message = '新增 $added 首，失败 ${_intOf(result['failed'])} 首';
    if (result['canceled'] == true) message += '，已停止';
    if (result['truncated'] == true) message += '，达到本次扫描上限';
    await _save();
  }

  Future<void> removeTrack(String id) {
    _tracks.remove(id);
    _lyrics.remove(id);
    for (final playlist in _playlists.values.toList()) {
      _playlists[playlist.id] = LocalPlaylist(
        id: playlist.id,
        name: playlist.name,
        songIds: playlist.songIds.where((key) => key != id).toList(),
      );
    }
    return _save();
  }

  Future<String> createPlaylist(String name) async {
    final title = name.trim();
    if (title.isEmpty) throw ArgumentError('歌单名称不能为空');
    final id = 'local-playlist-${DateTime.now().microsecondsSinceEpoch}';
    _playlists[id] = LocalPlaylist(id: id, name: title, songIds: []);
    await _save();
    return id;
  }

  Future<void> setPlaylistSongs(String id, Iterable<String> songIds) {
    final playlist = _playlists[id];
    if (playlist == null) return Future.value();
    _playlists[id] = LocalPlaylist(
      id: id,
      name: playlist.name,
      songIds: songIds.where(_tracks.containsKey).toSet().toList(),
    );
    return _save();
  }

  Future<void> deletePlaylist(String id) {
    _playlists.remove(id);
    return _save();
  }

  Future<void> attachLyrics(String songId, String lyrics) {
    if (!_tracks.containsKey(songId) || lyrics.length > 256 * 1024) {
      return Future.value();
    }
    _lyrics[songId] = lyrics;
    return _save();
  }

  Future<void> _save() {
    if (_disposed) return Future.value();
    final payload = jsonEncode({
      'tracks': _tracks.values.map((song) => song.toJson()).toList(),
      'roots': _roots.toList(),
      'lyrics': _lyrics,
      'playlists': _playlists.values.map((item) => item.toJson()).toList(),
    });
    notifyListeners();
    final write = _writes.then((_) => _write(storageKey, payload));
    _writes = write.catchError((_) {});
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({required this.model, super.key});
  final AppModel model;
  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  String query = '';
  LocalMusicLibrary get library => widget.model.localMusic;

  Future<void> _action(MirrorItem song, String action) async {
    try {
      if (action == 'lyrics') {
        final text = await NativeBridge.pickLocalLyrics();
        if (text != null) {
          await library.attachLyrics(song.id, text);
          if (widget.model.songDetail?.song.id == song.id) {
            await widget.model.openSongDetail(song);
          }
        }
      } else if (action == 'remove') {
        if (!mounted) return;
        if (await confirmHistoryClear(context, '本地条目“${song.title}”')) {
          await library.removeTrack(song.id);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建本地歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await library.createPlaylist(name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地歌单保存失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([library, widget.model]),
    builder: (context, _) {
      final songs = library.tracks
          .where(
            (song) => '${song.title} ${song.subtitle}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: widget.model.visualStyle == 'liquid'
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('本地音乐'),
            actions: [
              IconButton(
                tooltip: '新建本地歌单',
                onPressed: _createPlaylist,
                icon: const Icon(Icons.playlist_add),
              ),
              PopupMenuButton<String>(
                enabled: !library.busy,
                tooltip: '导入音乐',
                icon: const Icon(Icons.add),
                onSelected: (action) => library.importMusic(
                  folder: action == 'folder',
                  rescan: action == 'scan',
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'files', child: Text('选择音频文件')),
                  const PopupMenuItem(value: 'folder', child: Text('扫描文件夹')),
                  PopupMenuItem(
                    value: 'scan',
                    enabled: library.roots.isNotEmpty,
                    child: const Text('重新扫描'),
                  ),
                ],
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: '歌曲'),
                Tab(text: '本地歌单'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (library.busy) const LinearProgressIndicator(),
              if (library.message.isNotEmpty)
                ListTile(
                  dense: true,
                  title: Text(library.message),
                  trailing: library.busy
                      ? IconButton(
                          tooltip: '停止扫描',
                          onPressed: NativeBridge.cancelLocalMusicImport,
                          icon: const Icon(Icons.stop),
                        )
                      : null,
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: SearchFieldSurface(
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => query = value.trim()),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: '搜索本地音乐',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: songs.isEmpty
                              ? const Center(child: Text('暂无本地歌曲'))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  itemCount: songs.length,
                                  itemBuilder: (context, index) {
                                    final song = songs[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: AppCardSurface(
                                        model: widget.model,
                                        child: ListTile(
                                          leading: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: CoverImage(
                                                url: song.imageUrl,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            song.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          selected:
                                              widget.model.player.songId ==
                                              song.id,
                                          onTap: () => widget.model.clickSong(
                                            song,
                                            fromList: songs,
                                            sourceIndex: index,
                                          ),
                                          trailing: PopupMenuButton<String>(
                                            tooltip: '歌曲选项',
                                            onSelected: (value) =>
                                                _action(song, value),
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(
                                                value: 'lyrics',
                                                child: Text('关联歌词文件'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'remove',
                                                child: Text('从本地库移除'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                    library.playlists.isEmpty
                        ? const Center(child: Text('暂无本地歌单'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: library.playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = library.playlists[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCardSurface(
                                  model: widget.model,
                                  child: ListTile(
                                    leading: const Icon(Icons.queue_music),
                                    title: Text(playlist.name),
                                    subtitle: Text(
                                      '${playlist.songIds.length} 首',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => openAppPage<void>(
                                      context,
                                      LocalPlaylistPage(
                                        model: widget.model,
                                        playlistId: playlist.id,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: widget.model.showPlayerBar
              ? SafeArea(child: PlayerBar(model: widget.model))
              : null,
        ),
      );
    },
  );
}

class LocalPlaylistPage extends StatelessWidget {
  const LocalPlaylistPage({
    required this.model,
    required this.playlistId,
    super.key,
  });
  final AppModel model;
  final String playlistId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([model.localMusic, model]),
    builder: (context, _) {
      final library = model.localMusic;
      final playlist = library.playlists
          .where((item) => item.id == playlistId)
          .firstOrNull;
      final songs = library.playlistSongs(playlistId);
      return Scaffold(
        backgroundColor: model.visualStyle == 'liquid'
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(playlist?.name ?? '本地歌单'),
          actions: [
            IconButton(
              tooltip: '编辑歌曲',
              onPressed: playlist == null
                  ? null
                  : () async {
                      final selected = await openAppPage<Set<String>>(
                        context,
                        LocalSongPickerPage(
                          songs: library.tracks,
                          selected: playlist.songIds.toSet(),
                        ),
                      );
                      if (selected != null) {
                        await library.setPlaylistSongs(playlistId, selected);
                      }
                    },
              icon: const Icon(Icons.playlist_add_check),
            ),
            IconButton(
              tooltip: '删除本地歌单',
              onPressed: () async {
                if (await confirmHistoryClear(context, '本地歌单')) {
                  await library.deletePlaylist(playlistId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: songs.isEmpty
            ? const Center(child: Text('歌单为空'))
            : ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return ListTile(
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Icons.music_note),
                    selected: model.player.songId == song.id,
                    onTap: () => model.clickSong(
                      song,
                      fromList: songs,
                      sourceIndex: index,
                    ),
                  );
                },
              ),
        bottomNavigationBar: model.showPlayerBar
            ? SafeArea(child: PlayerBar(model: model))
            : null,
      );
    },
  );
}

class LocalSongPickerPage extends StatefulWidget {
  const LocalSongPickerPage({
    required this.songs,
    required this.selected,
    super.key,
  });
  final List<MirrorItem> songs;
  final Set<String> selected;
  @override
  State<LocalSongPickerPage> createState() => _LocalSongPickerPageState();
}

class _LocalSongPickerPageState extends State<LocalSongPickerPage> {
  late final Set<String> selected = {...widget.selected};
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppScope.of(context).visualStyle == 'liquid'
        ? Colors.transparent
        : Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      title: Text('已选 ${selected.length} 首'),
      actions: [
        IconButton(
          tooltip: '保存歌单',
          onPressed: () => Navigator.pop(context, selected),
          icon: const Icon(Icons.check),
        ),
      ],
    ),
    body: ListView.builder(
      itemCount: widget.songs.length,
      itemBuilder: (context, index) {
        final song = widget.songs[index];
        return CheckboxListTile(
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          value: selected.contains(song.id),
          onChanged: (value) => setState(() {
            if (value == true) {
              selected.add(song.id);
            } else {
              selected.remove(song.id);
            }
          }),
        );
      },
    ),
  );
}
