part of '../main.dart';

const playerControlLabels = <String, String>{
  'mini.previous': '上一首',
  'mini.play': '播放 / 暂停',
  'mini.next': '下一首',
  'mini.progress': '顶部进度光效',
  'player.favorite': '收藏',
  'player.mode': '播放顺序',
  'player.previous': '上一首',
  'player.play': '播放 / 暂停',
  'player.next': '下一首',
  'player.queue': '播放列表',
  'player.volume': '音量',
  'player.progress': '播放进度',
};

const regionTextLabels = <String, Map<String, String>>{
  'home': {
    'title': '页面标题',
    'sections': '内容标题',
    'searchBar': '搜索栏',
    'search': '搜索提示',
    'history': '搜索历史标题',
  },
  'library': {
    'title': '页面标题',
    'sections': '内容标题',
    'local': '本地音乐入口',
    'newPlaylist': '新建歌单按钮',
  },
  'settings': {'title': '页面标题', 'sections': '分组标题'},
  'lyrics': {'artist': '歌手信息', 'timing': '进度时间'},
};

ThemeData applyUiColors(ThemeData base, AppModel model) {
  final textColor = model.uiTextFollowsDynamic
      ? base.colorScheme.onSurface
      : model.uiFixedTextColor;
  final iconColor = model.uiIconFollowsDynamic
      ? base.colorScheme.primary
      : model.uiFixedIconColor;
  final progressColor = model.uiProgressFollowsDynamic
      ? base.colorScheme.primary
      : model.uiFixedProgressColor;
  final scheme = base.colorScheme.copyWith(
    onSurface: textColor,
    onSurfaceVariant: model.uiTextFollowsDynamic
        ? base.colorScheme.onSurfaceVariant
        : textColor.withValues(alpha: 0.72),
    primary: iconColor,
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: textColor,
      displayColor: textColor,
    ),
    iconTheme: base.iconTheme.copyWith(color: iconColor),
    primaryIconTheme: base.primaryIconTheme.copyWith(color: iconColor),
    listTileTheme: base.listTileTheme.copyWith(iconColor: iconColor),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: progressColor,
      thumbColor: progressColor,
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: progressColor,
      linearTrackColor: progressColor.withValues(alpha: 0.18),
    ),
  );
}

extension InterfacePreferences on AppModel {
  bool controlVisible(String key) => !hiddenControls.contains(key);

  void restoreInterfacePreferences(String? raw) {
    if (raw == null) return;
    try {
      final values = _mapOf(jsonDecode(raw));
      if (values['iconOnlyNavigation'] is bool) {
        iconOnlyNavigation = values['iconOnlyNavigation'] as bool;
      }
      if (values['cardStyle'] == 'outline' || values['cardStyle'] == 'solid') {
        cardStyle = values['cardStyle'] as String;
      }
      cardFrameEnabled = values['cardFrameEnabled'] != false;
      hiddenControls = _listOf(
        values['hiddenControls'],
      ).map(_stringOf).where(playerControlLabels.containsKey).toSet();
      const defaultOrder = [
        'mode',
        'previous',
        'play',
        'next',
        'favorite',
        'queue',
        'volume',
      ];
      final restoredOrder = _listOf(
        values['playerControlOrder'],
      ).map(_stringOf).where(defaultOrder.contains).toSet();
      playerControlOrder = [
        ...restoredOrder,
        ...defaultOrder.where((id) => !restoredOrder.contains(id)),
      ];
      double number(String key, double fallback, double low, double high) =>
          (values[key] is num ? (values[key] as num).toDouble() : fallback)
              .clamp(low, high);
      coverBlur = number('coverBlur', 48, 24, 80);
      coverLight = number('coverLight', 1.2, 0.6, 1.8);
      glassDepth = number('glassDepth', 28, 10, 50);
      glassBlur = number('glassBlur', 4, 0, 16);
      animationSpeed = number('animationSpeed', 1, 0.5, 2);
      progressGlow = number('progressGlow', 0.8, 0, 1.5);
      playerButtonScale = number('playerButtonScale', 1, 0.75, 1.4);
      playerLyricsFontScale = number('playerLyricsFontScale', 1, 0.75, 1.5);
      if (values['coverFirstBackground'] is bool) {
        coverFirstBackground = values['coverFirstBackground'] as bool;
      }
      uiTextFollowsDynamic = values['uiTextFollowsDynamic'] != false;
      uiIconFollowsDynamic = values['uiIconFollowsDynamic'] != false;
      uiProgressFollowsDynamic = values['uiProgressFollowsDynamic'] != false;
      Color restoredColor(String key, Color fallback) =>
          values[key] is int ? Color(values[key] as int) : fallback;
      uiFixedTextColor = restoredColor('uiFixedTextColor', uiFixedTextColor);
      uiFixedIconColor = restoredColor('uiFixedIconColor', uiFixedIconColor);
      uiFixedProgressColor = restoredColor(
        'uiFixedProgressColor',
        uiFixedProgressColor,
      );
      hiddenRegionText = _listOf(values['hiddenRegionText'])
          .map(_stringOf)
          .where((key) {
            final parts = key.split('.');
            return parts.length == 2 &&
                (regionTextLabels[parts.first]?.containsKey(parts.last) ??
                    false);
          })
          .toSet();
    } on FormatException {
      debugPrint('Invalid interface preferences');
    }
  }

