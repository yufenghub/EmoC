part of '../main.dart';

class ListeningHistoryPage extends StatelessWidget {
  const ListeningHistoryPage({required this.model, super.key});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final history = model.listeningHistory;
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) {
        final entries = history.recent;
        return Scaffold(
          backgroundColor: model.visualStyle == 'liquid'
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('最近播放'),
            actions: [
              IconButton(
                tooltip: '清空最近播放',
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        if (await confirmHistoryClear(context, '最近播放')) {
                          await history.clearRecent();
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: AppCardSurface(
                  model: model,
                  child: SwitchListTile(
                    title: const Text('记录最近播放'),
                    value: history.recordPlayback,
                    onChanged: (value) => history.setRecording(playback: value),
                  ),
                ),
              ),
              if (history.persistenceError != null)
                Text(
                  history.persistenceError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('暂无播放记录'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final date = entry.playedAt;
                          final label =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCardSurface(
                              model: model,
                              child: ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(
                                  entry.song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  entry.song.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => model.clickSong(
                                  entry.song,
                                  fromList: entries
                                      .map((item) => item.song)
                                      .toList(),
                                  sourceIndex: index,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    SizedBox(
                                      height: 32,
                                      child: IconButton(
                                        tooltip: '删除记录',
                                        onPressed: () =>
                                            history.removeSong(entry.song),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
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
        );
      },
    );
  }
}

Future<bool> confirmHistoryClear(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空$name？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    ) ??
    false;
