part of '../main.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final hasSearch = model.searchQuery.trim().isNotEmpty;
    return PageFrame(
      title: '首页',
      onRefresh: model.loadDailySongs,
      children: [
        SearchPanel(model: model),
        if (hasSearch) ...[
          const SizedBox(height: 20),
          SectionHeader(title: '搜索结果', count: model.searchResults.length),
          const SizedBox(height: 10),
          SongList(
            songs: model.searchResults,
            loading: model.searchLoading,
            emptyText: '暂无搜索结果',
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(title: '每日歌曲推荐', count: model.dailySongs.length),
        const SizedBox(height: 10),
        SongList(
          songs: model.dailySongs,
          loading: model.dailyLoading,
          emptyText: '暂无每日推荐歌曲，登录后刷新',
        ),
      ],
    );
  }
}

class SearchPanel extends StatefulWidget {
  const SearchPanel({required this.model, super.key});

  final AppModel model;

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.model.searchQuery);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.model.searchQuery &&
        widget.model.searchQuery.isEmpty) {
      controller.text = widget.model.searchQuery;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearch = widget.model.searchQuery.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: widget.model.updateSearchQuery,
            onSubmitted: widget.model.submitSearch,
            decoration: InputDecoration(
              hintText: '搜索音乐',
              prefixIcon: hasSearch
                  ? IconButton(
                      tooltip: '返回首页',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        controller.clear();
                        FocusScope.of(context).unfocus();
                        widget.model.clearSearch();
                      },
                    )
                  : const Icon(Icons.search),
              suffixIcon: widget.model.searchLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: '搜索',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () =>
                          widget.model.submitSearch(controller.text),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (widget.model.searchSuggestions.isNotEmpty) ...[
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.35),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.model.searchSuggestions.length,
                itemBuilder: (context, index) {
                  final item = widget.model.searchSuggestions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.manage_search),
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(item.subtitle),
                    onTap: () {
                      controller.text = item.title;
                      FocusScope.of(context).unfocus();
                      widget.model.openSuggestion(item);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
