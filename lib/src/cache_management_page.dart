part of '../main.dart';

String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({required this.model, super.key});
  final AppModel model;

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  bool _busy = true;
  String? _error;
  int _covers = 0;
  int _memory = 0;
  int _content = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final stats = await CoverRuntimeCache.instance.statistics();
      var content = 0;
      for (final key in contentCacheKeys) {
        final value = await NativeBridge.getString(
          key,
        ).timeout(const Duration(seconds: 2));
        content += utf8.encode(value ?? '').length;
      }
      if (!mounted) return;
      setState(() {
        _covers = stats.diskBytes;
        _memory = stats.memoryBytes;
        _content = content;
        _busy = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '缓存统计读取失败';
        });
      }
    }
  }

  Future<void> _perform(String title, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清除$title？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '缓存清理失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = CoverRuntimeCache.instance;
    final model = widget.model;
    return Scaffold(
      backgroundColor: model.visualStyle == 'liquid'
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            tooltip: '刷新统计',
            onPressed: _busy
                ? null
                : () {
                    setState(() => _busy = true);
                    _refresh();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              title: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          _cacheTile(
            context,
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('封面缓存'),
              subtitle: Text(
                '磁盘 ${formatCacheBytes(_covers)} · 内存 ${formatCacheBytes(_memory)}',
              ),
              trailing: IconButton(
                tooltip: '清除封面缓存',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _perform('封面缓存', () async {
                        await cache.clear();
                        PaintingBinding.instance.imageCache
                          ..clear()
                          ..clearLiveImages();
                      }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _cacheTile(
            context,
            ListTile(
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('歌词缓存'),
              subtitle: Text(
                '${model.lyricsCache.count} 首 · ${formatCacheBytes(model.lyricsCache.byteSize)}',
              ),
              trailing: IconButton(
                tooltip: '清除歌词缓存',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _perform('歌词缓存', model.lyricsCache.clear),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _cacheTile(
            context,
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('列表与恢复数据'),
              subtitle: Text('数据大小 ${formatCacheBytes(_content)}'),
              trailing: IconButton(
                tooltip: '清除列表缓存',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy
                    ? null
                    : () => _perform('列表缓存', () async {
                        model._currentPlaylistPersistTimer?.cancel();
                        model._playlistRevealPersistTimer?.cancel();
                        model._playlistSongCache.clear();
                        model._playlistRevealCounts.clear();
                        await model._clearContentCache();
                      }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _cacheTile(
            context,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<int>(
                initialValue: cache.diskLimitBytes ~/ (1 << 20),
                decoration: const InputDecoration(labelText: '封面磁盘容量上限'),
                items: [16, 32, 64, 128, 256, 512]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value MB'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) async {
                        if (value == null) return;
                        setState(() => _busy = true);
                        try {
                          await cache.setDiskLimit(value << 20);
                          await NativeBridge.setString(
                            'coverDiskLimitMb',
                            '$value',
                          );
                          await _refresh();
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _busy = false;
                              _error = '容量设置保存失败';
                            });
                          }
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _cacheTile(BuildContext context, Widget child) =>
    AppCardSurface(model: AppScope.of(context), child: child);

const contentCacheKeys = [
  'cacheDailySongs',
  'cacheLibraryPlaylists',
  'cachePlayerSnapshot',
  'cacheCurrentPlaylist',
  'cacheCurrentSongIndex',
  'cacheCurrentPlaylistSource',
  'cacheRecentPlaylistId',
  'cacheRecentPlaylistSongs',
  'playlistRevealCounts',
];
