part of '../main.dart';

class MinePage extends StatelessWidget {
  const MinePage({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: '我的',
      children: [
        const SettingsSectionTitle(title: '账号'),
        AccountCard(model: model),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.login,
          title: '登录',
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: () => unawaited(
                  model.accountActive
                      ? model.startFreshLogin()
                      : model.openLoginGate(),
                ),
                child: Text(model.accountActive ? '重登' : '登录'),
              ),
              if (model.accountActive)
                OutlinedButton(
                  onPressed: () => unawaited(model.logout()),
                  child: const Text('退出'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.verified_user_outlined,
          title: '保存登录状态',
          trailing: Switch(
            value: model.rememberLogin,
            onChanged: (value) => unawaited(model.setRememberLogin(value)),
          ),
        ),
        const SettingsSectionTitle(title: '界面'),
        ThemeModeSettingsTile(model: model),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.palette_outlined,
          title: '动态取色',
          trailing: Switch(
            value: model.dynamicColorEnabled,
            onChanged: (value) =>
                unawaited(model.setDynamicColorEnabled(value)),
          ),
        ),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.image_outlined,
          title: '显示歌曲封面',
          trailing: Switch(
            value: model.showSongCovers,
            onChanged: (value) => unawaited(model.setShowSongCovers(value)),
          ),
        ),
        const SettingsSectionTitle(title: '播放'),
        AudioQualitySettingsTile(model: model),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.queue_play_next_outlined,
          title: '同时播放',
          trailing: Switch(
            value: model.allowMixedAudio,
            onChanged: (value) => unawaited(model.setAllowMixedAudio(value)),
          ),
        ),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.subtitles_outlined,
          title: '桌面歌词',
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '桌面歌词设置',
                onPressed: () => _openDesktopLyricsSheet(context, model),
                icon: const Icon(Icons.tune),
              ),
              Switch(
                value: model.desktopLyricsEnabled,
                onChanged: (value) =>
                    unawaited(model.setDesktopLyricsEnabled(value)),
              ),
            ],
          ),
        ),
        const SettingsSectionTitle(title: '数据'),
        SettingsTile(
          icon: Icons.sync,
          title: '刷新内容',
          trailing: IconButton.filledTonal(
            onPressed: model.syncHomeAndLibrary,
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SizedBox(height: 10),
        SettingsTile(
          icon: Icons.cleaning_services_outlined,
          title: '清除缓存',
          trailing: IconButton.filledTonal(
            tooltip: '清除缓存',
            onPressed: () => _confirmClearCache(context, model),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ),
        const SettingsSectionTitle(title: '关于'),
        SettingsTile(
          icon: Icons.info_outline,
          title: '关于 EmoC',
          trailing: IconButton.filledTonal(
            tooltip: '软件信息',
            onPressed: () => _openAboutSheet(context, model),
            icon: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }
}

void _openDesktopLyricsSheet(BuildContext context, AppModel model) {
  var opacity = model.desktopLyricsOpacity;
  var fontSize = model.desktopLyricsFontSize;
  var fontWeight = model.desktopLyricsFontWeight;
  var locked = model.desktopLyricsLocked;
  var multiLine = model.desktopLyricsMultiLine;
  var centerLineLocked = model.desktopLyricsCenterLineLocked;
  var autoHideInForeground = model.desktopLyricsAutoHideInForeground;
  var autoHideWhenPaused = model.desktopLyricsAutoHideWhenPaused;
  var followDynamicColor = model.desktopLyricsFollowDynamicColor;
  var backgroundColor = model.desktopLyricsBackgroundColor;
  var textColor = model.desktopLyricsTextColor;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setState) {
          void update({
            double? nextOpacity,
            double? nextFontSize,
            int? nextFontWeight,
            bool? nextLocked,
            bool? nextMultiLine,
            bool? nextCenterLineLocked,
            bool? nextAutoHideInForeground,
            bool? nextAutoHideWhenPaused,
            bool? nextFollowDynamicColor,
            Color? nextBackgroundColor,
            Color? nextTextColor,
          }) {
            setState(() {
              opacity = nextOpacity ?? opacity;
              fontSize = nextFontSize ?? fontSize;
              fontWeight = nextFontWeight ?? fontWeight;
              locked = nextLocked ?? locked;
              multiLine = nextMultiLine ?? multiLine;
              centerLineLocked = nextCenterLineLocked ?? centerLineLocked;
              autoHideInForeground =
                  nextAutoHideInForeground ?? autoHideInForeground;
              autoHideWhenPaused = nextAutoHideWhenPaused ?? autoHideWhenPaused;
              followDynamicColor = nextFollowDynamicColor ?? followDynamicColor;
              backgroundColor = nextBackgroundColor ?? backgroundColor;
              textColor = nextTextColor ?? textColor;
            });
            unawaited(
              model.updateDesktopLyricsSettings(
                opacity: opacity,
                fontSize: fontSize,
                fontWeight: fontWeight,
                locked: locked,
                multiLine: multiLine,
                centerLineLocked: centerLineLocked,
                autoHideInForeground: autoHideInForeground,
                autoHideWhenPaused: autoHideWhenPaused,
                followDynamicColor: followDynamicColor,
                backgroundColor: backgroundColor,
                textColor: textColor,
              ),
            );
          }

          final previewLines = multiLine ? 'Emoc正在播放\nEmoc正在播放' : 'Emoc正在播放';
          final previewColor = followDynamicColor && model.dynamicColorEnabled
              ? model.themeSeedColor
              : backgroundColor;
          final previewTextColor =
              followDynamicColor && model.dynamicColorEnabled
              ? _desktopLyricsPreviewTextColor(model.themeSeedColor)
              : textColor;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.86,
            ),
            child: SingleChildScrollView(
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
                  Text(
                    '桌面歌词',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _withPreviewOpacity(previewColor, opacity),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      previewLines,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      maxLines: multiLine ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: previewTextColor,
                        fontSize: fontSize,
                        height: 1.32,
                        fontWeight: _fontWeightFromValue(fontWeight),
                        shadows: const [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DesktopLyricsSlider(
                    label: '背景透明度',
                    value: opacity,
                    min: 0,
                    max: 0.85,
                    divisions: 17,
                    displayValue: '${(opacity * 100).round()}%',
                    onChanged: (value) => update(nextOpacity: value),
                  ),
                  const SizedBox(height: 8),
                  _DesktopLyricsSlider(
                    label: '字体大小',
                    value: fontSize,
                    min: 14,
                    max: 32,
                    divisions: 18,
                    displayValue: fontSize.round().toString(),
                    onChanged: (value) => update(nextFontSize: value),
                  ),
                  const SizedBox(height: 8),
                  _DesktopLyricsSlider(
                    label: '字体粗细',
                    value: fontWeight.toDouble(),
                    min: 300,
                    max: 900,
                    divisions: 6,
                    displayValue: fontWeight.toString(),
                    onChanged: (value) => update(nextFontWeight: value.round()),
                  ),
                  const SizedBox(height: 10),
                  _DesktopLyricsColorPicker(
                    label: '背景颜色',
                    selectedColor: backgroundColor,
                    enabled: !followDynamicColor,
                    disabledLabel: '动态取色',
                    onChanged: (color) => update(nextBackgroundColor: color),
                  ),
                  const SizedBox(height: 10),
                  _DesktopLyricsColorPicker(
                    label: '歌词颜色',
                    selectedColor: textColor,
                    enabled: !followDynamicColor,
                    disabledLabel: '动态取色',
                    onChanged: (color) => update(nextTextColor: color),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('锁定桌面歌词'),
                    value: locked,
                    onChanged: (value) => update(nextLocked: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('固定在中垂线'),
                    value: centerLineLocked,
                    onChanged: (value) => update(nextCenterLineLocked: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('前台自动隐藏'),
                    value: autoHideInForeground,
                    onChanged: (value) =>
                        update(nextAutoHideInForeground: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('暂停播放时自动隐藏'),
                    value: autoHideWhenPaused,
                    onChanged: (value) => update(nextAutoHideWhenPaused: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('跟随动态取色'),
                    value: followDynamicColor,
                    onChanged: (value) => update(nextFollowDynamicColor: value),
                  ),
                  const SizedBox(height: 4),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('一句')),
                      ButtonSegment(value: true, label: Text('多句')),
                    ],
                    selected: {multiLine},
                    showSelectedIcon: false,
                    onSelectionChanged: (next) {
                      if (next.isEmpty) return;
                      update(nextMultiLine: next.first);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _DesktopLyricsSlider extends StatelessWidget {
  const _DesktopLyricsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DesktopLyricsColorPicker extends StatelessWidget {
  const _DesktopLyricsColorPicker({
    required this.label,
    required this.selectedColor,
    required this.enabled,
    required this.disabledLabel,
    required this.onChanged,
  });

  final String label;
  final Color selectedColor;
  final bool enabled;
  final String disabledLabel;
  final ValueChanged<Color> onChanged;

  static const _colors = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFE5ECFF),
    Color(0xFF000000),
    Color(0xFF1E293B),
    Color(0xFF3F7BFF),
    Color(0xFF14B8A6),
    Color(0xFF7C3AED),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              enabled ? '手动' : disabledLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in _colors)
              _DesktopLyricsColorDot(
                color: color,
                selected:
                    selectedColor.toARGB32() == color.toARGB32() && enabled,
                enabled: enabled,
                onTap: () => onChanged(color),
              ),
          ],
        ),
      ],
    );
  }
}

class _DesktopLyricsColorDot extends StatelessWidget {
  const _DesktopLyricsColorDot({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.42,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: enabled ? 0.22 : 0),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

FontWeight _fontWeightFromValue(int value) {
  if (value >= 850) return FontWeight.w900;
  if (value >= 750) return FontWeight.w800;
  if (value >= 650) return FontWeight.w700;
  if (value >= 550) return FontWeight.w600;
  if (value >= 450) return FontWeight.w500;
  if (value >= 350) return FontWeight.w400;
  return FontWeight.w300;
}

Color _withPreviewOpacity(Color color, double opacity) {
  final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
  return Color((alpha << 24) | (color.toARGB32() & 0x00FFFFFF));
}

Color _desktopLyricsPreviewTextColor(Color seed) {
  final hsl = HSLColor.fromColor(seed);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.62, 0.92).toDouble())
      .withLightness(0.82)
      .toColor();
}

class ThemeModeSettingsTile extends StatelessWidget {
  const ThemeModeSettingsTile({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contrast, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '界面主题',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.phone_android),
                  label: Text('系统'),
                ),
                ButtonSegment(
                  value: 'light',
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
              ],
              selected: {model.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                unawaited(model.setThemeMode(next.first));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AudioQualitySettingsTile extends StatelessWidget {
  const AudioQualitySettingsTile({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.high_quality_outlined,
      title: '播放音质',
      trailing: FilledButton.tonal(
        onPressed: () => _openAudioQualitySheet(context, model),
        child: Text(_audioQualityLabel(model.audioQuality)),
      ),
    );
  }
}

const _audioQualityOptions = <({String value, String label})>[
  (value: 'standard', label: '标准'),
  (value: 'higher', label: '较高'),
  (value: 'exhigh', label: '极高'),
  (value: 'lossless', label: '无损'),
];

String _audioQualityLabel(String value) {
  for (final option in _audioQualityOptions) {
    if (option.value == value) return option.label;
  }
  return '较高';
}

void _openAudioQualitySheet(BuildContext context, AppModel model) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          MediaQuery.viewPaddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '播放音质',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final option in _audioQualityOptions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                title: Text(option.label),
                trailing: model.audioQuality == option.value
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(model.setAudioQuality(option.value));
                },
              ),
          ],
        ),
      );
    },
  );
}

