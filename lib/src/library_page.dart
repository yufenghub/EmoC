part of '../main.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final playlist = model.selectedLibraryPlaylist;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.055, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: playlist != null
          ? PlaylistDetailPage(
              key: ValueKey('playlist-${playlist.id}-${playlist.title}'),
              model: model,
              playlist: playlist,
              onBack: model.closeLibraryPlaylist,
            )
          : PageFrame(
              key: const ValueKey('library-list'),
              title: '歌单',
              trailing: IconButton.filledTonal(
                tooltip: '新建歌单',
                onPressed: () => _openCreatePlaylistDialog(context, model),
                icon: const Icon(Icons.add),
              ),
              onRefresh: model.loadLibrary,
              children: [
                SectionHeader(
                  title: '我的音乐',
                  count: model.libraryPlaylists.length,
                ),
                const SizedBox(height: 10),
                PlaylistGrid(
                  playlists: model.libraryPlaylists,
                  loading: model.libraryLoading,
                ),
              ],
            ),
    );
  }
}

void _openCreatePlaylistDialog(BuildContext context, AppModel model) {
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '歌单名称'),
          onSubmitted: (value) {
            Navigator.of(context).pop();
            unawaited(model.createPlaylist(value));
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text;
              Navigator.of(context).pop();
              unawaited(model.createPlaylist(value));
            },
            child: const Text('新建'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
