part of '../main.dart';

class EmoCApp extends StatefulWidget {
  const EmoCApp({
    required this.model,
    required this.preferencesRestored,
    super.key,
  });

  final AppModel model;
  final bool preferencesRestored;

  @override
  State<EmoCApp> createState() => _EmoCAppState();
}

class _EmoCAppState extends State<EmoCApp> with WidgetsBindingObserver {
  late final AppModel model;
  late final AppThemeState themeState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model = widget.model;
    themeState = AppThemeState(model);
    unawaited(model.init(preferencesRestored: widget.preferencesRestored));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(model.refreshVisualStateAfterResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeState.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeState,
      builder: (context, _) {
        final appThemeMode = switch (model.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return AppScope(
          model: model,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'EmoC',
            theme: applyUiColors(
              model.visualStyle == 'liquid'
                  ? liquidTheme(
                      Brightness.light,
                      dynamicSeed: model.dynamicColorEnabled
                          ? model.themeSeedColor
                          : null,
                    )
                  : EmoCTheme.light(model.themeSeedColor),
              model,
            ),
            darkTheme: applyUiColors(
              model.visualStyle == 'liquid'
                  ? liquidTheme(
                      Brightness.dark,
                      dynamicSeed: model.dynamicColorEnabled
                          ? model.themeSeedColor
                          : null,
                    )
                  : EmoCTheme.dark(model.themeSeedColor),
              model,
            ),
            themeMode: appThemeMode,
            themeAnimationDuration: const Duration(milliseconds: 240),
            themeAnimationCurve: Curves.easeInOutCubic,
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              final overlayStyle = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                statusBarIconBrightness: brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarIconBrightness: brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
                systemStatusBarContrastEnforced: false,
              );
              return ScrollConfiguration(
                behavior: const _NoScrollbarBehavior(),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations:
                          model.motionLevel == 0 ||
                          MediaQuery.disableAnimationsOf(context),
                    ),
                    child: model.visualStyle == 'liquid'
                        ? glass.GlassPage(
                            settings: _glassSettings(context, model),
                            background: ValueListenableBuilder<int>(
                              valueListenable: _secondaryPageDepth,
                              builder: (context, depth, _) => TickerMode(
                                enabled: depth == 0,
                                child: ExcludeSemantics(
                                  child: AlbumFlowBackground(model: model),
                                ),
                              ),
                            ),
                            child: child ?? const SizedBox.shrink(),
                          )
                        : child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            home: const AppRoot(),
          ),
        );
      },
    );
  }
}

/// Filters the busy application model down to values that affect MaterialApp.
///
/// Artwork preparation and playback polling can notify [AppModel] many times a
/// second. Rebuilding MaterialApp for those events repeatedly restarts its
/// theme animation, which is especially visible in large playlists.
class AppThemeState extends ChangeNotifier {
  AppThemeState(this.model)
    : _themeMode = model.themeMode,
      _systemDarkMode = model.systemDarkMode,
      _visualStyle = model.visualStyle,
      _motionLevel = model.motionLevel,
      _glassDepth = model.glassDepth,
      _glassBlur = model.glassBlur,
      _seedArgb = model.themeSeedColor.toARGB32(),
      _uiColorKey = _colorKey(model) {
    model.addListener(_handleModelChanged);
  }

  final AppModel model;
  String _themeMode;
  bool _systemDarkMode;
  int _seedArgb;
  String _visualStyle;
  int _motionLevel;
  double _glassDepth;
  double _glassBlur;
  String _uiColorKey;

  static String _colorKey(AppModel model) => [
    model.dynamicColorEnabled,
    model.uiTextFollowsDynamic,
    model.uiIconFollowsDynamic,
    model.uiProgressFollowsDynamic,
    model.uiFixedTextColor.toARGB32(),
    model.uiFixedIconColor.toARGB32(),
    model.uiFixedProgressColor.toARGB32(),
  ].join('|');