void _confirmClearCache(BuildContext context, AppModel model) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清除缓存'),
      content: const Text('将清除首页、歌单、播放卡片和播放列表缓存，不会退出账号。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(model.clearCache());
          },
          child: const Text('清除'),
        ),
      ],
    ),
  );
}

const _projectUrl = 'https://github.com/yufenghub/EmoC';
const _appVersionLabel = '1.0.4';

void _openAboutSheet(BuildContext context, AppModel model) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EmoC',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '第三方、免费的 Android 音乐客户端',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'EmoC 使用 Flutter 和 Kotlin 构建，提供移动端歌单、搜索、播放控制、歌词、桌面歌词和系统媒体控件集成。'
                '本软件不是网易云音乐官方产品，不提供或托管音乐内容。'
                '应用依赖用户自己的 music.163.com 官网会话，部分功能会调用网易云音乐网页端接口以及第三方社区常见的兼容接口路径。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('版本'),
                subtitle: const Text(_appVersionLabel),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: const Text('项目链接'),
                subtitle: const Text(_projectUrl),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => unawaited(model.openExternalLink(_projectUrl)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('隐私说明'),
                subtitle: const Text('说明本地缓存、账号会话和第三方服务请求'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openPrivacyDialog(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('免责条款'),
                subtitle: const Text('第三方免费项目，与网易云音乐官方无隶属关系'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openDisclaimerDialog(context),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openPrivacyDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('隐私说明'),
      content: const SingleChildScrollView(
        child: Text(
          'EmoC 不运营独立分析后台，不出售、出租或独立变现用户数据。\n\n'
          '软件会在本机保存登录状态、播放列表缓存、歌词缓存、主题设置、桌面歌词设置和播放偏好，用于提升启动速度和恢复使用状态。\n\n'
          '账号、搜索、歌单、歌词、封面和播放相关请求依赖用户自己的 music.163.com 官网会话、网易云音乐网页端接口以及第三方社区常见的兼容接口路径。这些接口并非 EmoC 提供，也不是网易云音乐开放平台商业授权 API。\n\n'
          '桌面歌词悬浮窗权限只会在你开启桌面歌词功能时申请。',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

void _openDisclaimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('免责条款'),
      content: const SingleChildScrollView(
        child: Text(
          'EmoC 是第三方、免费的开源项目，与网易云音乐官方无隶属、授权、赞助或合作关系。\n\n'
          '本项目部分功能依赖用户自己的 music.163.com 官网会话、网易云音乐网页端接口以及第三方社区常见的兼容接口路径，仅供个人学习研究和互操作验证使用，禁止用于商业及非法用途。\n\n'
          '音乐内容、歌词、封面、账号服务、商标和相关权利归网易云音乐及对应权利方所有。EmoC 不提供、上传、托管、镜像或分发受版权保护的音乐内容，也不提供绕过会员、版权、账号、地区或平台限制的能力。\n\n'
          '请遵守所在地法律法规、平台服务条款和内容权利要求。账号风控、账号限制、账号封禁、服务不可用、版权风险和其他使用风险由使用者自行承担。\n\n'
          '本软件按现状提供，不承诺第三方服务的登录、播放、搜索、歌词或封面长期可用。',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  const AccountCard({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.visibleAccountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model.accountActive ? '账号已登录' : '未登录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
