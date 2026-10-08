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
              trailing: !model.regionTextVisible('library.newPlaylist')
                  ? null
                  : model.visualStyle == 'liquid'
                  ? LiquidSurface(
                      model: model,
                      child: IconButton(
                        tooltip: '新建歌单',
                        onPressed: () =>
                            _openCreatePlaylistDialog(context, model),
                        icon: const Icon(Icons.add),
                      ),
                    )
                  : IconButton.filledTonal(
                      tooltip: '新建歌单',
                      onPressed: () =>
                          _openCreatePlaylistDialog(context, model),
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
                const SizedBox(height: 20),
                if (model.regionTextVisible('library.local'))
                  Builder(
                    builder: (context) {
                      return AppCardSurface(
                        model: model,
                        child: ListTile(
                          leading: const Icon(Icons.library_music_outlined),
                          title: const Text(
                            '本地音乐',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openAppPage<void>(
                            context,
                            LocalMusicPage(model: model),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

void _openCreatePlaylistDialog(BuildContext context, AppModel model) {
  showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => _CreatePlaylistSheet(model: model),
  ).then((name) {
    if (name != null) unawaited(model.createPlaylist(name));
  });
}

class _CreatePlaylistSheet extends StatefulWidget {
  const _CreatePlaylistSheet({required this.model});

  final AppModel model;

  @override
  State<_CreatePlaylistSheet> createState() => _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends State<_CreatePlaylistSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewPaddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新建歌单', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '歌单名称'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _submit,
                child: const Text('新建'),
              ),
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: widget.model.visualStyle == 'liquid'
          ? LiquidSurface(model: widget.model, child: content)
          : Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: content,
            ),
    );
  }
}