  void _handleModelChanged() {
    final nextThemeMode = model.themeMode;
    final nextSystemDarkMode = model.systemDarkMode;
    final nextSeedArgb = model.themeSeedColor.toARGB32();
    final nextUiColorKey = _colorKey(model);
    if (_themeMode == nextThemeMode &&
        _visualStyle == model.visualStyle &&
        _motionLevel == model.motionLevel &&
        _glassDepth == model.glassDepth &&
        _glassBlur == model.glassBlur &&
        _systemDarkMode == nextSystemDarkMode &&
        _seedArgb == nextSeedArgb &&
        _uiColorKey == nextUiColorKey) {
      return;
    }
    _themeMode = nextThemeMode;
    _systemDarkMode = nextSystemDarkMode;
    _seedArgb = nextSeedArgb;
    _uiColorKey = nextUiColorKey;
    _visualStyle = model.visualStyle;
    _motionLevel = model.motionLevel;
    _glassDepth = model.glassDepth;
    _glassBlur = model.glassBlur;
    notifyListeners();
  }

  @override
  void dispose() {
    model.removeListener(_handleModelChanged);
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel model, required super.child, super.key})
    : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }

  static AppModel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final handled = model.handleSystemBack();
          if (!handled) {
            unawaited(model.moveTaskToBack());
          }
        }
      },
      child: Stack(
        children: [
          const MainShell(),
          if (model.loginGateVisible) OfficialLoginGate(model: model),
          AppUpdatePromptCoordinator(model: model),
          Positioned(
            left: 18,
            right: 18,
            top: MediaQuery.paddingOf(context).top + 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
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
                      begin: const Offset(0, -0.38),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: model.noticeMessage.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('notice-empty'))
                  : AppNoticeBanner(
                      key: ValueKey('notice-${model.noticeMessage}'),
                      message: model.noticeMessage,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppNoticeBanner extends StatelessWidget {
  const AppNoticeBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfficialLoginGate extends StatelessWidget {
  const OfficialLoginGate({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '登录网易云音乐',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '默认使用验证码登录，也可以切换到扫码登录。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: model.smsLoginVisible
                              ? QrLoginPanel(
                                  key: const ValueKey('qr-login'),
                                  model: model,
                                )
                              : SmsLoginPanel(
                                  key: const ValueKey('sms-login'),
                                  model: model,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => unawaited(model.enterApp()),
                child: Text(model.accountActive ? '进入应用' : '稍后进入'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrLoginPanel extends StatelessWidget {
  const QrLoginPanel({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 270,
            height: 270,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: model.loginLoading
                ? const Center(child: CircularProgressIndicator())
                : QrProjection(
                    data: model.loginQrData,
                    source: model.loginQrImage,
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          model.loginMessage,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (model.loginMethods.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final method in model.loginMethods)
                ActionChip(
                  label: Text(method),
                  onPressed: () => unawaited(model.selectLoginMethod(method)),
                ),
            ],
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => unawaited(model.refreshLoginQr()),
          icon: const Icon(Icons.refresh),
          label: const Text('刷新二维码'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => unawaited(model.openSmsLogin()),
          child: const Text('返回验证码登录'),
        ),
      ],
    );
  }
}

class SmsLoginPanel extends StatefulWidget {
  const SmsLoginPanel({required this.model, super.key});

  final AppModel model;

  @override
  State<SmsLoginPanel> createState() => _SmsLoginPanelState();
}

class _SmsLoginPanelState extends State<SmsLoginPanel> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '验证码登录',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '手机号',
            prefixIcon: Icon(Icons.phone_android),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: widget.model.smsLoginBusy
                  ? null
                  : () => unawaited(
                      widget.model.sendSmsCode(phoneController.text),
                    ),
              child: const Text('获取'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.model.smsLoginMessage.isNotEmpty)
          Text(
            widget.model.smsLoginMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: widget.model.smsLoginBusy
              ? null
              : () => unawaited(
                  widget.model.loginWithSms(
                    phoneController.text,
                    codeController.text,
                  ),
                ),
          child: widget.model.smsLoginBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('登录'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => unawaited(widget.model.backToQrLogin()),
          child: const Text('扫码登录'),
        ),
      ],
    );
  }
}

class QrProjection extends StatelessWidget {
  const QrProjection({required this.data, required this.source, super.key});

  final String data;
  final String source;

  @override
  Widget build(BuildContext context) {
    if (data.isNotEmpty) {
      return QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 230,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(8),
      );
    }
    if (source.startsWith('data:image')) {
      final bytes = _bytesFromDataUrl(source);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.contain);
      }
    }
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.qr_code_2, size: 120, color: Colors.black54),
      );
    }
    return const Icon(Icons.qr_code_2, size: 120, color: Colors.black54);
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final pages = [
          HomePage(model: model),
          LibraryPage(model: model),
          MinePage(model: model),
        ];
        return Scaffold(
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
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
              child: KeyedSubtree(
                key: ValueKey('tab-${model.tabIndex}'),
                child: pages[model.tabIndex],
              ),
            ),
          ),
          bottomNavigationBar: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
              final bottomGap = bottomInset > 0 ? 6.0 : 0.0;
              final liquid = model.visualStyle == 'liquid';
              if (liquid) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, bottomGap + 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.bottomCenter,
                        child: model.showPlayerBar
                            ? PlayerBar(model: model)
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 5),
                      LiquidSurface(
                        model: model,
                        quality: glass.GlassQuality.premium,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          height: model.iconOnlyNavigation ? 50 : 64,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 420),
                                    curve: const Cubic(0.2, 0.82, 0.24, 1.005),
                                    alignment: Alignment(
                                      model.tabIndex - 1.0,
                                      0,
                                    ),
                                    child: FractionallySizedBox(
                                      widthFactor: 1 / 3,
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          width: model.iconOnlyNavigation
                                              ? 58
                                              : 104,
                                          height: model.iconOnlyNavigation
                                              ? 40
                                              : 54,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.14),
                                            border: Border.all(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.24),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var index = 0; index < 3; index++)
                                    Expanded(
                                      child: _GlassNavigationItem(
                                        index: index,
                                        selected: model.tabIndex == index,
                                        iconOnly: model.iconOnlyNavigation,
                                        onTap: () => model.setTab(index),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final navigation = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return SizeTransition(
                        sizeFactor: curved,
                        alignment: Alignment.topCenter,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.18),
                            end: Offset.zero,
                          ).animate(curved),
                          child: FadeTransition(opacity: curved, child: child),
                        ),
                      );
                    },
                    child: model.showPlayerBar
                        ? PlayerBar(key: const ValueKey('player'), model: model)
                        : const SizedBox.shrink(key: ValueKey('no-player')),
                  ),
                  NavigationBar(
                    height: model.iconOnlyNavigation ? 54 : 64,
                    labelBehavior: model.iconOnlyNavigation
                        ? NavigationDestinationLabelBehavior.alwaysHide
                        : NavigationDestinationLabelBehavior.alwaysShow,
                    backgroundColor: liquid
                        ? Colors.transparent
                        : theme.colorScheme.surface,
                    selectedIndex: model.tabIndex,
                    onDestinationSelected: model.setTab,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: '首页',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music),
                        label: '歌单',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ],
                  ),
                  SizedBox(height: bottomGap),
                ],
              );
              return Material(
                color: theme.colorScheme.surface,
                child: navigation,
              );
            },
          ),
        );
      },
    );
  }
}

class _GlassNavigationItem extends StatelessWidget {
  const _GlassNavigationItem({
    required this.index,
    required this.selected,
    required this.iconOnly,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const labels = ['首页', '歌单', '我的'];
    const icons = [
      Icons.home_outlined,
      Icons.library_music_outlined,
      Icons.person_outline,
    ];
    const activeIcons = [Icons.home, Icons.library_music, Icons.person];
    return Semantics(
      button: true,
      selected: selected,
      label: labels[index],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            constraints: BoxConstraints(
              minWidth: iconOnly ? 46 : 68,
              maxWidth: iconOnly ? 58 : 104,
            ),
            height: iconOnly ? 40 : 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? activeIcons[index] : icons[index],
                  size: 24,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  alignment: Alignment.topCenter,
                  child: iconOnly
                      ? const SizedBox(width: 0, height: 0)
                      : Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            labels[index],
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
