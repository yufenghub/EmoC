part of '../main.dart';

Future<void>? _glassInitialization;
Future<void> _initializeGlass() => _glassInitialization ??=
    glass.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);

glass.LiquidGlassSettings _glassSettings(
  BuildContext context,
  AppModel model,
) => glass.LiquidGlassSettings(
  thickness: model.glassDepth,
  blur: model.glassBlur,
  glassColor: Color.lerp(
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0x10FFFFFF)
        : const Color(0x20FFFFFF),
    model.themeSeedColor.withValues(alpha: 0.10),
    0.32,
  )!,
  refractiveIndex: 1.2,
  chromaticAberration: 0.03,
  lightIntensity: 0,
  ambientStrength: 0,
  ambientRim: 0,
  glowIntensity: 0,
  shadowElevation: 0,
  fresnelStrength: 0,
  saturation: 1.25,
);

extension AppearanceActions on AppModel {
  Future<void> setAppearance({String? style, int? motion}) async {
    if (style != null) visualStyle = style == 'liquid' ? 'liquid' : 'simple';
    if (motion != null) motionLevel = motion.clamp(0, 2);
    if (visualStyle == 'liquid') motionLevel = 2;
    if (visualStyle == 'liquid') unawaited(_initializeGlass());
    notifyListeners();
    await NativeBridge.setString('visualStyle', visualStyle);
    await NativeBridge.setString('motionLevel', '$motionLevel');
  }
}

ThemeData liquidTheme(Brightness brightness, {Color? dynamicSeed}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: dynamicSeed ?? const Color(0xFF258C79),
        brightness: brightness,
      ).copyWith(
        primary: dynamicSeed == null
            ? (dark ? const Color(0xFFA8E7C9) : const Color(0xFF126754))
            : null,
        secondary: dark ? const Color(0xFFFFAFAB) : const Color(0xFF9C414A),
        tertiary: dark ? const Color(0xFFD9E997) : const Color(0xFF586915),
        surface: dark ? const Color(0xFF121B1A) : const Color(0xFFF1F8F5),
        onSurface: dark ? const Color(0xFFF1F7F4) : const Color(0xFF14231F),
      );
  return ThemeData(useMaterial3: true, colorScheme: scheme).copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    cardTheme: EmoCTheme._cardTheme(scheme.surface.withValues(alpha: 0.78)),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: 0.20),
      backgroundColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: dark ? 0.22 : 0.16)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.onSurface.withValues(alpha: 0.16)),
        ),
      ),
    ),
    dividerColor: scheme.onSurface.withValues(alpha: 0.12),
  );
}