  Future<void> saveInterfacePreferences() => NativeBridge.setString(
    'interfacePreferences',
    jsonEncode({
      'iconOnlyNavigation': iconOnlyNavigation,
      'cardStyle': cardStyle,
      'cardFrameEnabled': cardFrameEnabled,
      'hiddenControls': hiddenControls.toList(),
      'playerControlOrder': playerControlOrder,
      'coverBlur': coverBlur,
      'coverLight': coverLight,
      'glassDepth': glassDepth,
      'glassBlur': glassBlur,
      'animationSpeed': animationSpeed,
      'progressGlow': progressGlow,
      'playerButtonScale': playerButtonScale,
      'playerLyricsFontScale': playerLyricsFontScale,
      'coverFirstBackground': coverFirstBackground,
      'uiTextFollowsDynamic': uiTextFollowsDynamic,
      'uiIconFollowsDynamic': uiIconFollowsDynamic,
      'uiProgressFollowsDynamic': uiProgressFollowsDynamic,
      'uiFixedTextColor': uiFixedTextColor.toARGB32(),
      'uiFixedIconColor': uiFixedIconColor.toARGB32(),
      'uiFixedProgressColor': uiFixedProgressColor.toARGB32(),
      'hiddenRegionText': hiddenRegionText.toList(),
    }),
  );

