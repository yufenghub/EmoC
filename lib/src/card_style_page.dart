part of '../main.dart';

class CardStylePage extends StatelessWidget {
  const CardStylePage({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: model.visualStyle == 'liquid'
        ? Colors.transparent
        : Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('卡片样式')),
    body: AnimatedBuilder(
      animation: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'solid',
                  icon: Icon(Icons.crop_square),
                  label: Text('实心'),
                ),
                ButtonSegment(
                  value: 'outline',
                  icon: Icon(Icons.blur_on),
                  label: Text('镂空'),
                ),
              ],
              selected: {model.cardStyle},
              showSelectedIcon: false,
              onSelectionChanged: (values) => model.setCardStyle(values.first),
            ),
          ),
          if (model.libraryPlaylists.isNotEmpty) ...[
            const SizedBox(height: 24),
            IgnorePointer(
              child: PlaylistCard(playlist: model.libraryPlaylists.first),
            ),
          ],
          if (model.dailySongs.isNotEmpty) ...[
            const SizedBox(height: 8),
            IgnorePointer(
              child: PreparedSongTile(
                song: model.dailySongs.first,
                sourceList: model.dailySongs,
                sourceIndex: 0,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