class AppearanceSettingsTile extends StatelessWidget {
  const AppearanceSettingsTile({required this.model, super.key});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final showLabels = model.regionTextVisible('settings.labels');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCardSurface(
        model: model,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: showLabels ? const Text('外观风格') : null,
              ),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'simple',
                    icon: const Icon(Icons.crop_square),
                    label: showLabels ? const Text('简约') : null,
                  ),
                  ButtonSegment(
                    value: 'liquid',
                    icon: const Icon(Icons.blur_on),
                    label: showLabels ? const Text('华丽') : null,
                  ),
                ],
                selected: {model.visualStyle},
                onSelectionChanged: (values) =>
                    model.setAppearance(style: values.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidSurface extends StatelessWidget {
  const LiquidSurface({
    required this.model,
    required this.child,
    this.quality = glass.GlassQuality.standard,
    this.borderRadius = 8,
    this.useOwnLayer = true,
    super.key,
  });
  final AppModel model;
  final Widget child;
  final glass.GlassQuality quality;
  final double borderRadius;
  final bool useOwnLayer;

  @override
  Widget build(BuildContext context) {
    return glass.GlassContainer(
      settings: useOwnLayer ? _glassSettings(context, model) : null,
      quality: quality,
      useOwnLayer: useOwnLayer,
      shape: glass.LiquidRoundedRectangle(borderRadius: borderRadius),
      child: child,
    );
  }
}

class AlbumFlowBackground extends StatefulWidget {
  const AlbumFlowBackground({required this.model, super.key});
  final AppModel model;

  @override
  State<AlbumFlowBackground> createState() => _AlbumFlowBackgroundState();
}

class _AlbumFlowBackgroundState extends State<AlbumFlowBackground>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static Future<ui.FragmentProgram>? _program;
  static ui.FragmentProgram? _resolvedProgram;
  static ui.Image? _lastArtwork;
  static String? _lastCover;
  final _clock = ValueNotifier<double>(0);
  Timer? _timer;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  ui.Image? _previousImage;
  late final AnimationController _artworkTransition;
  String? _cover;
  int _generation = 0;
  bool _foreground = true;
  bool _dependenciesReady = false;
  bool? _lastCoverFirst;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.model.addListener(_update);
    widget.model.playbackRevision.addListener(_update);
    if (_resolvedProgram != null) _shader = _resolvedProgram!.fragmentShader();
    if (_lastArtwork != null) _image = _lastArtwork!.clone();
    _artworkTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1,
    );
    if (_shader == null) unawaited(_loadProgram());
    _update();
  }

  Future<void> _loadProgram() async {
    try {
      final program = await (_program ??= ui.FragmentProgram.fromAsset(
        'shaders/album_flow.frag',
      ));
      _resolvedProgram = program;
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (error) {
      debugPrint('Album flow shader unavailable: $error');
    }
  }

  void _update() {
    if (_lastCoverFirst != widget.model.coverFirstBackground) {
      _lastCoverFirst = widget.model.coverFirstBackground;
      if (mounted) setState(() {});
    }
    final player = widget.model.displayPlayer;
    final cover = widget.model.showSongCovers
        ? (player.coverUrl.isNotEmpty
              ? player.coverUrl
              : widget.model.coverFor(player.asMirrorItem()))
        : '';
    if (cover != _cover) {
      _cover = cover;
      if (_image == null || cover != _lastCover) {
        unawaited(_loadArtwork(cover, ++_generation));
      }
    }
    if (_dependenciesReady && mounted) _syncClock();
  }

  Future<void> _loadArtwork(String cover, int generation) async {
    ui.Image? next;
    try {
      Uint8List? bytes;
      if (cover.startsWith('file:')) {
        final file = File.fromUri(Uri.parse(cover));
        if (await file.length() <= 3 << 20) bytes = await file.readAsBytes();
      } else if (cover.startsWith('http')) {
        bytes = (await CoverRuntimeCache.instance.load([cover]))?.bytes;
      }
      if (bytes != null) {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 8,
          targetHeight: 8,
        );
        try {
          next = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
    } on Exception catch (error) {
      debugPrint('Album flow artwork unavailable: $error');
    }
    if (next == null) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const colors = [
        Color(0xFF246D60),
        Color(0xFFD49097),
        Color(0xFFAFBD66),
        Color(0xFF468C96),
      ];
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH((i % 2).toDouble(), (i ~/ 2).toDouble(), 1, 1),
          Paint()..color = colors[i],
        );
      }
      final picture = recorder.endRecording();
      next = await picture.toImage(2, 2);
      picture.dispose();
    }
    if (!mounted || generation != _generation) {
      next.dispose();
      return;
    }
    _lastArtwork?.dispose();
    _lastArtwork = next.clone();
    _lastCover = cover;
    _previousImage?.dispose();
    _previousImage = _image;
    setState(() => _image = next);
    if (_previousImage != null) {
      _artworkTransition.forward(from: 0);
    } else {
      _artworkTransition.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dependenciesReady = true;
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
  }

  void _syncClock() {
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    final animate =
        _foreground &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.valuesOf(context).enabled &&
        !(media?.disableAnimations ?? true) &&
        widget.model.motionLevel > 0 &&
        widget.model.displayPlayer.playing;
    final interval = widget.model.motionLevel == 2 ? 32 : 50;
    if (!animate) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null && _interval == interval) return;
    _timer?.cancel();
    _interval = interval;
    _timer = Timer.periodic(Duration(milliseconds: interval), (_) {
      _clock.value += interval / 1000 * widget.model.animationSpeed;
    });
  }

  int _interval = 33;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.model.removeListener(_update);
    widget.model.playbackRevision.removeListener(_update);
    _timer?.cancel();
    _artworkTransition.dispose();
    _clock.dispose();
    _shader?.dispose();
    _previousImage?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: _shader == null || _image == null
          ? ColoredBox(color: Theme.of(context).colorScheme.surface)
          : CustomPaint(
              painter: _AlbumFlowPainter(
                _shader!,
                _image!,
                _previousImage ?? _image!,
                _clock,
                _artworkTransition,
                dark,
                widget.model.coverFirstBackground,
              ),
              size: Size.infinite,
            ),
    );
  }
}

class _AlbumFlowPainter extends CustomPainter {
  _AlbumFlowPainter(
    this.shader,
    this.image,
    this.previousImage,
    this.clock,
    this.artworkTransition,
    this.dark,
    this.coverFirst,
  ) : super(repaint: Listenable.merge([clock, artworkTransition]));
  final ui.FragmentShader shader;
  final ui.Image image;
  final ui.Image previousImage;
  final ValueNotifier<double> clock;
  final AnimationController artworkTransition;
  final bool dark;
  final bool coverFirst;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, clock.value)
      ..setFloat(3, dark ? 1 : 0)
      ..setFloat(4, coverFirst ? 1 : 0)
      ..setFloat(5, Curves.easeInOutCubic.transform(artworkTransition.value))
      ..setImageSampler(0, previousImage, filterQuality: FilterQuality.medium)
      ..setImageSampler(1, image, filterQuality: FilterQuality.medium);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AlbumFlowPainter old) =>
      old.image != image ||
      old.previousImage != previousImage ||
      old.shader != shader ||
      old.dark != dark ||
      old.coverFirst != coverFirst;
}
