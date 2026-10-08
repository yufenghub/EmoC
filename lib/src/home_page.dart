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
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (model.regionTextVisible('home.searchBar')) ...[
                  SearchPanel(model: model),
                  const SizedBox(height: 20),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.025),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SectionHeader(
                    key: ValueKey(
                      hasSearch ? 'search-results' : 'daily-recommendations',
                    ),
                    title: hasSearch ? '搜索结果' : '每日歌曲推荐',
                    count: hasSearch
                        ? model.searchResults.length
                        : model.dailySongs.length,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          key: ValueKey(hasSearch ? 'search-list' : 'daily-list'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, opacity, child) =>
              SliverOpacity(opacity: opacity, sliver: child!),
          child: SliverSongList(
            songs: hasSearch ? model.searchResults : model.dailySongs,
            loading: hasSearch ? model.searchLoading : model.dailyLoading,
            emptyText: hasSearch ? '暂无搜索结果' : '暂无每日推荐歌曲，登录后刷新',
          ),
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
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.model.searchQuery);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() => setState(() {});

  void _submit(String query) {
    _focus.unfocus();
    unawaited(widget.model.submitSearch(query));
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.model.searchQuery) {
      controller.value = TextEditingValue(
        text: widget.model.searchQuery,
        selection: TextSelection.collapsed(
          offset: widget.model.searchQuery.length,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearch = widget.model.searchQuery.trim().isNotEmpty;
    return TextFieldTapRegion(
      child: SearchFieldSurface(
        child: Column(
          children: [
            TextField(
              controller: controller,
              focusNode: _focus,
              onTapOutside: (_) => _focus.unfocus(),
              textInputAction: TextInputAction.search,
              onChanged: widget.model.updateSearchQuery,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: widget.model.regionTextVisible('home.search')
                    ? '搜索音乐'
                    : null,
                prefixIcon: hasSearch || _focus.hasFocus
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
                        onPressed: () => _submit(controller.text),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _focus.hasFocus && !hasSearch
                  ? Padding(
                      key: const ValueKey('search-history'),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SearchHistorySection(
                        model: widget.model,
                        onSelected: _submit,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('search-history-hidden'),
                      width: double.infinity,
                    ),
            ),
            if (_focus.hasFocus &&
                widget.model.searchSuggestions.isNotEmpty) ...[
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
      ),
    );
  }
}

class SearchHistorySection extends StatelessWidget {
  const SearchHistorySection({
    required this.model,
    required this.onSelected,
    super.key,
  });
  final AppModel model;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final history = model.listeningHistory;
    return AnimatedBuilder(
      animation: history,
      builder: (context, _) => Column(
        children: [
          Row(
            children: [
              if (model.regionTextVisible('home.history'))
                Expanded(
                  child: Text(
                    '搜索历史',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                )
              else
                const Spacer(),
              IconButton(
                tooltip: '清空搜索历史',
                onPressed: history.searches.isEmpty
                    ? null
                    : () async {
                        if (await confirmHistoryClear(context, '搜索历史')) {
                          await history.clearSearches();
                        }
                      },
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          for (final query in history.searches.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history, size: 20),
              title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(query),
              trailing: IconButton(
                tooltip: '删除搜索记录',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => history.removeSearch(query),
              ),
            ),
        ],
      ),
    );
  }
}