  Future<void> setIconOnlyNavigation(bool enabled) async {
    iconOnlyNavigation = enabled;
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> setCardStyle(String style) async {
    if (style != 'solid' && style != 'outline') return;
    cardStyle = style;
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> setCardFrameEnabled(bool enabled) async {
    if (cardFrameEnabled == enabled) return;
    cardFrameEnabled = enabled;
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> setCoverFirstBackground(bool enabled) async {
    coverFirstBackground = enabled;
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> setControlVisible(String key, bool visible) async {
    if (!playerControlLabels.containsKey(key)) return;
    visible ? hiddenControls.remove(key) : hiddenControls.add(key);
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> movePlayerControl(String source, String target) async {
    if (source == target ||
        !playerControlOrder.contains(source) ||
        !playerControlOrder.contains(target)) {
      return;
    }
    final sourceIndex = playerControlOrder.indexOf(source);
    final targetIndex = playerControlOrder.indexOf(target);
    playerControlOrder[sourceIndex] = target;
    playerControlOrder[targetIndex] = source;
    notifyListeners();
    await saveInterfacePreferences();
  }

  Future<void> setUiRoleColor(
    String role, {
    bool? followDynamic,
    Color? fixedColor,
  }) async {
    switch (role) {
      case 'text':
        uiTextFollowsDynamic = followDynamic ?? uiTextFollowsDynamic;
        uiFixedTextColor = fixedColor ?? uiFixedTextColor;
      case 'icon':
        uiIconFollowsDynamic = followDynamic ?? uiIconFollowsDynamic;
        uiFixedIconColor = fixedColor ?? uiFixedIconColor;
      case 'progress':
        uiProgressFollowsDynamic = followDynamic ?? uiProgressFollowsDynamic;
        uiFixedProgressColor = fixedColor ?? uiFixedProgressColor;
    }
    notifyListeners();
    await saveInterfacePreferences();
  }

  bool regionTextVisible(String key) =>
      key == 'settings.labels' || !hiddenRegionText.contains(key);

  Future<void> setRegionTextVisible(String key, bool visible) async {
    visible ? hiddenRegionText.remove(key) : hiddenRegionText.add(key);
    notifyListeners();
    await saveInterfacePreferences();
  }

  Color progressColor(ThemeData theme) => uiProgressFollowsDynamic
      ? (theme.sliderTheme.activeTrackColor ?? theme.colorScheme.primary)
      : uiFixedProgressColor;

  void updateEffect(String key, double value) {
    switch (key) {
      case 'coverBlur':
        coverBlur = value.clamp(24, 80);
      case 'coverLight':
        coverLight = value.clamp(0.6, 1.8);
      case 'glassDepth':
        glassDepth = value.clamp(10, 50);
      case 'glassBlur':
        glassBlur = value.clamp(0, 16);
      case 'animationSpeed':
        animationSpeed = value.clamp(0.5, 2);
      case 'progressGlow':
        progressGlow = value.clamp(0, 1.5);
      case 'playerButtonScale':
        playerButtonScale = value.clamp(0.75, 1.4);
      case 'playerLyricsFontScale':
        playerLyricsFontScale = value.clamp(0.75, 1.5);
    }
    notifyListeners();
  }

  Future<void> resetInterfacePreferences() async {
    hiddenControls = {};
    coverBlur = 48;
    coverLight = 1.2;
    glassDepth = 28;
    glassBlur = 4;
    animationSpeed = 1;
    progressGlow = 0.8;
    playerButtonScale = 1;
    playerLyricsFontScale = 1;
    notifyListeners();
    await saveInterfacePreferences();
  }
}

void openInterfaceSettings(
  BuildContext context,
  AppModel model, {
  bool playerOnly = false,
}) {
  if (!playerOnly) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _RegionSettingsSheet(model: model),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.84,
      child: DefaultTabController(
        length: 2,
        child: AnimatedBuilder(
          animation: model,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        playerOnly ? '播放页自定义' : '自定义',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '恢复默认',
                      onPressed: model.resetInterfacePreferences,
                      icon: const Icon(Icons.restart_alt),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              _InterfacePreview(model: model, region: 'player', height: 280),
              const TabBar(
                tabs: [
                  Tab(text: '按钮'),
                  Tab(text: '动效'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (!playerOnly) ...[
                          const SettingsSectionTitle(
                            title: '迷你播放条',
                            icon: Icons.music_note_outlined,
                          ),
                          for (final entry in playerControlLabels.entries.where(
                            (entry) => entry.key.startsWith('mini.'),
                          ))
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              value: model.controlVisible(entry.key),
                              onChanged: (value) =>
                                  model.setControlVisible(entry.key, value),
                            ),
                        ],
                        const SettingsSectionTitle(
                          title: '播放页',
                          icon: Icons.play_circle_outline,
                        ),
                        for (final entry in playerControlLabels.entries.where(
                          (entry) => entry.key.startsWith('player.'),
                        ))
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.value),
                            value: model.controlVisible(entry.key),
                            onChanged: (value) =>
                                model.setControlVisible(entry.key, value),
                          ),
                        _EffectSlider(
                          model: model,
                          name: 'playerButtonScale',
                          label: '按钮大小',
                          value: model.playerButtonScale,
                          min: 0.75,
                          max: 1.4,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'playerLyricsFontScale',
                          label: '歌词字号',
                          value: model.playerLyricsFontScale,
                          min: 0.75,
                          max: 1.5,
                        ),
                      ],
                    ),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _EffectSlider(
                          model: model,
                          name: 'coverBlur',
                          label: '封面模糊',
                          value: model.coverBlur,
                          min: 24,
                          max: 80,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'coverLight',
                          label: '封面感光',
                          value: model.coverLight,
                          min: 0.6,
                          max: 1.8,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'glassDepth',
                          label: '玻璃折射厚度',
                          value: model.glassDepth,
                          min: 10,
                          max: 50,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'glassBlur',
                          label: '玻璃磨砂',
                          value: model.glassBlur,
                          min: 0,
                          max: 16,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'animationSpeed',
                          label: '动效速度',
                          value: model.animationSpeed,
                          min: 0.5,
                          max: 2,
                        ),
                        _EffectSlider(
                          model: model,
                          name: 'progressGlow',
                          label: '进度光效',
                          value: model.progressGlow,
                          min: 0,
                          max: 1.5,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RegionSettingsSheet extends StatefulWidget {
  const _RegionSettingsSheet({required this.model});
  final AppModel model;

  @override
  State<_RegionSettingsSheet> createState() => _RegionSettingsSheetState();
}

class _RegionSettingsSheetState extends State<_RegionSettingsSheet> {
  String? _region;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    const regions = [
      ('home', '首页', Icons.home_outlined),
      ('library', '歌单', Icons.library_music_outlined),
      ('settings', '设置', Icons.settings_outlined),
      ('lyrics', '歌词', Icons.lyrics_outlined),
    ];
    final title = regions.where((entry) => entry.$1 == _region).firstOrNull?.$2;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                children: [
                  if (_region != null)
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => setState(() => _region = null),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title ?? '自定义',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            _InterfacePreview(
              model: model,
              region: _region ?? 'home',
              height: 240,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                child: ListView(
                  key: ValueKey(_region ?? 'regions'),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: _region == null
                      ? [
                          for (final entry in regions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(8),
                                child: ListTile(
                                  leading: Icon(entry.$3),
                                  title: Text(entry.$2),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      setState(() => _region = entry.$1),
                                ),
                              ),
                            ),
                        ]
                      : [
                          for (final entry
                              in regionTextLabels[_region]!.entries)
                            SwitchListTile(
                              title: Text(entry.value),
                              value: model.regionTextVisible(
                                '$_region.${entry.key}',
                              ),
                              onChanged: (value) => model.setRegionTextVisible(
                                '$_region.${entry.key}',
                                value,
                              ),
                            ),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterfacePreview extends StatelessWidget {
  const _InterfacePreview({
    required this.model,
    required this.region,
    required this.height,
  });
  final AppModel model;
  final String region;
  final double height;

  @override
  Widget build(BuildContext context) {
    final page = switch (region) {
      'home' => HomePage(model: model),
      'library' => LibraryPage(model: model),
      'settings' => MinePage(model: model),
      _ => SongDetailPage(
        model: model,
        song: model.displayPlayer.asMirrorItem(),
        previewStyle: region == 'lyrics' ? 0 : model.lyricsPlayerStyle,
      ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewHeight = min(height, constraints.maxWidth * 1.9);
        final tab = switch (region) {
          'library' => 1,
          'settings' => 2,
          _ => 0,
        };
        final previewPage = region == 'player' || region == 'lyrics'
            ? page
            : Scaffold(
                body: SafeArea(child: page),
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (model.showPlayerBar) PlayerBar(model: model),
                    model.visualStyle == 'liquid'
                        ? LiquidSurface(
                            model: model,
                            child: SizedBox(
                              height: model.iconOnlyNavigation ? 50 : 64,
                              child: Row(
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Expanded(
                                      child: _GlassNavigationItem(
                                        index: i,
                                        selected: tab == i,
                                        iconOnly: model.iconOnlyNavigation,
                                        onTap: () {},
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : NavigationBar(
                            height: model.iconOnlyNavigation ? 54 : 64,
                            selectedIndex: tab,
                            onDestinationSelected: (_) {},
                            labelBehavior: model.iconOnlyNavigation
                                ? NavigationDestinationLabelBehavior.alwaysHide
                                : NavigationDestinationLabelBehavior.alwaysShow,
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.home),
                                label: '首页',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.library_music),
                                label: '歌单',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.person),
                                label: '我的',
                              ),
                            ],
                          ),
                  ],
                ),
              );
        return Center(
          child: SizedBox(
            width: previewHeight / 1.9,
            height: previewHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: 360,
                  height: 684,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: const Size(360, 684),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            if (model.visualStyle == 'liquid')
                              Positioned.fill(
                                child: AlbumFlowBackground(model: model),
                              ),
                            previewPage,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EffectSlider extends StatelessWidget {
  const _EffectSlider({
    required this.model,
    required this.name,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
  });
  final AppModel model;
  final String name;
  final String label;
  final double value;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.toStringAsFixed(max <= 2 ? 1 : 0)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (value) => model.updateEffect(name, value),
          onChangeEnd: (_) => model.saveInterfacePreferences(),
        ),
      ],
    ),
  );
}

void openUiColorSettings(BuildContext context, AppModel model) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.86,
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          final theme = Theme.of(context);
          final textColor = model.uiTextFollowsDynamic
              ? theme.colorScheme.onSurface
              : model.uiFixedTextColor;
          final iconColor = model.uiIconFollowsDynamic
              ? theme.colorScheme.primary
              : model.uiFixedIconColor;
          final progressColor = model.progressColor(theme);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('界面颜色', style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.music_note, color: iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            model.displayPlayer.hasSong
                                ? model.displayPlayer.title
                                : '正在播放',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                            ),
                          ),
                        ),
                        Icon(Icons.play_arrow, color: iconColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.42,
                      color: progressColor,
                      backgroundColor: progressColor.withValues(alpha: 0.16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    for (final role in ['text', 'icon', 'progress']) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (role) {
                          'text' => '文字',
                          'icon' => '图标',
                          _ => '进度',
                        }),
                        subtitle: const Text('跟随封面取色'),
                        value: switch (role) {
                          'text' => model.uiTextFollowsDynamic,
                          'icon' => model.uiIconFollowsDynamic,
                          _ => model.uiProgressFollowsDynamic,
                        },
                        onChanged: (value) =>
                            model.setUiRoleColor(role, followDynamic: value),
                      ),
                      _DesktopLyricsColorPicker(
                        label: '固定颜色',
                        selectedColor: switch (role) {
                          'text' => model.uiFixedTextColor,
                          'icon' => model.uiFixedIconColor,
                          _ => model.uiFixedProgressColor,
                        },
                        enabled: switch (role) {
                          'text' => !model.uiTextFollowsDynamic,
                          'icon' => !model.uiIconFollowsDynamic,
                          _ => !model.uiProgressFollowsDynamic,
                        },
                        disabledLabel: '跟随封面',
                        onChanged: (value) =>
                            model.setUiRoleColor(role, fixedColor: value),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class CoverGlowBackground extends StatelessWidget {
  const CoverGlowBackground({
    required this.model,
    required this.coverUrl,
    super.key,
  });
  final AppModel model;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final light = model.coverLight;
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: model.visualStyle == 'liquid'
                  ? Colors.transparent
                  : theme.colorScheme.surface,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              child: coverUrl.isNotEmpty && model.showSongCovers
                  ? Transform.scale(
                      key: ValueKey(coverUrl),
                      scale: 1.35,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: model.coverBlur,
                          sigmaY: model.coverBlur,
                        ),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: CoverImage(
                            url: coverUrl,
                            identity: coverUrl,
                            decodeSize: 128,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.expand(key: ValueKey('no-cover')),
            ),
            ColoredBox(
              color: (dark ? Colors.black : Colors.white).withValues(
                alpha: model.coverFirstBackground
                    ? (dark ? 0.16 : 0.42)
                    : (dark ? 0.36 : 0.76),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
