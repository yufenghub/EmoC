part of '../main.dart';

class AppModel extends ChangeNotifier {
  AppModel()
    : systemDarkMode =
          ui.PlatformDispatcher.instance.platformBrightness ==
          ui.Brightness.dark {
    _artworkPipeline = SongArtworkPipeline(this);
    _playlistModule = PlaylistModule(this);
  }

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  WebViewController? webController;
  Timer? _loginTimer;
  Timer? _playerTimer;
  Timer? _searchDebounce;
  Timer? _noticeHideTimer;
  Timer? _themeModeReviewTimer;
  Timer? _dynamicThemeGuardTimer;
  Timer? _desktopLyricsColorReviewTimer;
  Timer? _coverCacheNotifyTimer;
  Timer? _coverCachePersistTimer;
  Timer? _currentPlaylistPersistTimer;
  Timer? _playlistRevealPersistTimer;
  Timer? _autoAdvanceWatchdog;
  bool _dynamicThemeGuardRefreshInProgress = false;
  int _playRequestId = 0;
  int _loginFlowGeneration = 0;
  int _snapshotRequestSerial = 0;
  int _desktopLyricsColorReviewSerial = 0;
  int _themeModeChangeSerial = 0;
  late final SongArtworkPipeline _artworkPipeline;
  late final PlaylistModule _playlistModule;
  final PlaybackOrderController _playbackOrder = PlaybackOrderController();
  String _songDetailRequestKey = '';
  final Map<String, int> _activeSnapshotRequests = <String, int>{};
  final Map<int, Completer<void>> _snapshotWaiters = <int, Completer<void>>{};
  final SmsLoginApiClient _smsLoginApiClient = SmsLoginApiClient();
  final MusicMutationApiClient _musicMutationApiClient =
      MusicMutationApiClient();

  bool ready = false;
  String themeMode = 'system';
  bool systemDarkMode;
  bool loginGateVisible = false;
  bool loggedIn = false;
  bool rememberLogin = true;
  bool loginLoading = false;
  bool smsLoginVisible = false;
  bool smsLoginBusy = false;
  bool dailyLoading = false;
  bool libraryLoading = false;
  bool playlistLoading = false;
  bool searchLoading = false;
  bool songDetailLoading = false;
  bool queueLoading = false;
  bool playerBarVisible = false;
  bool allowMixedAudio = false;
  bool dynamicColorEnabled = false;
  bool showSongCovers = true;
  bool desktopLyricsEnabled = false;
  bool desktopLyricsLocked = false;
  bool desktopLyricsMultiLine = false;
  bool desktopLyricsCenterLineLocked = false;
  bool desktopLyricsAutoHideInForeground = false;
  bool desktopLyricsAutoHideWhenPaused = false;
  bool desktopLyricsFollowDynamicColor = false;
  int tabIndex = 0;

  String status = '正在连接网易云音乐官网';
  String pageUrl = 'https://music.163.com/';
  String accountName = '未登录';
  String avatarUrl = '';
  String loginQrData = '';
  String loginQrImage = '';
  String loginMessage = '验证码登录';
  String smsLoginMessage = '请输入手机号获取验证码';
  String activePlaylistTitle = '';
  String searchQuery = '';
  String noticeMessage = '';
  String audioQuality = 'higher';
  double desiredVolume = 0.7;
  double desktopLyricsOpacity = 0.42;
  double desktopLyricsFontSize = 18;
  int desktopLyricsFontWeight = 800;
  Color themeSeedColor = const Color(0xFF3F7BFF);
  Color desktopLyricsBackgroundColor = Colors.black;
  Color desktopLyricsTextColor = Colors.white;
  int lyricsPlayerStyle = 0;
  int _noticeToken = 0;

  List<String> loginMethods = const [];
  List<MirrorItem> dailySongs = const [];
  List<MirrorItem> libraryPlaylists = const [];
  List<MirrorItem> _libraryPlaylistsBase = const [];
  List<MirrorItem> playlistSongs = const [];
  List<MirrorItem> searchSuggestions = const [];
  List<MirrorItem> searchResults = const [];
  List<MirrorItem> playerQueue = const [];
  List<MirrorItem> currentPlaylist = const [];
  List<SavedAccount> savedAccounts = const [];
  List<String> queueLyricLines = const [];
  List<String> pinnedPlaylistIds = const [];
  final Map<String, List<MirrorItem>> _playlistSongCache =
      <String, List<MirrorItem>>{};
  final Map<String, int> _playlistRevealCounts = <String, int>{};
  Map<String, String> songCoverCache = <String, String>{};
  final Map<String, Future<String>> _songCoverRequests =
      <String, Future<String>>{};
  final List<Completer<void>> _songCoverWaiters = <Completer<void>>[];
  int _activeSongCoverRequests = 0;
  PlayerSnapshot player = PlayerSnapshot.empty;
  final ValueNotifier<int> playbackRevision = ValueNotifier<int>(0);
  PlayerSnapshot _lastPlayerWithSong = PlayerSnapshot.empty;
  PlayerSnapshot? _loginGatePlayerBackup;
  bool _loginGatePlayerBarVisibleBackup = false;
  SongDetail? songDetail;
  MirrorItem? selectedLibraryPlaylist;
  int currentSongIndex = -1;
  bool _modeSwitching = false;
  bool _restoreLoginOnLoad = false;
  bool _trustSavedLogin = false;
  bool? _switchAccountBackupLoggedIn;
  String? _switchAccountBackupName;
  String? _switchAccountBackupAvatarUrl;
  String? _switchAccountBackupCookie;
  bool _nativePlaybackActive = false;
  bool _nativePlaybackPending = false;
  bool _localPauseRequested = false;
  bool _autoAdvanceInProgress = false;
  bool _pendingPreviousNativeActive = false;
  bool _pendingAutoAdvance = false;
  int _pendingSongIndex = -1;
  int _pendingSkipDirection = 1;
  int _autoAdvanceSkipGuard = 0;
  MirrorItem? _pendingSong;
  List<MirrorItem> _pendingPlaylist = const [];
  PlayerSnapshot? _pendingPreviousPlayer;
  DateTime? _seekHoldUntil;
  int? _seekHoldSeconds;
  DateTime? _playIntentHoldUntil;
  bool? _playIntentPlaying;
  final DateTime _startupNoticeSuppressUntil = DateTime.now().add(
    const Duration(seconds: 5),
  );
  String _lastSavedPlayerCacheKey = '';
  String _lastSavedPlaylistCacheKey = '';
  String _dynamicColorCoverUrl = '';
  String _dynamicColorSongId = '';
  String _dynamicColorPendingCoverUrl = '';
  String _dynamicColorPendingRequestKey = '';
  String _dynamicColorQueuedCoverUrl = '';
  String _dynamicColorQueuedSongId = '';
  String _lastDynamicColorRequestKey = '';
  String _dynamicColorFailedCoverUrl = '';
  DateTime? _dynamicColorFailedAt;
  int _dynamicColorSerial = 0;
  Timer? _dynamicColorDebounce;
  final Map<String, Color> _dynamicColorCache = <String, Color>{};
  String _dynamicColorSource = 'daily';
  String _pendingDynamicColorSource = 'daily';
  String _activePlaybackDynamicSource = 'daily';
  String _activePlaybackDynamicSongId = '';
  String _dynamicColorTargetSongId = '';
  String _nativeDynamicColorSongId = '';
  int? _nativeDynamicColorArgb;
  String _playlistDynamicColorSongId = '';
  int? _playlistDynamicColorArgb;
  String _playlistDynamicColorCoverUrl = '';
  int _dynamicColorSourceSerial = 0;
  String _lastDesktopLyricsPayloadKey = '';
  String _lastDesktopLyricsDetailRequestKey = '';
  String _lastDesktopLyricsStyleKey = '';
  DateTime? _desktopLyricsStyleHoldUntil;
  bool _playlistAllowEmptySnapshot = false;

  bool isPlaylistPinned(MirrorItem playlist) =>
      playlist.id.isNotEmpty && pinnedPlaylistIds.contains(playlist.id);

  PlayerSnapshot get displayPlayer =>
      player.hasSong ? player : _lastPlayerWithSong;

  bool get showPlayerBar => playerBarVisible && displayPlayer.hasSong;

  bool get accountActive => loggedIn || _hasRealAccountName(accountName);

  String get visibleAccountName {
    if (_hasRealAccountName(accountName)) return accountName;
    if (accountActive) {
      for (final account in savedAccounts) {
        if (account.hasUsableName) return account.name;
      }
    }
    return accountActive ? '账号已登录' : '未登录';
  }

  bool get useDarkTheme =>
      themeMode == 'dark' || (themeMode == 'system' && systemDarkMode);

  bool get _seekHoldActive {
    final until = _seekHoldUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool get _playIntentHoldActive {
    final until = _playIntentHoldUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  Future<void> init() async {
    NativeBridge.setSystemCommandHandler(_handleSystemMediaCommand);
    try {
      final savedThemeMode = await NativeBridge.getString(
        'themeMode',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (savedThemeMode == 'system' ||
          savedThemeMode == 'light' ||
          savedThemeMode == 'dark') {
        themeMode = savedThemeMode!;
      } else {
        final legacyDarkMode = await NativeBridge.getString(
          'darkMode',
        ).timeout(const Duration(seconds: 2), onTimeout: () => null);
        themeMode = legacyDarkMode == 'true'
            ? 'dark'
            : legacyDarkMode == 'false'
            ? 'light'
            : 'system';
      }
    } catch (_) {
      themeMode = 'system';
    }
    await _refreshSystemThemeFromNative(notify: false);
    try {
      final pinned = await NativeBridge.getString(
        'pinnedPlaylistIds',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      pinnedPlaylistIds = _stringOf(pinned).isEmpty
          ? const []
          : _listOf(jsonDecode(pinned!))
                .map(_stringOf)
                .where((id) => id.isNotEmpty)
                .toList(growable: false);
    } catch (_) {
      pinnedPlaylistIds = const [];
    }
    try {
      dynamicColorEnabled =
          await NativeBridge.getString(
            'dynamicColorEnabled',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      final savedSeed = await NativeBridge.getString(
        'themeSeedColor',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final parsedSeed = int.tryParse(savedSeed ?? '');
      if (dynamicColorEnabled && parsedSeed != null) {
        themeSeedColor = Color(parsedSeed);
      }
    } catch (_) {
      dynamicColorEnabled = false;
      themeSeedColor = const Color(0xFF3F7BFF);
    }
    try {
      showSongCovers =
          await NativeBridge.getString(
            'showSongCovers',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) !=
          'false';
    } catch (_) {
      showSongCovers = true;
    }
    try {
      final savedPlayerStyle = int.tryParse(
        await NativeBridge.getString(
              'lyricsPlayerStyle',
            ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
            '',
      );
      lyricsPlayerStyle = (savedPlayerStyle ?? 0).clamp(0, 2);
    } catch (_) {
      lyricsPlayerStyle = 0;
    }
    try {
      desktopLyricsEnabled =
          await NativeBridge.getString(
            'desktopLyricsEnabled',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsOpacity =
          double.tryParse(
            await NativeBridge.getString(
                  'desktopLyricsOpacity',
                ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
                '',
          )?.clamp(0.0, 0.85).toDouble() ??
          desktopLyricsOpacity;
      desktopLyricsFontSize =
          double.tryParse(
            await NativeBridge.getString(
                  'desktopLyricsFontSize',
                ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
                '',
          )?.clamp(14.0, 32.0).toDouble() ??
          desktopLyricsFontSize;
      desktopLyricsFontWeight =
          int.tryParse(
            await NativeBridge.getString(
                  'desktopLyricsFontWeight',
                ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
                '',
          )?.clamp(300, 900).toInt() ??
          desktopLyricsFontWeight;
      desktopLyricsLocked =
          await NativeBridge.getString(
            'desktopLyricsLocked',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsMultiLine =
          await NativeBridge.getString(
            'desktopLyricsMultiLine',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsCenterLineLocked =
          await NativeBridge.getString(
            'desktopLyricsCenterLineLocked',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsAutoHideInForeground =
          await NativeBridge.getString(
            'desktopLyricsAutoHideInForeground',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsAutoHideWhenPaused =
          await NativeBridge.getString(
            'desktopLyricsAutoHideWhenPaused',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      desktopLyricsFollowDynamicColor =
          await NativeBridge.getString(
            'desktopLyricsFollowDynamicColor',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      final savedDesktopLyricsBackground = await NativeBridge.getString(
        'desktopLyricsBackgroundColor',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final parsedDesktopLyricsBackground = int.tryParse(
        savedDesktopLyricsBackground ?? '',
      );
      if (parsedDesktopLyricsBackground != null) {
        desktopLyricsBackgroundColor = Color(parsedDesktopLyricsBackground);
      }
      final savedDesktopLyricsTextColor = await NativeBridge.getString(
        'desktopLyricsTextColor',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final parsedDesktopLyricsTextColor = int.tryParse(
        savedDesktopLyricsTextColor ?? '',
      );
      if (parsedDesktopLyricsTextColor != null) {
        desktopLyricsTextColor = Color(parsedDesktopLyricsTextColor);
      }
      await _applyDesktopLyricsStyle();
      if (desktopLyricsEnabled) {
        await _restoreDesktopLyricsOverlay();
      }
    } catch (_) {}
    try {
      final savedVolume = await NativeBridge.getString(
        'desiredVolume',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final parsedVolume = double.tryParse(savedVolume ?? '');
      if (parsedVolume != null) {
        desiredVolume = parsedVolume.clamp(0, 1).toDouble();
        if (desiredVolume <= 0.02) desiredVolume = 0.7;
        player = _playerWith(volume: desiredVolume);
      }
    } catch (_) {}
    try {
      final savedAudioQuality = await NativeBridge.getString(
        'audioQuality',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (_validAudioQuality(savedAudioQuality)) {
        audioQuality = savedAudioQuality!;
      }
    } catch (_) {}
    try {
      final savedMode = await NativeBridge.getString(
        'playbackMode',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (_validPlaybackMode(savedMode)) {
        player = _playerWith(mode: savedMode);
      }
    } catch (_) {}
    try {
      allowMixedAudio =
          await NativeBridge.getString(
            'allowMixedAudio',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) ==
          'true';
      unawaited(NativeBridge.setAllowMixedAudio(allowMixedAudio));
    } catch (_) {}
    try {
      rememberLogin =
          await NativeBridge.getString(
            'rememberLogin',
          ).timeout(const Duration(seconds: 2), onTimeout: () => null) !=
          'false';
      final savedLoggedIn = await NativeBridge.getString(
        'savedLoggedIn',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (rememberLogin && savedLoggedIn == 'true') {
        loggedIn = true;
        loginGateVisible = false;
        loginLoading = false;
        loginMessage = '正在恢复上次登录状态';
        status = '正在恢复上次登录状态';
        accountName =
            await NativeBridge.getString(
              'savedAccountName',
            ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
            accountName;
        avatarUrl =
            await NativeBridge.getString(
              'savedAvatarUrl',
            ).timeout(const Duration(seconds: 2), onTimeout: () => null) ??
            avatarUrl;
        _restoreLoginOnLoad = true;
        _trustSavedLogin = true;
      }
    } catch (_) {
      rememberLogin = true;
    }
    await _restoreSavedAccounts();
    await _restorePlaylistRevealCounts();
    await _restoreContentCache();
    if (showSongCovers) {
      final startupArtwork = <MirrorItem>[
        ...dailySongs.take(12),
        ...currentPlaylist.take(12),
        if (displayPlayer.hasSong) displayPlayer.asMirrorItem(),
      ];
      unawaited(prepareSongArtworkBatch(startupArtwork));
    }
    ready = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final controller = await _ensureWebController();
    await controller?.loadRequest(Uri.parse('https://music.163.com/'));
    if (!_restoreLoginOnLoad) {
      unawaited(_probeStartupLoginState());
    }
  }

  @override
  void dispose() {
    _smsLoginApiClient.dispose();
    _loginTimer?.cancel();
    _playerTimer?.cancel();
    _searchDebounce?.cancel();
    _noticeHideTimer?.cancel();
    _themeModeReviewTimer?.cancel();
    _dynamicColorDebounce?.cancel();
    _dynamicThemeGuardTimer?.cancel();
    _desktopLyricsColorReviewTimer?.cancel();
    _coverCacheNotifyTimer?.cancel();
    _coverCachePersistTimer?.cancel();
    _currentPlaylistPersistTimer?.cancel();
    _playlistRevealPersistTimer?.cancel();
    _autoAdvanceWatchdog?.cancel();
    for (final waiter in _songCoverWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _songCoverWaiters.clear();
    playbackRevision.dispose();
    for (final waiter in _snapshotWaiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _snapshotWaiters.clear();
    super.dispose();
  }

  void setTab(int index) {
    final shouldClosePlaylist =
        selectedLibraryPlaylist != null && (index != 1 || tabIndex == 1);
    tabIndex = index;
    if (shouldClosePlaylist) {
      selectedLibraryPlaylist = null;
    }
    notifyListeners();
    if (index == 0 && dailySongs.isEmpty) {
      unawaited(loadDailySongs());
    } else if (index == 1 && libraryPlaylists.isEmpty) {
      unawaited(loadLibrary());
    }
  }

  void openLibraryPlaylist(MirrorItem playlist) {
    selectedLibraryPlaylist = playlist;
    playlistLoading = true;
    activePlaylistTitle = playlist.title;
    playlistSongs = _playlistSongCache[playlist.id] ?? const [];
    status = '正在打开歌单：${playlist.title}';
    notifyListeners();
  }

  void closeLibraryPlaylist() {
    if (selectedLibraryPlaylist == null) return;
    selectedLibraryPlaylist = null;
    notifyListeners();
  }

  bool handleSystemBack() {
    if (loginGateVisible) {
      loginGateVisible = false;
      _restoreSwitchAccountBackup();
      _loginTimer?.cancel();
      notifyListeners();
      return true;
    }
    if (selectedLibraryPlaylist != null) {
      closeLibraryPlaylist();
      return true;
    }
    if (searchQuery.trim().isNotEmpty ||
        searchSuggestions.isNotEmpty ||
        searchResults.isNotEmpty) {
      clearSearch();
      return true;
    }
    if (tabIndex != 0) {
      setTab(0);
      return true;
    }
    return false;
  }

  Future<void> setThemeMode(String value) async {
    if (value != 'system' && value != 'light' && value != 'dark') return;
    final serial = ++_themeModeChangeSerial;
    _themeModeReviewTimer?.cancel();
    themeMode = value;
    notifyListeners();
    if (value == 'system') {
      unawaited(_refreshSystemThemeFromNative(notify: true));
    }
    await _persistThemeModeValue(value, serial);
    if (!_themeModeChangeIsCurrent(value, serial)) return;
    notifyListeners();
    _scheduleThemeModeReview(value, serial);
  }

  Future<void> refreshVisualStateAfterResume() async {
    await _refreshSystemThemeFromNative(notify: themeMode == 'system');
    if (themeMode != 'system') {
      await _verifyFixedThemeMode(themeMode);
    }
    await _refreshDesktopLyricsAfterResume();
    if (dynamicColorEnabled) {
      if (_nativePlaybackActive) {
        await _syncNativePlayerState();
      }
      final syncedFromNative = await _refreshDynamicThemeFromNativePlayback(
        force: true,
      );
      if (!syncedFromNative) {
        _refreshDynamicThemeFromCurrentCover(force: true);
      }
      _scheduleDynamicThemeGuard();
    }
  }

  bool _themeModeChangeIsCurrent(String expectedMode, int serial) {
    return serial == _themeModeChangeSerial && themeMode == expectedMode;
  }

  Future<void> _persistThemeModeValue(String value, int serial) async {
    await Future<void>.delayed(Duration.zero);
    if (!_themeModeChangeIsCurrent(value, serial)) return;
    try {
      await NativeBridge.setString('themeMode', value);
      if (!_themeModeChangeIsCurrent(value, serial)) return;
      await NativeBridge.setString('darkMode', (value == 'dark').toString());
    } catch (_) {}
  }

  void _scheduleThemeModeReview(String expectedMode, int serial) {
    _themeModeReviewTimer?.cancel();
    _themeModeReviewTimer = Timer(const Duration(milliseconds: 550), () {
      if (!_themeModeChangeIsCurrent(expectedMode, serial)) return;
      if (expectedMode == 'system') {
        unawaited(_verifySystemThemeMode(serial));
      } else {
        unawaited(_verifyFixedThemeMode(expectedMode, serial: serial));
      }
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1500), () {
        if (!_themeModeChangeIsCurrent(expectedMode, serial)) return null;
        if (expectedMode == 'system') {
          return _verifySystemThemeMode(serial);
        }
        return _verifyFixedThemeMode(expectedMode, serial: serial);
      }),
    );
  }

  Future<void> _verifySystemThemeMode(int serial) async {
    if (!_themeModeChangeIsCurrent('system', serial)) return;
    await _persistThemeModeValue('system', serial);
    if (!_themeModeChangeIsCurrent('system', serial)) return;
    await _refreshSystemThemeFromNative(notify: false);
    if (_themeModeChangeIsCurrent('system', serial)) notifyListeners();
  }

  Future<void> _verifyFixedThemeMode(String expectedMode, {int? serial}) async {
    if (expectedMode != 'light' && expectedMode != 'dark') return;
    if (serial != null && !_themeModeChangeIsCurrent(expectedMode, serial)) {
      return;
    }
    var changed = false;
    if (themeMode != expectedMode) {
      themeMode = expectedMode;
      changed = true;
    }
    try {
      final stored = await NativeBridge.getString(
        'themeMode',
      ).timeout(const Duration(seconds: 1), onTimeout: () => null);
      if (serial != null && !_themeModeChangeIsCurrent(expectedMode, serial)) {
        return;
      }
      if (stored != expectedMode) {
        await NativeBridge.setString('themeMode', expectedMode);
      }
      final expectedDark = (expectedMode == 'dark').toString();
      final storedDark = await NativeBridge.getString(
        'darkMode',
      ).timeout(const Duration(seconds: 1), onTimeout: () => null);
      if (serial != null && !_themeModeChangeIsCurrent(expectedMode, serial)) {
        return;
      }
      if (storedDark != expectedDark) {
        await NativeBridge.setString('darkMode', expectedDark);
      }
    } catch (_) {}
    if (changed || themeMode == expectedMode) notifyListeners();
  }

  Future<void> _refreshSystemThemeFromNative({required bool notify}) async {
    try {
      final next = await NativeBridge.isSystemDarkMode().timeout(
        const Duration(seconds: 2),
        onTimeout: () => systemDarkMode,
      );
      if (systemDarkMode == next) return;
      systemDarkMode = next;
      if (notify && themeMode == 'system') {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _refreshDesktopLyricsAfterResume() async {
    if (!desktopLyricsEnabled) return;
    try {
      await _ensureDesktopLyricsOverlayActive(forceSync: true);
      if (!desktopLyricsEnabled) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setRememberLogin(bool value) async {
    rememberLogin = value;
    await NativeBridge.setString('rememberLogin', value.toString());
    if (value && loggedIn) {
      await _persistLoginState();
    } else if (!value) {
      await _clearSavedLoginState();
    }
    notifyListeners();
  }

  bool _validAudioQuality(String? value) {
    return value == 'standard' ||
        value == 'higher' ||
        value == 'exhigh' ||
        value == 'lossless';
  }

  String _audioQualityName(String value) {
    return switch (value) {
      'standard' => '标准',
      'higher' => '较高',
      'exhigh' => '极高',
      'lossless' => '无损',
      _ => '较高',
    };
  }

  Future<void> setAudioQuality(String value) async {
    if (!_validAudioQuality(value)) return;
    audioQuality = value;
    status = '播放音质已切换为：${_audioQualityName(value)}';
    await NativeBridge.setString('audioQuality', value);
    notifyListeners();
  }

  Future<void> setAllowMixedAudio(bool value) async {
    allowMixedAudio = value;
    await NativeBridge.setString('allowMixedAudio', value.toString());
    try {
      await NativeBridge.setAllowMixedAudio(value);
    } catch (_) {}
    notifyListeners();
  }

  void _restoreSwitchAccountBackup() {
    final backupLoggedIn = _switchAccountBackupLoggedIn;
    if (backupLoggedIn == null) return;
    final backupCookie = _switchAccountBackupCookie ?? '';
    loggedIn = backupLoggedIn;
    accountName = _switchAccountBackupName ?? accountName;
    avatarUrl = _switchAccountBackupAvatarUrl ?? avatarUrl;
    _switchAccountBackupLoggedIn = null;
    _switchAccountBackupName = null;
    _switchAccountBackupAvatarUrl = null;
    _switchAccountBackupCookie = null;
    if (backupLoggedIn && backupCookie.isNotEmpty) {
      unawaited(
        NativeBridge.setCookies('https://music.163.com/', backupCookie),
      );
    }
    if (backupLoggedIn) {
      unawaited(_persistLoginState());
    }
  }

  void _clearSwitchAccountBackup() {
    _switchAccountBackupLoggedIn = null;
    _switchAccountBackupName = null;
    _switchAccountBackupAvatarUrl = null;
    _switchAccountBackupCookie = null;
  }

  void _captureLoginPlaybackBackup() {
    final snapshot = displayPlayer;
    if (!snapshot.hasSong) return;
    _loginGatePlayerBackup = snapshot;
    _loginGatePlayerBarVisibleBackup = true;
  }

  Future<void> _captureSwitchAccountBackup() async {
    if (_switchAccountBackupLoggedIn != null) return;
    await _persistLoginState();
    _switchAccountBackupLoggedIn = loggedIn;
    _switchAccountBackupName = accountName;
    _switchAccountBackupAvatarUrl = avatarUrl;
    try {
      _switchAccountBackupCookie = await NativeBridge.getCookies(
        'https://music.163.com/',
      );
    } catch (_) {}
  }

  bool _hasRealAccountName(String value) {
    final text = value.trim();
    return text.isNotEmpty && text != '未登录' && text != '已登录账号';
  }

  Future<void> _restoreSavedAccounts() async {
    try {
      final raw = await NativeBridge.getString(
        'savedAccounts',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final restored = _stringOf(raw).isEmpty
          ? <SavedAccount>[]
          : _listOf(jsonDecode(raw!))
                .map((item) => SavedAccount.fromJson(_mapOf(item)))
                .where((account) => account.hasUsableName)
                .toList(growable: true);
      if (_hasRealAccountName(accountName) &&
          !restored.any((account) => account.name == accountName)) {
        restored.insert(
          0,
          SavedAccount(
            id: '',
            name: accountName,
            avatarUrl: avatarUrl,
            cookie: '',
            lastUsedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      restored.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      savedAccounts = restored.take(8).toList(growable: false);
    } catch (_) {
      savedAccounts = const [];
    }
  }

  Future<void> _saveSavedAccounts() async {
    try {
      await NativeBridge.setString(
        'savedAccounts',
        jsonEncode(savedAccounts.map((account) => account.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _rememberCurrentAccount({String id = ''}) async {
    if (!_hasRealAccountName(accountName)) return;
    var cookie = '';
    try {
      cookie = await NativeBridge.getCookies('https://music.163.com/');
    } catch (_) {}
    final key = id.isNotEmpty ? id : accountName;
    savedAccounts = <SavedAccount>[
      SavedAccount(
        id: id,
        name: accountName,
        avatarUrl: avatarUrl,
        cookie: cookie,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      for (final account in savedAccounts)
        if (account.key != key && account.name != accountName) account,
    ].take(8).toList(growable: false);
    await _saveSavedAccounts();
  }

  Future<void> _persistLoginState() async {
    await _rememberCurrentAccount();
    if (!rememberLogin) return;
    try {
      await NativeBridge.setString('rememberLogin', 'true');
      await NativeBridge.setString('savedLoggedIn', accountActive.toString());
      await NativeBridge.setString('savedAccountName', accountName);
      await NativeBridge.setString('savedAvatarUrl', avatarUrl);
    } catch (_) {}
  }

  Future<void> _clearSavedLoginState() async {
    try {
      await NativeBridge.setString('savedLoggedIn', 'false');
      await NativeBridge.setString('savedAccountName', '');
      await NativeBridge.setString('savedAvatarUrl', '');
    } catch (_) {}
  }

  Future<void> _restorePlaylistRevealCounts() async {
    try {
      final source = await NativeBridge.getString(
        'playlistRevealCounts',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (_stringOf(source).isEmpty) return;
      final decoded = jsonDecode(source!);
      if (decoded is! Map) return;
      _playlistRevealCounts.clear();
      for (final entry in decoded.entries) {
        final playlistId = entry.key.toString().trim();
        final rawCount = entry.value;
        final count = rawCount is num
            ? rawCount.toInt()
            : int.tryParse(rawCount.toString()) ?? 0;
        if (playlistId.isEmpty || count <= 0) continue;
        _playlistRevealCounts[playlistId] = count.clamp(1, 2000).toInt();
        if (_playlistRevealCounts.length >= 100) break;
      }
    } catch (_) {}
  }

  int playlistRevealCount(String playlistId) {
    if (playlistId.isEmpty) return 0;
    return _playlistRevealCounts[playlistId] ?? 0;
  }

  void rememberPlaylistRevealCount(String playlistId, int count) {
    if (playlistId.isEmpty || count <= 0) return;
    final normalized = count.clamp(1, 2000).toInt();
    if ((_playlistRevealCounts[playlistId] ?? 0) >= normalized) return;
    if (!_playlistRevealCounts.containsKey(playlistId) &&
        _playlistRevealCounts.length >= 100) {
      _playlistRevealCounts.remove(_playlistRevealCounts.keys.first);
    }
    _playlistRevealCounts[playlistId] = normalized;
    _schedulePlaylistRevealCountsSave();
  }

  void _schedulePlaylistRevealCountsSave() {
    _playlistRevealPersistTimer?.cancel();
    _playlistRevealPersistTimer = Timer(const Duration(milliseconds: 350), () {
      _playlistRevealPersistTimer = null;
      unawaited(_persistPlaylistRevealCounts());
    });
  }

  Future<void> _persistPlaylistRevealCounts() async {
    try {
      await NativeBridge.setString(
        'playlistRevealCounts',
        jsonEncode(_playlistRevealCounts),
      );
    } catch (_) {}
  }

  void _forgetPlaylistRevealCount(String playlistId) {
    if (_playlistRevealCounts.remove(playlistId) == null) return;
    _schedulePlaylistRevealCountsSave();
  }

  Future<void> _restoreContentCache() async {
    try {
      final daily = await NativeBridge.getString(
        'cacheDailySongs',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final library = await NativeBridge.getString(
        'cacheLibraryPlaylists',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final cachedPlayer = await NativeBridge.getString(
        'cachePlayerSnapshot',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final cachedPlaylist = await NativeBridge.getString(
        'cacheCurrentPlaylist',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final cachedPlaylistIndex = await NativeBridge.getString(
        'cacheCurrentSongIndex',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      final cachedPlaylistSource = await NativeBridge.getString(
        'cacheCurrentPlaylistSource',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (_stringOf(daily).isNotEmpty) {
        dailySongs = _decodeItems(daily!);
        _rememberCovers(dailySongs);
      }
      if (_stringOf(library).isNotEmpty) {
        _setLibraryPlaylists(_decodeItems(library!), updateBase: true);
      }
      if (_stringOf(cachedPlaylist).isNotEmpty) {
        _restoreCurrentPlaylistCache(
          cachedPlaylist!,
          cachedPlaylistIndex,
          cachedPlaylistSource,
        );
      }
      if (_stringOf(cachedPlayer).isNotEmpty) {
        final restored = PlayerSnapshot.fromJson(
          _mapOf(jsonDecode(cachedPlayer!)),
        );
        if (restored.hasSong) {
          player = PlayerSnapshot(
            visible: true,
            songId: restored.songId,
            title: restored.title,
            artist: restored.artist,
            source: restored.source,
            coverUrl: restored.coverUrl,
            playing: false,
            currentSeconds: 0,
            durationSeconds: restored.durationSeconds,
            currentMilliseconds: 0,
            durationMilliseconds: restored.durationMilliseconds,
            volume: desiredVolume,
            mode: _validPlaybackMode(restored.mode)
                ? restored.mode
                : player.mode,
          );
          _lastPlayerWithSong = player;
          _activePlaybackDynamicSongId = restored.songId;
          _dynamicColorTargetSongId = restored.songId;
          playerBarVisible = true;
          _lastSavedPlayerCacheKey = _playerCacheKey(player);
          unawaited(NativeBridge.restorePausedMedia(player));
        }
      }
    } catch (_) {}
  }

  void _restoreCurrentPlaylistCache(
    String source,
    String? cachedIndex,
    String? cachedDynamicSource,
  ) {
    final restored = _decodeItems(source);
    if (restored.isEmpty) return;
    final index = int.tryParse(cachedIndex ?? '') ?? -1;
    currentPlaylist = restored;
    playerQueue = restored;
    currentSongIndex = index >= 0 && index < restored.length ? index : -1;
    _activePlaybackDynamicSource = cachedDynamicSource == 'playlist'
        ? 'playlist'
        : 'daily';
    _pendingDynamicColorSource = _activePlaybackDynamicSource;
    _dynamicColorSource = _activePlaybackDynamicSource;
    _rememberCovers(restored);
    _lastSavedPlaylistCacheKey =
        '$_activePlaybackDynamicSource|${_playlistCacheKey(restored, currentSongIndex)}';
  }

  Future<void> _saveItemsCache(String key, List<MirrorItem> items) async {
    if (items.isEmpty) return;
    try {
      await NativeBridge.setString(
        key,
        jsonEncode(
          _itemsWithKnownCovers(
            items,
          ).take(120).map((item) => item.toJson()).toList(),
        ),
      );
    } catch (_) {}
  }

  List<MirrorItem> _itemsWithKnownCovers(List<MirrorItem> items) {
    return items
        .map((item) {
          final cover = coverFor(item);
          if (!cover.startsWith('http') || cover == item.imageUrl) return item;
          return MirrorItem(
            domId: item.domId,
            kind: item.kind,
            title: item.title,
            subtitle: item.subtitle,
            imageUrl: cover,
            href: item.href,
          );
        })
        .toList(growable: false);
  }

  String _playerCacheKey(PlayerSnapshot snapshot) {
    return [
      snapshot.songId,
      snapshot.title,
      snapshot.artist,
      snapshot.coverUrl,
      snapshot.durationMilliseconds,
      snapshot.mode,
    ].join('|');
  }

  String _playlistCacheKey(List<MirrorItem> items, int index) {
    return [
      index,
      items.length,
      for (final item in items.take(8))
        item.id.isNotEmpty ? item.id : '${item.title}/${item.subtitle}',
      for (final item
          in items.length > 8
              ? items.skip(items.length - 3)
              : const <MirrorItem>[])
        item.id.isNotEmpty ? item.id : '${item.title}/${item.subtitle}',
    ].join('|');
  }

  Future<void> _saveCurrentPlaylistCache() async {
    final items = currentPlaylist.isNotEmpty ? currentPlaylist : playerQueue;
    if (items.isEmpty) return;
    final index = currentPlaylist.isNotEmpty ? currentSongIndex : -1;
    final cacheKey =
        '$_activePlaybackDynamicSource|${_playlistCacheKey(items, index)}';
    if (cacheKey == _lastSavedPlaylistCacheKey) return;
    _lastSavedPlaylistCacheKey = cacheKey;
    try {
      await NativeBridge.setString(
        'cacheCurrentPlaylist',
        jsonEncode(
          _itemsWithKnownCovers(
            items,
          ).take(1200).map((item) => item.toJson()).toList(),
        ),
      );
      await NativeBridge.setString('cacheCurrentSongIndex', index.toString());
      await NativeBridge.setString(
        'cacheCurrentPlaylistSource',
        _activePlaybackDynamicSource,
      );
    } catch (_) {}
  }

  void _scheduleCurrentPlaylistCacheSave({
    Duration delay = const Duration(milliseconds: 420),
    bool includeUpdatedCovers = false,
  }) {
    if (includeUpdatedCovers) _lastSavedPlaylistCacheKey = '';
    _currentPlaylistPersistTimer?.cancel();
    _currentPlaylistPersistTimer = Timer(delay, () {
      _currentPlaylistPersistTimer = null;
      unawaited(_saveCurrentPlaylistCache());
    });
  }

  Future<List<MirrorItem>> _restoreRecentPlaylistSongsCache(
    String playlistId,
  ) async {
    if (playlistId.isEmpty) return const [];
    try {
      final cachedId = await NativeBridge.getString('cacheRecentPlaylistId');
      if (cachedId != playlistId) return const [];
      final source = await NativeBridge.getString('cacheRecentPlaylistSongs');
      return _decodeItems(source ?? '');
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveRecentPlaylistSongsCache(
    String playlistId,
    List<MirrorItem> items,
  ) async {
    if (playlistId.isEmpty) return;
    try {
      final payload = jsonEncode(
        _itemsWithKnownCovers(
          items,
        ).take(1500).map((item) => item.toJson()).toList(growable: false),
      );
      await NativeBridge.setString('cacheRecentPlaylistId', playlistId);
      await NativeBridge.setString('cacheRecentPlaylistSongs', payload);
    } catch (_) {}
  }

  Future<void> _invalidatePlaylistSongsCache(String playlistId) async {
    if (playlistId.isEmpty) return;
    _playlistSongCache.remove(playlistId);
    try {
      final cachedId = await NativeBridge.getString('cacheRecentPlaylistId');
      if (cachedId != playlistId) return;
      await Future.wait(<Future<void>>[
        NativeBridge.removeString('cacheRecentPlaylistId'),
        NativeBridge.removeString('cacheRecentPlaylistSongs'),
      ]);
    } catch (_) {}
  }

  Future<void> _clearContentCache() async {
    for (final key in const [
      'cacheDailySongs',
      'cacheLibraryPlaylists',
      'cachePlayerSnapshot',
      'cacheCurrentPlaylist',
      'cacheCurrentSongIndex',
      'cacheCurrentPlaylistSource',
      'cacheRecentPlaylistId',
      'cacheRecentPlaylistSongs',
      'playlistRevealCounts',
    ]) {
      try {
        await NativeBridge.removeString(key);
      } catch (_) {}
    }
  }

  Future<void> _savePlayerCache(PlayerSnapshot snapshot) async {
    if (!snapshot.hasSong) return;
    final cached = PlayerSnapshot(
      visible: true,
      songId: snapshot.songId,
      title: snapshot.title,
      artist: snapshot.artist,
      source: snapshot.source,
      coverUrl: snapshot.coverUrl,
      playing: false,
      currentSeconds: 0,
      durationSeconds: snapshot.durationSeconds,
      currentMilliseconds: 0,
      durationMilliseconds: snapshot.durationMilliseconds,
      volume: desiredVolume,
      mode: snapshot.mode,
    );
    try {
      await NativeBridge.setString(
        'cachePlayerSnapshot',
        jsonEncode(cached.toJson()),
      );
    } catch (_) {}
  }

  List<MirrorItem> _decodeItems(String source) {
    try {
      return _listOf(jsonDecode(source))
          .map((item) => MirrorItem.fromJson(_mapOf(item)))
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<MirrorItem> _sortLibraryPlaylists(List<MirrorItem> items) {
    if (items.isEmpty || pinnedPlaylistIds.isEmpty) return items;
    final pinIndex = <String, int>{
      for (var i = 0; i < pinnedPlaylistIds.length; i++)
        pinnedPlaylistIds[i]: i,
    };
    final indexed = <({int index, MirrorItem item})>[
      for (var i = 0; i < items.length; i++) (index: i, item: items[i]),
    ];
    indexed.sort((a, b) {
      final aPin = pinIndex[a.item.id];
      final bPin = pinIndex[b.item.id];
      if (aPin != null && bPin != null) return aPin.compareTo(bPin);
      if (aPin != null) return -1;
      if (bPin != null) return 1;
      return a.index.compareTo(b.index);
    });
    return indexed.map((entry) => entry.item).toList(growable: false);
  }

  void _setLibraryPlaylists(List<MirrorItem> items, {bool updateBase = true}) {
    if (updateBase || _libraryPlaylistsBase.isEmpty) {
      _libraryPlaylistsBase = items.toList(growable: false);
    }
    final source = _libraryPlaylistsBase.isEmpty
        ? items
        : _libraryPlaylistsBase;
    libraryPlaylists = _sortLibraryPlaylists(source);
  }

  List<MirrorItem> _currentLibraryBase() =>
      _libraryPlaylistsBase.isEmpty ? libraryPlaylists : _libraryPlaylistsBase;

  Future<void> _saveLibraryPlaylistCache() async {
    await _saveItemsCache('cacheLibraryPlaylists', _currentLibraryBase());
  }

  void _rememberCovers(List<MirrorItem> items) {
    final next = Map<String, String>.from(songCoverCache);
    for (final item in items) {
      if (item.id.isNotEmpty && item.imageUrl.startsWith('http')) {
        next[item.id] = item.imageUrl;
      }
    }
    songCoverCache = next;
    final prefetchCount = items.length <= 40 ? items.length : 24;
    final prefetchUrls = items
        .map((item) => item.imageUrl)
        .where((url) => url.startsWith('http'))
        .take(prefetchCount)
        .toList(growable: false);
    if (prefetchUrls.isNotEmpty) {
      // Give on-screen artwork the first download slots on a cold start.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 320), () async {
          await CoverRuntimeCache.instance.prefetch(prefetchUrls);
          _scheduleSongCoverNotify();
        }),
      );
    }
  }

  String coverFor(MirrorItem item) {
    final cached = songCoverCache[item.id] ?? '';
    if (cached.startsWith('http')) return cached;
    return item.imageUrl.startsWith('http') ? item.imageUrl : '';
  }

  bool isSongArtworkReady(MirrorItem song) => _artworkPipeline.isReady(song);

  Future<bool> prepareSongArtwork(
    MirrorItem song, {
    bool forceMetadata = false,
  }) {
    return _artworkPipeline.prepare(song, forceMetadata: forceMetadata);
  }

  Future<bool> prepareSongArtworkBatch(
    List<MirrorItem> songs, {
    bool forceMissingMetadata = false,
  }) {
    return _artworkPipeline.prepareBatch(
      songs,
      forceMissingMetadata: forceMissingMetadata,
    );
  }

  Future<String> ensureSongCover(MirrorItem song, {bool force = false}) {
    final known = coverFor(song);
    if (!force && known.startsWith('http')) return Future.value(known);
    final songId = song.id.trim();
    if (songId.isEmpty) return Future.value('');
    final pending = _songCoverRequests[songId];
    if (pending != null) return pending;
    final request =
        _withSongCoverSlot(
              () => _resolvePlaybackCover(
                song,
                force ? '' : known,
                ignoreKnown: force,
              ),
            )
            .then((url) {
              if (url.startsWith('http')) {
                songCoverCache = {...songCoverCache, songId: url};
                if (player.songId == songId && player.coverUrl != url) {
                  player = _playerWith(coverUrl: url);
                  unawaited(NativeBridge.updatePlayerMetadata(player));
                  _requestDynamicThemeFromCoverForSource(
                    _activePlaybackDynamicSource,
                    url,
                    songId: songId,
                    force: true,
                  );
                }
                _scheduleSongCoverNotify();
              }
              return url;
            })
            .whenComplete(() {
              _songCoverRequests.remove(songId);
            });
    _songCoverRequests[songId] = request;
    return request;
  }

  Future<T> _withSongCoverSlot<T>(Future<T> Function() action) async {
    if (_activeSongCoverRequests >= 6) {
      final waiter = Completer<void>();
      _songCoverWaiters.add(waiter);
      await waiter.future;
    }
    _activeSongCoverRequests += 1;
    try {
      return await action();
    } finally {
      if (_activeSongCoverRequests > 0) _activeSongCoverRequests -= 1;
      if (_songCoverWaiters.isNotEmpty) {
        final waiter = _songCoverWaiters.removeAt(0);
        if (!waiter.isCompleted) waiter.complete();
      }
    }
  }

  void _scheduleSongCoverNotify() {
    if (_coverCacheNotifyTimer?.isActive == true) return;
    _coverCacheNotifyTimer = Timer(const Duration(milliseconds: 90), () {
      _coverCacheNotifyTimer = null;
      _scheduleCoverCachePersistence();
      notifyListeners();
    });
  }

  void _scheduleCoverCachePersistence() {
    _coverCachePersistTimer?.cancel();
    _coverCachePersistTimer = Timer(const Duration(milliseconds: 1200), () {
      _coverCachePersistTimer = null;
      if (dailySongs.isNotEmpty) {
        unawaited(_saveItemsCache('cacheDailySongs', dailySongs));
      }
      if (currentPlaylist.isNotEmpty || playerQueue.isNotEmpty) {
        _scheduleCurrentPlaylistCacheSave(includeUpdatedCovers: true);
      }
    });
  }

  bool _isSameSongCollection(List<MirrorItem> left, List<MirrorItem> right) {
    if (identical(left, right)) return true;
    if (left.isEmpty || right.isEmpty || left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_sameSong(left[index], right[index])) return false;
    }
    return true;
  }

  String _dynamicColorSourceForPlayback(
    List<MirrorItem> requestPlaylist,
    List<MirrorItem>? fromList,
    String sourceHint,
  ) {
    if (sourceHint == 'playlist' || sourceHint == 'daily') return sourceHint;
    final source = fromList != null && fromList.isNotEmpty
        ? fromList
        : requestPlaylist;
    if (_isSameSongCollection(source, dailySongs)) return 'daily';
    if (_isSameSongCollection(source, playlistSongs)) return 'playlist';
    if (_dynamicColorSource == 'playlist' &&
        _isSameSongCollection(source, currentPlaylist)) {
      return 'playlist';
    }
    return 'daily';
  }

  bool _songStateMatches(
    MirrorItem song, {
    required String songId,
    required String title,
    required String artist,
  }) {
    if (songId.isNotEmpty && song.id == songId) return true;
    final normalizedTitle = _normalizeForMatch(title);
    if (normalizedTitle.isEmpty ||
        _normalizeForMatch(song.title) != normalizedTitle) {
      return false;
    }
    final normalizedArtist = _normalizeForMatch(artist);
    if (normalizedArtist.isEmpty) return true;
    return _normalizeForMatch(song.subtitle).contains(normalizedArtist) ||
        normalizedArtist.contains(_normalizeForMatch(song.subtitle));
  }

  bool _songStateInList(
    List<MirrorItem> songs, {
    required String songId,
    required String title,
    required String artist,
  }) {
    if (songs.isEmpty) return false;
    return songs.any(
      (song) =>
          _songStateMatches(song, songId: songId, title: title, artist: artist),
    );
  }

  String _dynamicColorSourceForSongState({
    required String songId,
    required String title,
    required String artist,
  }) {
    if (_activePlaybackDynamicSongId.isNotEmpty &&
        songId == _activePlaybackDynamicSongId) {
      return _activePlaybackDynamicSource;
    }
    final matchesPlaylist =
        _songStateInList(
          playlistSongs,
          songId: songId,
          title: title,
          artist: artist,
        ) ||
        (_dynamicColorSource == 'playlist' &&
            _songStateInList(
              currentPlaylist,
              songId: songId,
              title: title,
              artist: artist,
            ));
    if (matchesPlaylist) return 'playlist';
    if (_songStateInList(
      dailySongs,
      songId: songId,
      title: title,
      artist: artist,
    )) {
      return 'daily';
    }
    return _dynamicColorSource;
  }

  String _knownCoverForSongState({
    required String songId,
    required String title,
    required String artist,
    String fallback = '',
  }) {
    if (songId.isNotEmpty) {
      final cached = songCoverCache[songId] ?? '';
      if (cached.startsWith('http')) return cached;
    }
    final sourceFirst = _dynamicColorSource == 'playlist'
        ? <List<MirrorItem>>[playlistSongs, currentPlaylist, dailySongs]
        : <List<MirrorItem>>[dailySongs, currentPlaylist, playlistSongs];
    for (final songs in sourceFirst) {
      for (final song in songs) {
        if (!_songStateMatches(
          song,
          songId: songId,
          title: title,
          artist: artist,
        )) {
          continue;
        }
        final cover = coverFor(song);
        if (cover.startsWith('http')) return cover;
      }
    }
    final normalizedFallback = _absoluteMusicUrl(fallback).trim();
    return normalizedFallback.startsWith('http') ? normalizedFallback : '';
  }

  void _setDynamicColorSource(String source) {
    final next = source == 'playlist' ? 'playlist' : 'daily';
    if (_dynamicColorSource == next) return;
    _dynamicColorSource = next;
    _dynamicColorSourceSerial += 1;
    _dynamicColorSerial += 1;
    _dynamicColorDebounce?.cancel();
    _dynamicColorPendingCoverUrl = '';
    _dynamicColorPendingRequestKey = '';
    _dynamicColorQueuedCoverUrl = '';
    _dynamicColorQueuedSongId = '';
    _lastDynamicColorRequestKey = '';
    _dynamicColorFailedCoverUrl = '';
    _dynamicColorFailedAt = null;
  }

  void _requestDynamicThemeFromCoverForSource(
    String source,
    String coverUrl, {
    String songId = '',
    bool force = false,
  }) {
    _setDynamicColorSource(source);
    // Playlist playback owns its colour lifecycle in PlaylistModule. Letting
    // generic cover updates compete here caused every player poll to launch a
    // second colour calculation for the same song.
    if (source == 'playlist') return;
    _requestDynamicThemeFromCover(coverUrl, songId: songId, force: force);
  }

  String _dynamicColorCacheKey(String coverUrl) =>
      _absoluteMusicUrl(coverUrl).trim();

  String _dynamicColorRequestKey(String songId, String coverUrl) =>
      '$_dynamicColorSource|$songId|$coverUrl';

  void _clearDynamicColorRequestState() {
    _dynamicColorDebounce?.cancel();
    _dynamicColorCoverUrl = '';
    _dynamicColorSongId = '';
    _dynamicColorPendingCoverUrl = '';
    _dynamicColorPendingRequestKey = '';
    _dynamicColorQueuedCoverUrl = '';
    _dynamicColorQueuedSongId = '';
    _lastDynamicColorRequestKey = '';
    _dynamicColorFailedCoverUrl = '';
    _dynamicColorFailedAt = null;
    _dynamicColorSerial += 1;
    _dynamicColorSourceSerial += 1;
  }

  void _clearNativeDynamicColorAuthority() {
    _nativeDynamicColorSongId = '';
    _nativeDynamicColorArgb = null;
    _playlistDynamicColorSongId = '';
    _playlistDynamicColorArgb = null;
  }

  void _refreshDynamicThemeFromCurrentCover({bool force = false}) {
    if (!dynamicColorEnabled) return;
    if (force) _clearDynamicColorRequestState();
    final displayed = displayPlayer;
    final cover = [
      displayed.coverUrl,
      songCoverCache[displayed.songId] ?? '',
      player.coverUrl,
      songCoverCache[player.songId] ?? '',
      _lastPlayerWithSong.coverUrl,
      songCoverCache[_lastPlayerWithSong.songId] ?? '',
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    if (cover.startsWith('http')) {
      final songId = displayed.songId.isNotEmpty
          ? displayed.songId
          : (player.songId.isNotEmpty
                ? player.songId
                : _lastPlayerWithSong.songId);
      _requestDynamicThemeFromCover(cover, songId: songId, force: force);
    }
  }

  String _knownCoverForDynamicColor(MirrorItem song, {String fallback = ''}) {
    return [
      fallback,
      coverFor(song),
      song.imageUrl,
      songCoverCache[song.id] ?? '',
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
  }

  Future<bool> _refreshDynamicThemeFromNativePlayback({
    bool force = false,
    String sourceHint = '',
  }) async {
    if (!dynamicColorEnabled) return false;
    try {
      final state = await NativeBridge.playerState().timeout(
        const Duration(milliseconds: 900),
        onTimeout: () => const <String, dynamic>{},
      );
      if (state['active'] != true) return false;
      final nativeCoverUrl = _absoluteMusicUrl(_stringOf(state['coverUrl']));
      final nativeSongId = _stringOf(state['songId']);
      final effectiveSongId = nativeSongId.isNotEmpty
          ? nativeSongId
          : (player.songId.isNotEmpty ? player.songId : displayPlayer.songId);
      final effectiveTitle = _stringOf(state['title']).isNotEmpty
          ? _stringOf(state['title'])
          : (player.title.isNotEmpty ? player.title : displayPlayer.title);
      final effectiveArtist = _stringOf(state['artist']).isNotEmpty
          ? _stringOf(state['artist'])
          : (player.artist.isNotEmpty ? player.artist : displayPlayer.artist);
      if (effectiveSongId.isNotEmpty &&
          _dynamicColorTargetSongId.isNotEmpty &&
          effectiveSongId != _dynamicColorTargetSongId) {
        return false;
      }
      final nativeDynamicSource = _dynamicColorSourceForSongState(
        songId: effectiveSongId,
        title: effectiveTitle,
        artist: effectiveArtist,
      );
      final effectiveDynamicSource = sourceHint == 'playlist'
          ? 'playlist'
          : nativeDynamicSource;
      _setDynamicColorSource(effectiveDynamicSource);
      final nativeCoverSongId = _stringOf(state['coverSongId']);
      final nativeCoverBelongsToSong =
          nativeCoverUrl.startsWith('http') &&
          (effectiveSongId.isEmpty || nativeCoverSongId == effectiveSongId);
      final effectiveCoverUrl = _knownCoverForSongState(
        songId: effectiveSongId,
        title: effectiveTitle,
        artist: effectiveArtist,
        fallback: nativeCoverBelongsToSong ? nativeCoverUrl : '',
      );
      final nativeCoverColor = _nativeOpaqueColor(state['coverColor']);
      final nativeCoverColorSongId = _stringOf(state['coverColorSongId']);
      final nativeColorMatches =
          nativeCoverColor != null &&
          (effectiveSongId.isEmpty
              ? nativeCoverColorSongId.isEmpty
              : nativeCoverColorSongId == effectiveSongId);
      if (nativeColorMatches) {
        await _applyDynamicThemeColor(
          nativeCoverColor,
          coverUrl: effectiveCoverUrl,
          songId: effectiveSongId,
          force: force,
          syncDesktopLyrics: false,
          authoritative: true,
        );
        return true;
      }
      if (!effectiveCoverUrl.startsWith('http')) return false;
      if (effectiveSongId.isNotEmpty) {
        songCoverCache = {
          ...songCoverCache,
          effectiveSongId: effectiveCoverUrl,
        };
      }
      final coverChanged =
          player.hasSong && player.coverUrl != effectiveCoverUrl;
      if (coverChanged) {
        player = _playerWith(
          songId: effectiveSongId.isNotEmpty ? effectiveSongId : null,
          coverUrl: effectiveCoverUrl,
        );
      }
      if (effectiveDynamicSource == 'playlist') {
        final playlistSong = currentPlaylist.firstWhere(
          (song) => _songStateMatches(
            song,
            songId: effectiveSongId,
            title: effectiveTitle,
            artist: effectiveArtist,
          ),
          orElse: () => player.asMirrorItem(),
        );
        await _playlistModule.refreshPlaybackColor(
          requestId: _playRequestId,
          song: playlistSong,
          songId: effectiveSongId,
          force: force,
        );
        if (coverChanged) notifyListeners();
        return true;
      }
      if (force) {
        await _updateDynamicThemeFromCover(
          effectiveCoverUrl,
          songId: effectiveSongId,
          force: true,
        );
      } else {
        _requestDynamicThemeFromCover(
          effectiveCoverUrl,
          songId: effectiveSongId,
          force: coverChanged,
        );
      }
      if (coverChanged) {
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyDynamicThemeColor(
    Color color, {
    String coverUrl = '',
    String songId = '',
    bool force = false,
    bool syncDesktopLyrics = true,
    bool authoritative = false,
  }) async {
    if (!dynamicColorEnabled) return;
    if (songId.isNotEmpty &&
        _dynamicColorTargetSongId.isNotEmpty &&
        songId != _dynamicColorTargetSongId) {
      return;
    }
    if (!authoritative &&
        songId.isNotEmpty &&
        _nativeDynamicColorSongId == songId &&
        _nativeDynamicColorArgb != null) {
      return;
    }
    if (authoritative && songId.isNotEmpty) {
      _nativeDynamicColorSongId = songId;
      _nativeDynamicColorArgb = color.toARGB32();
      _dynamicThemeGuardTimer?.cancel();
    }
    final normalized = _absoluteMusicUrl(coverUrl).trim();
    if (normalized.startsWith('http')) {
      _dynamicColorCoverUrl = normalized;
      _lastDynamicColorRequestKey = _dynamicColorRequestKey(songId, normalized);
      _dynamicColorCache[_dynamicColorCacheKey(normalized)] = color;
      if (_dynamicColorCache.length > 24) {
        _dynamicColorCache.remove(_dynamicColorCache.keys.first);
      }
    }
    if (songId.isNotEmpty) {
      _dynamicColorSongId = songId;
    }
    _dynamicColorFailedCoverUrl = '';
    _dynamicColorFailedAt = null;
    if (themeSeedColor.toARGB32() == color.toARGB32()) {
      if (syncDesktopLyrics && desktopLyricsEnabled) {
        unawaited(_applyDesktopLyricsStyle());
      }
      return;
    }
    themeSeedColor = color;
    // Theme rendering must never wait for a busy platform channel. Persist the
    // value in the background after the Flutter tree has received the update.
    notifyListeners();
    unawaited(
      NativeBridge.setString(
        'themeSeedColor',
        color.toARGB32().toString(),
      ).timeout(const Duration(seconds: 2)).catchError((_) {}),
    );
    if (syncDesktopLyrics && desktopLyricsEnabled) {
      unawaited(_applyDesktopLyricsStyle(force: true));
    }
    if (!authoritative) _scheduleDynamicThemeGuard();
  }

  void _scheduleDynamicThemeGuard([Color? expectedColor]) {
    _dynamicThemeGuardTimer?.cancel();
    if (!dynamicColorEnabled) return;
    if (_dynamicThemeGuardRefreshInProgress) return;
    final requestId = _playRequestId;
    final source = _dynamicColorSource;
    final displayed = displayPlayer;
    final songId = displayed.songId.isNotEmpty
        ? displayed.songId
        : (player.songId.isNotEmpty
              ? player.songId
              : _lastPlayerWithSong.songId);
    final coverUrl = [
      displayed.coverUrl,
      songCoverCache[displayed.songId] ?? '',
      player.coverUrl,
      songCoverCache[player.songId] ?? '',
      _lastPlayerWithSong.coverUrl,
      songCoverCache[_lastPlayerWithSong.songId] ?? '',
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    if (songId.isNotEmpty && _nativeDynamicColorSongId == songId) return;
    final expectedArgb = expectedColor?.toARGB32();
    _dynamicThemeGuardTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!dynamicColorEnabled || requestId != _playRequestId) return;
      if (songId.isNotEmpty && _nativeDynamicColorSongId == songId) return;
      if (expectedArgb != null && themeSeedColor.toARGB32() != expectedArgb) {
        return;
      }
      _dynamicThemeGuardRefreshInProgress = true;
      unawaited(
        _refreshDynamicThemeFromNativePlayback(force: true, sourceHint: source)
            .then((ok) async {
              if (ok ||
                  !dynamicColorEnabled ||
                  requestId != _playRequestId ||
                  !coverUrl.startsWith('http')) {
                return;
              }
              _setDynamicColorSource(source);
              await _updateDynamicThemeFromCover(
                coverUrl,
                songId: songId,
                force: true,
              );
            })
            .whenComplete(() {
              _dynamicThemeGuardRefreshInProgress = false;
              if (dynamicColorEnabled &&
                  requestId != _playRequestId &&
                  (_dynamicColorTargetSongId.isEmpty ||
                      _nativeDynamicColorSongId != _dynamicColorTargetSongId)) {
                _scheduleDynamicThemeGuard();
              }
            }),
      );
    });
  }

  bool get _desktopLyricsStyleHoldActive {
    final until = _desktopLyricsStyleHoldUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _holdDesktopLyricsDynamicStyle() {
    if (!desktopLyricsEnabled ||
        !desktopLyricsFollowDynamicColor ||
        !dynamicColorEnabled) {
      return;
    }
    _desktopLyricsStyleHoldUntil = DateTime.now().add(
      const Duration(milliseconds: 1150),
    );
  }

  void _scheduleInterfaceColorReviewFromDesktopLyrics(int requestId) {
    if (!dynamicColorEnabled ||
        !desktopLyricsEnabled ||
        !desktopLyricsFollowDynamicColor) {
      return;
    }
    final token = ++_desktopLyricsColorReviewSerial;
    _desktopLyricsColorReviewTimer?.cancel();
    _desktopLyricsColorReviewTimer = Timer(const Duration(seconds: 1), () {
      unawaited(
        _reviewInterfaceColorFromDesktopLyrics(
          requestId: requestId,
          token: token,
        ),
      );
    });
  }

  Color? _nativeOpaqueColor(dynamic value) {
    if (value is! num) return null;
    final raw = value.toInt() & 0xFFFFFFFF;
    return Color(0xFF000000 | (raw & 0x00FFFFFF));
  }

  Future<void> _reviewInterfaceColorFromDesktopLyrics({
    required int requestId,
    required int token,
  }) async {
    if (token != _desktopLyricsColorReviewSerial ||
        requestId != _playRequestId ||
        !dynamicColorEnabled ||
        !desktopLyricsEnabled ||
        !desktopLyricsFollowDynamicColor) {
      return;
    }
    if (player.songId.isNotEmpty &&
        _nativeDynamicColorSongId == player.songId) {
      return;
    }
    _desktopLyricsStyleHoldUntil = null;
    await _refreshDynamicThemeFromNativePlayback(
      force: true,
      sourceHint: _activePlaybackDynamicSource,
    );
  }

  void _requestDynamicThemeFromCover(
    String coverUrl, {
    String songId = '',
    bool force = false,
  }) {
    final normalized = _absoluteMusicUrl(coverUrl).trim();
    if (!dynamicColorEnabled || !normalized.startsWith('http')) return;
    final requestKey = _dynamicColorRequestKey(songId, normalized);
    if (_dynamicColorPendingRequestKey == requestKey) return;
    if (!force && requestKey == _lastDynamicColorRequestKey) return;
    final cached = _dynamicColorCache[_dynamicColorCacheKey(normalized)];
    if (cached != null) {
      unawaited(
        _applyDynamicThemeColor(
          cached,
          coverUrl: normalized,
          songId: songId,
          force: force,
        ),
      );
      return;
    }
    if (songId.isNotEmpty && songId != _dynamicColorSongId) {
      _dynamicColorSongId = songId;
      _dynamicColorCoverUrl = '';
      _dynamicColorPendingCoverUrl = '';
      _dynamicColorFailedCoverUrl = '';
      _dynamicColorFailedAt = null;
    }
    if (!force && _dynamicColorPendingCoverUrl == normalized) return;
    final failedAt = _dynamicColorFailedAt;
    if (!force &&
        _dynamicColorFailedCoverUrl == normalized &&
        failedAt != null &&
        DateTime.now().difference(failedAt) < const Duration(seconds: 15)) {
      return;
    }
    if (force) {
      _dynamicColorDebounce?.cancel();
      _dynamicColorQueuedCoverUrl = '';
      _dynamicColorQueuedSongId = '';
      unawaited(
        _updateDynamicThemeFromCover(normalized, songId: songId, force: true),
      );
      return;
    }
    _dynamicColorQueuedCoverUrl = normalized;
    _dynamicColorQueuedSongId = songId;
    _dynamicColorDebounce?.cancel();
    _dynamicColorDebounce = Timer(const Duration(milliseconds: 280), () {
      final queuedCover = _dynamicColorQueuedCoverUrl;
      final queuedSongId = _dynamicColorQueuedSongId;
      if (queuedCover.isEmpty) return;
      unawaited(
        _updateDynamicThemeFromCover(queuedCover, songId: queuedSongId),
      );
    });
  }

  Future<void> _updateDynamicThemeFromCover(
    String coverUrl, {
    String songId = '',
    bool force = false,
  }) async {
    final normalized = _absoluteMusicUrl(coverUrl).trim();
    if (!dynamicColorEnabled || !normalized.startsWith('http')) return;
    final requestKey = _dynamicColorRequestKey(songId, normalized);
    if (_dynamicColorPendingRequestKey == requestKey) return;
    if (!force &&
        _dynamicColorCoverUrl == normalized &&
        (songId.isEmpty || songId == _dynamicColorSongId)) {
      return;
    }
    if (!force && _dynamicColorPendingCoverUrl == normalized) return;
    final failedAt = _dynamicColorFailedAt;
    if (!force &&
        _dynamicColorFailedCoverUrl == normalized &&
        failedAt != null &&
        DateTime.now().difference(failedAt) < const Duration(seconds: 15)) {
      return;
    }
    final serial = ++_dynamicColorSerial;
    final sourceSerial = _dynamicColorSourceSerial;
    final source = _dynamicColorSource;
    _dynamicColorPendingCoverUrl = normalized;
    _dynamicColorPendingRequestKey = requestKey;
    try {
      final color = await _dominantCoverColor(normalized);
      if (serial != _dynamicColorSerial ||
          sourceSerial != _dynamicColorSourceSerial ||
          source != _dynamicColorSource) {
        return;
      }
      if (color == null) {
        _dynamicColorFailedCoverUrl = normalized;
        _dynamicColorFailedAt = DateTime.now();
        return;
      }
      _dynamicColorFailedCoverUrl = '';
      _dynamicColorFailedAt = null;
      _dynamicColorCoverUrl = normalized;
      if (songId.isNotEmpty) _dynamicColorSongId = songId;
      await _applyDynamicThemeColor(
        color,
        coverUrl: normalized,
        songId: songId,
        force: force,
      );
    } catch (_) {
      if (serial == _dynamicColorSerial &&
          sourceSerial == _dynamicColorSourceSerial &&
          source == _dynamicColorSource) {
        _dynamicColorFailedCoverUrl = normalized;
        _dynamicColorFailedAt = DateTime.now();
      }
    } finally {
      if (sourceSerial == _dynamicColorSourceSerial &&
          _dynamicColorPendingCoverUrl == normalized) {
        _dynamicColorPendingCoverUrl = '';
      }
      if (_dynamicColorPendingRequestKey == requestKey) {
        _dynamicColorPendingRequestKey = '';
      }
    }
  }

  Future<Color?> _dominantCoverColor(String coverUrl) async {
    final cached = await CoverRuntimeCache.instance.load(
      _coverImageCandidates(coverUrl),
    );
    if (cached != null) {
      final cachedColor = await _dominantColorFromImageBytes(cached.bytes);
      if (cachedColor != null) return cachedColor;
    }
    final candidates = _coverColorCandidates(coverUrl);
    if (candidates.isEmpty) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 5);
    try {
      for (final candidate in candidates) {
        try {
          final request = await client
              .getUrl(Uri.parse(candidate))
              .timeout(const Duration(seconds: 5));
          request.followRedirects = true;
          request.maxRedirects = 5;
          request.headers.set(HttpHeaders.userAgentHeader, _desktopUserAgent);
          request.headers.set(
            HttpHeaders.acceptHeader,
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          );
          request.headers.set(
            HttpHeaders.refererHeader,
            'https://music.163.com/',
          );
          final response = await request.close().timeout(
            const Duration(seconds: 6),
          );
          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }
          final chunks = <int>[];
          await for (final chunk in response) {
            chunks.addAll(chunk);
            if (chunks.length > 1024 * 1024) break;
          }
          if (chunks.isEmpty) continue;
          final color = await _dominantColorFromImageBytes(
            Uint8List.fromList(chunks),
          );
          if (color != null) return color;
        } catch (_) {
          continue;
        }
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  List<String> _coverColorCandidates(String coverUrl) {
    final normalized = _absoluteMusicUrl(coverUrl).trim();
    final candidates = <String>{};
    void add(String value) {
      if (value.startsWith('http')) candidates.add(value);
    }

    String sized(String value) {
      if (!value.startsWith('http')) return value;
      final base = value.split('?').first;
      return '$base?param=80y80';
    }

    final protocolVariants = <String>[
      normalized,
      if (normalized.startsWith('http://'))
        normalized.replaceFirst('http://', 'https://')
      else if (normalized.startsWith('https://'))
        normalized.replaceFirst('https://', 'http://'),
    ];
    for (final value in protocolVariants) {
      add(sized(value));
      add(value);
      for (final host in const [
        'p1.music.126.net',
        'p2.music.126.net',
        'p3.music.126.net',
        'p4.music.126.net',
      ]) {
        final replaced = value.replaceFirst(
          RegExp(r'p\d\.music\.126\.net'),
          host,
        );
        add(sized(replaced));
      }
    }
    return candidates.toList(growable: false);
  }

  Future<Color?> _dominantColorFromImageBytes(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 28,
      targetHeight: 28,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (bytes == null) return null;
        return _averageCoverColor(bytes, strict: true) ??
            _averageCoverColor(bytes, strict: false);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Color? _averageCoverColor(ByteData bytes, {required bool strict}) {
    var red = 0.0;
    var green = 0.0;
    var blue = 0.0;
    var count = 0;
    for (var offset = 0; offset + 3 < bytes.lengthInBytes; offset += 4) {
      final a = bytes.getUint8(offset + 3);
      if (a < 180) continue;
      final r = bytes.getUint8(offset);
      final g = bytes.getUint8(offset + 1);
      final b = bytes.getUint8(offset + 2);
      if (strict) {
        final brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255;
        if (brightness < 0.14 || brightness > 0.9) continue;
      }
      red += r;
      green += g;
      blue += b;
      count += 1;
    }
    if (count == 0) return null;
    final raw = Color.fromARGB(
      255,
      (red / count).round(),
      (green / count).round(),
      (blue / count).round(),
    );
    final hsl = HSLColor.fromColor(raw);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.42, 0.78).toDouble())
        .withLightness(hsl.lightness.clamp(0.42, 0.62).toDouble())
        .toColor();
  }

  Future<String> _resolvePlaybackCover(
    MirrorItem song,
    String fallback, {
    bool ignoreKnown = false,
  }) async {
    final known = [
      fallback,
      if (!ignoreKnown) coverFor(song),
      if (!ignoreKnown) song.imageUrl,
      if (!ignoreKnown) songCoverCache[song.id] ?? '',
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    if (known.isNotEmpty) return known;
    final songId = song.id.trim();
    if (songId.isEmpty) return '';
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 6);
    try {
      final cookie = await NativeBridge.getCookies(
        'https://music.163.com/',
      ).timeout(const Duration(seconds: 2), onTimeout: () => '');
      final typedId = int.tryParse(songId) ?? songId;
      for (var attempt = 0; attempt < 3; attempt++) {
        for (final uri in _songDetailApiUris([typedId])) {
          try {
            final decoded = await _getMusicJson(client, uri, cookie);
            final songs = _listOf(
              _mapOf(decoded)['songs'] ?? _mapOf(decoded)['data'],
            );
            for (final item in songs) {
              final map = _mapOf(item);
              final album = _mapOf(map['al'] ?? map['album']);
              final cover = _absoluteMusicUrl(
                _stringOf(album['picUrl'] ?? map['picUrl'] ?? map['coverUrl']),
              );
              if (cover.startsWith('http')) {
                songCoverCache = {...songCoverCache, songId: cover};
                return cover;
              }
            }
          } catch (_) {
            continue;
          }
        }
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 180 * (attempt + 1)),
          );
        }
      }
      final pageCover = await _resolveCoverFromSongPage(client, songId, cookie);
      if (pageCover.startsWith('http')) {
        songCoverCache = {...songCoverCache, songId: pageCover};
        return pageCover;
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    return '';
  }

  Future<String> _resolveCoverFromSongPage(
    HttpClient client,
    String songId,
    String cookie,
  ) async {
    final uris = [
      Uri.https('music.163.com', '/song', {'id': songId}),
      Uri.https('music.163.com', '/m/song', {'id': songId}),
      Uri.https('y.music.163.com', '/m/song', {'id': songId}),
      Uri.https('y.music.163.com', '/song', {'id': songId}),
    ];
    final patterns = <RegExp>[
      RegExp(
        '<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)',
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image["\']',
      ),
      RegExp('picUrl["\']?\\s*[:=]\\s*["\']([^"\']+)'),
      RegExp('coverUrl["\']?\\s*[:=]\\s*["\']([^"\']+)'),
      RegExp(
        '<img[^>]+(?:data-src|src)=["\']([^"\']+)["\'][^>]*class=["\'][^"\']*j-img',
      ),
      RegExp(
        '<img[^>]+class=["\'][^"\']*j-img[^"\']*["\'][^>]+(?:data-src|src)=["\']([^"\']+)',
      ),
    ];
    for (final uri in uris) {
      try {
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 5));
        request.headers.set(HttpHeaders.userAgentHeader, _desktopUserAgent);
        request.headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        );
        request.headers.set(
          HttpHeaders.refererHeader,
          'https://music.163.com/',
        );
        if (cookie.isNotEmpty) {
          request.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        final response = await request.close().timeout(
          const Duration(seconds: 6),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 6));
        for (final pattern in patterns) {
          final match = pattern.firstMatch(body);
          final raw = match?.group(1);
          if (raw == null || raw.isEmpty) continue;
          final cover = _absoluteMusicUrl(
            raw.replaceAll(r'\/', '/').replaceAll('&amp;', '&'),
          );
          if (cover.startsWith('http')) return cover;
        }
      } catch (_) {
        continue;
      }
    }
    return '';
  }

  Future<void> prepareLoginQr() async {
    await _useDesktopWebSession();
    final controller = await _ensureWebController();
    if (controller != null &&
        (!pageUrl.startsWith('https://music.163.com') ||
            pageUrl.contains('/m/login'))) {
      await controller.loadRequest(Uri.parse('https://music.163.com/'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    loginLoading = true;
    loginMessage = '正在生成二维码';
    loginQrData = '';
    loginQrImage = '';
    notifyListeners();
    await _runJavaScript(_openLoginScript);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _runJavaScript(_createOfficialQrScript);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _extractLoginProjection();
    _loginTimer?.cancel();
    _loginTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollLoginQr()),
    );
  }

  Future<void> refreshLoginQr() async {
    _trustSavedLogin = false;
    loggedIn = false;
    accountName = '未登录';
    avatarUrl = '';
    await _useDesktopWebSession();
    final controller = await _ensureWebController();
    await NativeBridge.clearCookies();
    await _clearSavedLoginState();
    if (controller != null) {
      await controller.loadRequest(Uri.parse('https://music.163.com/'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    loginLoading = true;
    loginMessage = '正在刷新二维码';
    loginQrData = '';
    loginQrImage = '';
    notifyListeners();
    await _runJavaScript(_createOfficialQrScript);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _extractLoginProjection();
  }

  Future<void> _pollLoginQr() async {
    await _runJavaScript(_pollOfficialQrScript);
    await _extractLoginProjection();
  }

  Future<void> selectLoginMethod(String label) async {
    if (label.contains('验证码') || label.contains('短信') || label.contains('手机')) {
      await openSmsLogin();
      return;
    }
    final encoded = jsonEncode(label);
    await _runJavaScript('''
      (async function () {
        var label = $encoded;
        function clean(v) { return (v || '').replace(/\\s+/g, ' ').trim(); }
        function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }
        function nodes() { return Array.prototype.slice.call(document.querySelectorAll('a,button,span,div,label,input')); }
        function clickText(patterns) {
          var list = nodes();
          for (var i = 0; i < list.length; i++) {
            var text = clean(list[i].textContent || list[i].value || list[i].getAttribute('aria-label') || list[i].getAttribute('title') || '');
            for (var p = 0; p < patterns.length; p++) {
              if (patterns[p].test(text)) {
                var target = list[i].closest('a,button,label') || list[i];
                target.click();
                return true;
              }
            }
          }
          return false;
        }
        function agreeProtocol() {
          var checks = Array.prototype.slice.call(document.querySelectorAll('input[type="checkbox"]'));
          for (var c = 0; c < checks.length; c++) {
            if (!checks[c].checked) {
              checks[c].click();
              return true;
            }
          }
          return clickText([/同意.*协议/, /服务协议/, /隐私政策/]);
        }
        if (/短信|验证码|手机/.test(label)) {
          clickText([/选择其他登录模式/, /选择其他登录方式/, /其他登录模式/, /其他登录方式/]);
          await sleep(360);
          agreeProtocol();
          await sleep(180);
          if (clickText([/手机号登录\\/注册/, /手机号登录/, /手机登录/, /短信验证码/, /验证码登录/])) {
            return true;
          }
        }
        var fallback = nodes();
        for (var f = 0; f < fallback.length; f++) {
          var text = clean(fallback[f].textContent || fallback[f].value || fallback[f].getAttribute('aria-label') || fallback[f].getAttribute('title') || '');
          if (text.indexOf(label) >= 0) {
            (fallback[f].closest('a,button,label') || fallback[f]).click();
            return true;
          }
        }
        return false;
      })();
    ''');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _extractLoginProjection();
  }

  Future<void> openSmsLogin() async {
    smsLoginVisible = false;
    smsLoginBusy = false;
    smsLoginMessage = '请输入手机号获取验证码';
    loginMessage = '验证码登录';
    _loginTimer?.cancel();
    loginLoading = false;
    _smsLoginApiClient.reset();
    notifyListeners();
  }

  Future<void> backToQrLogin() async {
    smsLoginVisible = true;
    smsLoginBusy = false;
    smsLoginMessage = '';
    notifyListeners();
    await prepareLoginQr();
  }

  Future<void> sendSmsCode(String phone) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanedPhone.length < 11) {
      smsLoginMessage = '请输入完整手机号';
      notifyListeners();
      return;
    }
    smsLoginBusy = true;
    smsLoginMessage = '正在发送验证码';
    notifyListeners();
    final result = await _smsLoginApiClient.sendCode(cleanedPhone);
    smsLoginBusy = false;
    smsLoginMessage = result.message.isEmpty
        ? (result.success ? '验证码请求已提交，请查看短信' : '验证码未发送成功，请稍后重试')
        : result.message;
    loginMessage = smsLoginMessage;
    notifyListeners();
  }

  Future<void> loginWithSms(String phone, String code) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    final cleanedCode = code.replaceAll(RegExp(r'\D'), '');
    if (cleanedPhone.length < 11 || cleanedCode.length < 4) {
      smsLoginMessage = '请输入手机号和验证码';
      notifyListeners();
      return;
    }
    smsLoginBusy = true;
    smsLoginMessage = '正在登录';
    notifyListeners();
    final result = await _smsLoginApiClient.login(cleanedPhone, cleanedCode);
    smsLoginBusy = false;
    smsLoginMessage = result.message.isEmpty
        ? (result.success ? '登录成功' : '验证码登录失败，请检查验证码或使用扫码登录')
        : result.message;
    loginMessage = smsLoginMessage;
    if (result.cookies.isNotEmpty) {
      await NativeBridge.setCookies('https://music.163.com/', result.cookies);
    }
    if (!result.success) {
      notifyListeners();
      return;
    }
    loggedIn = true;
    if (_hasRealAccountName(result.accountName)) {
      accountName = result.accountName;
    }
    _clearSwitchAccountBackup();
    smsLoginMessage = '登录成功，正在进入应用';
    loginMessage = '登录成功，正在进入应用';
    unawaited(_rememberCurrentAccount(id: result.accountId));
    unawaited(_persistLoginState());
    _loginTimer?.cancel();
    _scheduleEnterApp(const Duration(milliseconds: 500));
    notifyListeners();
  }

  Future<void> startFreshLogin() async {
    final generation = ++_loginFlowGeneration;
    await _captureSwitchAccountBackup();
    _captureLoginPlaybackBackup();
    _trustSavedLogin = false;
    smsLoginVisible = false;
    smsLoginBusy = false;
    loginGateVisible = true;
    loggedIn = false;
    accountName = '未登录';
    avatarUrl = '';
    loginLoading = false;
    loginMessage = '正在打开新账号登录';
    _loginTimer?.cancel();
    notifyListeners();
    await NativeBridge.clearCookies();
    await _clearSavedLoginState();
    final controller = await _ensureWebController();
    if (generation != _loginFlowGeneration) return;
    await _useDesktopWebSession();
    await controller?.loadRequest(Uri.parse('https://music.163.com/'));
    if (generation != _loginFlowGeneration) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (generation != _loginFlowGeneration) return;
    await openSmsLogin();
  }

  void _scheduleEnterApp(Duration delay) {
    final generation = _loginFlowGeneration;
    Future<void>.delayed(delay, () {
      if (generation != _loginFlowGeneration) return;
      unawaited(enterApp());
    });
  }

  Future<void> enterApp() async {
    final loginGateBackup = _loginGatePlayerBackup;
    final preservePlaybackUi =
        player.hasSong ||
        _lastPlayerWithSong.hasSong ||
        (loginGateBackup?.hasSong ?? false) ||
        _nativePlaybackActive ||
        _nativePlaybackPending;
    if (!loggedIn && _hasRealAccountName(accountName)) {
      loggedIn = true;
    }
    if (!loggedIn) {
      _restoreSwitchAccountBackup();
    }
    loginGateVisible = false;
    _loginTimer?.cancel();
    if (loggedIn) {
      _clearSwitchAccountBackup();
      unawaited(_persistLoginState());
    }
    await _useDesktopWebSession();
    await _runJavaScript(_onPageReadyScript);
    await _runJavaScript(_silenceOfficialAudioScript);
    if (!preservePlaybackUi) {
      playerBarVisible = false;
      player = PlayerSnapshot.empty;
    } else {
      playerBarVisible = true;
      if (!player.hasSong && (loginGateBackup?.hasSong ?? false)) {
        player = loginGateBackup!;
      } else if (!player.hasSong && _lastPlayerWithSong.hasSong) {
        player = _lastPlayerWithSong;
      }
      playerBarVisible = playerBarVisible || _loginGatePlayerBarVisibleBackup;
    }
    _loginGatePlayerBackup = null;
    _loginGatePlayerBarVisibleBackup = false;
    songDetail = null;
    songDetailLoading = false;
    _startPlayerPolling();
    status = accountActive ? '账号已登录，正在同步内容' : '未登录浏览，部分内容可能为空';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await syncHomeAndLibrary();
  }

  Future<void> openLoginGate() async {
    final generation = ++_loginFlowGeneration;
    await _captureSwitchAccountBackup();
    _captureLoginPlaybackBackup();
    smsLoginVisible = false;
    smsLoginBusy = false;
    _trustSavedLogin = false;
    loggedIn = false;
    accountName = '未登录';
    avatarUrl = '';
    loginGateVisible = true;
    loginLoading = false;
    loginMessage = '正在打开登录';
    notifyListeners();
    final controller = await _ensureWebController();
    if (generation != _loginFlowGeneration) return;
    if (controller == null) {
      loginMessage = '登录组件未就绪，请稍后重试';
      notifyListeners();
      return;
    }
    await NativeBridge.clearCookies();
    await _clearSavedLoginState();
    await _useDesktopWebSession();
    await controller.loadRequest(Uri.parse('https://music.163.com/'));
    if (generation != _loginFlowGeneration) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (generation != _loginFlowGeneration) return;
    await openSmsLogin();
  }

  Future<void> logout() async {
    final generation = ++_loginFlowGeneration;
    _loginTimer?.cancel();
    _clearSwitchAccountBackup();
    smsLoginVisible = false;
    smsLoginBusy = false;
    _trustSavedLogin = false;
    loggedIn = false;
    accountName = '未登录';
    avatarUrl = '';
    loginGateVisible = true;
    loginLoading = false;
    loginMessage = '已退出登录';
    status = '已退出登录';
    await _clearSavedLoginState();
    notifyListeners();
    await _runJavaScript(_logoutOfficialScript);
    await NativeBridge.clearCookies();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (generation != _loginFlowGeneration) return;
    final controller = await _ensureWebController();
    await _useDesktopWebSession();
    await controller?.loadRequest(Uri.parse('https://music.163.com/'));
    if (generation != _loginFlowGeneration) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (generation != _loginFlowGeneration) return;
    await openSmsLogin();
  }

  Future<void> syncHomeAndLibrary() async {
    final refreshedDaily = await _maybeAutoRefreshDailyAfterSix();
    if (!refreshedDaily) {
      await loadDailySongs();
    }
    await loadLibrary();
  }

  Future<bool> _maybeAutoRefreshDailyAfterSix() async {
    final now = DateTime.now();
    if (now.hour < 6) return false;
    final today = _dateKey(now);
    try {
      final lastRefreshDate = await NativeBridge.getString(
        'lastDailyAutoRefreshDate',
      ).timeout(const Duration(seconds: 2), onTimeout: () => null);
      if (lastRefreshDate == today) return false;
      await loadDailySongs();
      final refreshed = dailySongs.isNotEmpty && status.startsWith('已加载每日推荐');
      if (refreshed) {
        await NativeBridge.setString('lastDailyAutoRefreshDate', today);
      }
      return refreshed;
    } catch (_) {
      return false;
    }
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> loadDailySongs() async {
    dailyLoading = true;
    if (!_nativePlaybackPending) {
      _noticeToken += 1;
      _noticeHideTimer?.cancel();
      noticeMessage = '';
    }
    status = '正在打开官网每日歌曲推荐';
    notifyListeners();
    await _navigateOfficial('https://music.163.com/#/discover/recommend/taste');
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    await _extractPage('daily');
    if (dailySongs.isEmpty) {
      dailyLoading = true;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await _extractPage('daily');
    }
  }

  Future<void> loadLibrary() async {
    libraryLoading = true;
    if (!_nativePlaybackPending) {
      _noticeToken += 1;
      _noticeHideTimer?.cancel();
      noticeMessage = '';
    }
    status = '正在打开官网“我的音乐”';
    notifyListeners();
    await _navigateOfficial('https://music.163.com/#/my/m/music/');
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    await _extractPage('library');
  }

  Future<void> loadPlaylistSongs(MirrorItem playlist) async {
    await _playlistModule.load(playlist);
  }

  Future<List<MirrorItem>> _requestPlaylistSongsDirect(
    String playlistId, {
    int? expectedCount,
  }) async {
    final id = playlistId.trim();
    if (id.isEmpty) return const [];
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..idleTimeout = const Duration(seconds: 6);
    try {
      final cookie = await NativeBridge.getCookies(
        'https://music.163.com/',
      ).timeout(const Duration(seconds: 2), onTimeout: () => '');
      var best = const <MirrorItem>[];
      for (final uri in _playlistApiUris(id)) {
        try {
          final decoded = await _getMusicJson(client, uri, cookie);
          final items = _dedupeItems(
            await _playlistSongsFromApiResponse(decoded, id, client, cookie),
          );
          if (items.length > best.length) best = items;
          if (expectedCount != null &&
              expectedCount > 0 &&
              best.length >= expectedCount) {
            break;
          }
        } catch (_) {}
      }
      return best;
    } finally {
      client.close(force: true);
    }
  }

  List<Uri> _playlistApiUris(String playlistId) {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return [
      Uri.https('music.163.com', '/api/playlist/track/all', {
        'id': playlistId,
        'limit': '5000',
        'offset': '0',
        'timestamp': now,
      }),
      Uri.https('music.163.com', '/api/v6/playlist/track/all', {
        'id': playlistId,
        'limit': '5000',
        'offset': '0',
        'timestamp': now,
      }),
      Uri.https('music.163.com', '/api/playlist/detail', {
        'id': playlistId,
        'n': '5000',
        's': '8',
        'limit': '5000',
        'offset': '0',
        'timestamp': now,
      }),
      Uri.https('music.163.com', '/api/v6/playlist/detail', {
        'id': playlistId,
        'n': '5000',
        's': '8',
        'limit': '5000',
        'offset': '0',
        'timestamp': now,
      }),
    ];
  }

  List<Uri> _songDetailApiUris(List<dynamic> ids) {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final idsJson = jsonEncode(ids);
    final cJson = jsonEncode(
      ids.map((id) => <String, dynamic>{'id': id}).toList(),
    );
    final firstId = ids.length == 1 ? _stringOf(ids.first) : '';
    return [
      if (firstId.isNotEmpty)
        Uri.https('music.163.com', '/api/song/detail/', {
          'id': firstId,
          'ids': idsJson,
          'timestamp': now,
        }),
      if (firstId.isNotEmpty)
        Uri.https('music.163.com', '/api/song/detail', {
          'id': firstId,
          'ids': idsJson,
          'timestamp': now,
        }),
      Uri.https('music.163.com', '/api/song/detail', {
        'ids': idsJson,
        'timestamp': now,
      }),
      Uri.https('music.163.com', '/api/v3/song/detail', {
        'ids': idsJson,
        'c': cJson,
        'timestamp': now,
      }),
      Uri.https('music.163.com', '/api/v6/song/detail', {
        'ids': idsJson,
        'c': cJson,
        'timestamp': now,
      }),
    ];
  }

  Future<dynamic> _getMusicJson(
    HttpClient client,
    Uri uri,
    String cookie, {
    String referer = 'https://music.163.com/',
  }) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.userAgentHeader, _desktopUserAgent);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.refererHeader, referer);
    if (cookie.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookie);
    }
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return jsonDecode(body);
  }

  Future<List<MirrorItem>> _playlistSongsFromApiResponse(
    dynamic decoded,
    String playlistId,
    HttpClient client,
    String cookie,
  ) async {
    final roots = _apiRoots(decoded);
    var directItems = const <MirrorItem>[];
    for (final root in roots) {
      final list = root is List ? root : const [];
      final items = _apiSongListToItems(list, 'playlist_api');
      if (items.length > directItems.length) directItems = items;
    }
    for (final root in roots) {
      final map = root is Map ? root : const {};
      final returnedId = _stringOf(map['id'] ?? map['playlistId']);
      if (returnedId.isNotEmpty && returnedId != playlistId) {
        throw const FormatException('playlist id mismatch');
      }
      for (final key in const ['songs', 'tracks', 'list', 'items', 'datas']) {
        final items = _apiSongListToItems(_listOf(map[key]), 'playlist_api');
        if (items.length > directItems.length) directItems = items;
      }
    }
    final responseIds = _trackIdsFromApiRoots(roots);
    final detailIds = responseIds.isNotEmpty
        ? responseIds
        : directItems
              .map((item) => item.id)
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
    final missingCovers = directItems.any(
      (item) => !item.imageUrl.startsWith('http'),
    );
    if (detailIds.isEmpty ||
        (!missingCovers && responseIds.length <= directItems.length)) {
      return directItems;
    }
    final detailedItems = await _fetchSongDetailsDirect(
      detailIds,
      client,
      cookie,
    );
    if (detailedItems.isEmpty) return directItems;
    return _mergePlaylistSongsInIdOrder(detailIds, directItems, detailedItems);
  }

  List<MirrorItem> _mergePlaylistSongsInIdOrder(
    List<String> ids,
    List<MirrorItem> directItems,
    List<MirrorItem> detailedItems,
  ) {
    final byId = <String, MirrorItem>{};
    for (final item in directItems) {
      if (item.id.isNotEmpty) byId[item.id] = item;
    }
    for (final item in detailedItems) {
      if (item.id.isEmpty) continue;
      final existing = byId[item.id];
      if (existing == null || item.imageUrl.startsWith('http')) {
        byId[item.id] = item;
      } else {
        byId[item.id] = MirrorItem(
          domId: item.domId,
          kind: item.kind,
          title: item.title,
          subtitle: item.subtitle,
          imageUrl: existing.imageUrl,
          href: item.href,
        );
      }
    }
    final ordered = <MirrorItem>[];
    final seen = <String>{};
    for (final id in ids) {
      final item = byId[id];
      if (item != null && seen.add(id)) ordered.add(item);
    }
    for (final item in [...detailedItems, ...directItems]) {
      if (item.id.isNotEmpty && seen.add(item.id)) ordered.add(item);
    }
    return ordered;
  }

  List<dynamic> _apiRoots(dynamic decoded) {
    final roots = <dynamic>[decoded];
    if (decoded is Map) {
      final data = decoded['data'];
      final result = decoded['result'];
      final playlist = decoded['playlist'];
      roots.add(data);
      roots.add(result);
      roots.add(playlist);
      if (data is Map) roots.add(data['playlist']);
      if (result is Map) roots.add(result['playlist']);
    }
    return roots.where((item) => item != null).toList(growable: false);
  }

  List<MirrorItem> _apiSongListToItems(List<dynamic> songs, String prefix) {
    final items = <MirrorItem>[];
    for (var i = 0; i < songs.length; i++) {
      final item = _apiSongToMirrorItem(songs[i], i, prefix);
      if (item != null) items.add(item);
    }
    return items;
  }

  MirrorItem? _apiSongToMirrorItem(dynamic source, int index, String prefix) {
    var song = _mapOf(source);
    if (song.containsKey('song')) {
      song = _mapOf(song['song']);
    }
    final id = _stringOf(song['id'] ?? song['songId'] ?? song['trackId']);
    if (id.isEmpty) return null;
    final title = _stringOf(song['name'] ?? song['title']);
    if (title.isEmpty) return null;
    final album = _mapOf(song['al'] ?? song['album']);
    final artist = _apiArtists(song);
    final albumName = _stringOf(album['name']);
    final imageUrl = _absoluteMusicUrl(
      _stringOf(
        album['picUrl'] ??
            album['blurPicUrl'] ??
            album['pic'] ??
            song['picUrl'] ??
            song['coverUrl'] ??
            song['imageUrl'] ??
            song['albumPicUrl'] ??
            song['pic'],
      ),
    );
    return MirrorItem(
      domId: '${prefix}_${id}_$index',
      kind: 'song',
      title: title,
      subtitle: [
        artist,
        albumName,
      ].where((item) => item.isNotEmpty).join(' · '),
      imageUrl: imageUrl,
      href: 'https://music.163.com/#/song?id=$id',
    );
  }

  String _apiArtists(Map<String, dynamic> song) {
    final artists = _listOf(song['ar'] ?? song['artists']);
    return artists
        .map((item) => _stringOf(_mapOf(item)['name']))
        .where((name) => name.isNotEmpty)
        .join(' / ');
  }

  List<String> _trackIdsFromApiRoots(List<dynamic> roots) {
    final ids = <String>[];
    final seen = <String>{};
    for (final root in roots) {
      final map = root is Map ? root : const {};
      for (final key in const ['trackIds', 'trackids', 'ids', 'privileges']) {
        for (final item in _listOf(map[key])) {
          final itemMap = _mapOf(item);
          final id = itemMap.isEmpty
              ? _stringOf(item)
              : _stringOf(
                  itemMap['id'] ?? itemMap['songId'] ?? itemMap['trackId'],
                );
          if (id.isNotEmpty && seen.add(id)) ids.add(id);
        }
      }
    }
    return ids;
  }

  Future<List<MirrorItem>> _fetchSongDetailsDirect(
    List<String> ids,
    HttpClient client,
    String cookie,
  ) async {
    // Keep query strings short enough for every CDN/proxy in the request path.
    // Large playlists previously used chunks of 200, which caused the detail
    // request to fail and left only the first 10 tracks from the playlist page.
    const detailBatchSize = 50;
    final chunks = <List<String>>[
      for (var start = 0; start < ids.length; start += detailBatchSize)
        ids.skip(start).take(detailBatchSize).toList(growable: false),
    ];
    final results = List<List<MirrorItem>>.generate(
      chunks.length,
      (_) => const <MirrorItem>[],
    );
    var nextChunk = 0;

    Future<void> worker() async {
      while (nextChunk < chunks.length) {
        final chunkIndex = nextChunk++;
        final chunk = chunks[chunkIndex];
        results[chunkIndex] = await _fetchSongDetailChunk(
          chunk,
          client,
          cookie,
        );
      }
    }

    final workerCount = chunks.length.clamp(0, 4).toInt();
    await Future.wait(List.generate(workerCount, (_) => worker()));
    for (var index = 0; index < chunks.length; index++) {
      if (results[index].length >= chunks[index].length) continue;
      final retry = await _fetchSongDetailChunk(chunks[index], client, cookie);
      if (retry.length > results[index].length) results[index] = retry;
    }
    return results.expand((items) => items).toList(growable: false);
  }

  Future<List<MirrorItem>> _fetchSongDetailChunk(
    List<String> chunk,
    HttpClient client,
    String cookie,
  ) async {
    if (chunk.isEmpty) return const [];
    final numericIds = chunk
        .map((id) => int.tryParse(id) ?? id)
        .toList(growable: false);
    for (final uri in _songDetailApiUris(numericIds)) {
      try {
        final decoded = await _getMusicJson(client, uri, cookie);
        var nextItems = const <MirrorItem>[];
        for (final root in _apiRoots(decoded)) {
          final rootMap = _mapOf(root);
          final candidate = root is List
              ? root
              : _listOf(
                  rootMap['songs'] ??
                      rootMap['tracks'] ??
                      rootMap['data'] ??
                      rootMap['items'],
                );
          final parsed = _apiSongListToItems(candidate, 'playlist_api');
          if (parsed.length > nextItems.length) nextItems = parsed;
        }
        if (nextItems.isNotEmpty) {
          final byId = <String, MirrorItem>{
            for (final item in nextItems)
              if (item.id.isNotEmpty) item.id: item,
          };
          return chunk
              .map((id) => byId[id])
              .whereType<MirrorItem>()
              .toList(growable: false);
        }
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  Future<void> clickSong(
    MirrorItem song, {
    List<MirrorItem>? fromList,
    int sourceIndex = -1,
    String dynamicColorSource = '',
    bool autoAdvance = false,
    int skipDirection = 1,
    bool resetSkipGuard = false,
  }) async {
    final requestId = ++_playRequestId;
    final requestPlaylist = fromList != null && fromList.isNotEmpty
        ? fromList
        : currentPlaylist;
    final requestIndex = _indexOfSongInList(
      song,
      requestPlaylist,
      sourceIndex: sourceIndex,
    );
    final playbackDynamicSource = _dynamicColorSourceForPlayback(
      requestPlaylist,
      fromList,
      dynamicColorSource,
    );
    _dynamicColorTargetSongId = song.id;
    _playlistDynamicColorSongId = '';
    _playlistDynamicColorArgb = null;
    _playlistDynamicColorCoverUrl = '';
    if (_nativeDynamicColorSongId != song.id) {
      _nativeDynamicColorSongId = '';
      _nativeDynamicColorArgb = null;
    }
    _setDynamicColorSource(playbackDynamicSource);
    _pendingDynamicColorSource = playbackDynamicSource;
    _holdDesktopLyricsDynamicStyle();
    _pendingSong = song;
    _pendingPlaylist = requestPlaylist;
    _pendingSongIndex = requestIndex;
    _pendingPreviousPlayer = player.hasSong ? player : null;
    _pendingPreviousNativeActive = _nativePlaybackActive;
    _pendingAutoAdvance = autoAdvance;
    _pendingSkipDirection = skipDirection < 0 ? -1 : 1;
    if (!autoAdvance || resetSkipGuard) {
      _autoAdvanceSkipGuard = 0;
    }
    _nativePlaybackPending = true;
    _localPauseRequested = false;
    _playIntentHoldUntil = null;
    _playIntentPlaying = null;
    _noticeToken += 1;
    _noticeHideTimer?.cancel();
    noticeMessage = '';
    status = '正在请求播放地址：${song.title}';
    final knownCoverUrl = _knownCoverForDynamicColor(song);
    unawaited(
      prepareSongArtwork(
        song,
        forceMetadata:
            playbackDynamicSource == 'playlist' &&
            !knownCoverUrl.startsWith('http'),
      ),
    );
    if (playbackDynamicSource == 'playlist') {
      unawaited(
        _playlistModule.refreshPlaybackColor(
          requestId: requestId,
          song: song,
          songId: song.id,
        ),
      );
    }
    if (playbackDynamicSource != 'playlist' &&
        knownCoverUrl.startsWith('http')) {
      _requestDynamicThemeFromCoverForSource(
        playbackDynamicSource,
        knownCoverUrl,
        songId: song.id,
        force: true,
      );
    }
    notifyListeners();
    unawaited(_runJavaScript(_silenceOfficialAudioScript));
    if (requestId != _playRequestId) return;
    final requestTimeout = autoAdvance
        ? const Duration(seconds: 10)
        : const Duration(seconds: 14);
    final directResult = await _requestSongUrlDirect(song, requestId).timeout(
      requestTimeout,
      onTimeout: () => <String, dynamic>{
        'type': 'songUrl',
        'requestId': requestId,
        'songId': song.id,
        'title': song.title,
        'artist': song.subtitle,
        'coverUrl': coverFor(song),
        'message': '播放地址请求超时',
        'directApi': true,
      },
    );
    if (requestId != _playRequestId) return;
    await _handleSongUrl(directResult);
  }

  Future<Map<String, dynamic>> _requestSongUrlDirect(
    MirrorItem song,
    int requestId,
  ) async {
    final songId = song.id.trim();
    final resultBase = <String, dynamic>{
      'type': 'songUrl',
      'requestId': requestId,
      'songId': songId,
      'title': song.title,
      'artist': song.subtitle,
      'coverUrl': coverFor(song),
      'directApi': true,
    };
    if (songId.isEmpty) {
      return {...resultBase, 'message': '歌曲 ID 为空'};
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 8);
    try {
      final cookie = await NativeBridge.getCookies(
        'https://music.163.com/',
      ).timeout(const Duration(seconds: 2), onTimeout: () => '');
      var sawVipBlocked = false;
      for (final uri in _songUrlApiUris(songId)) {
        if (requestId != _playRequestId) {
          return {...resultBase, 'message': '播放请求已取消'};
        }
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 8));
        request.headers.set(HttpHeaders.userAgentHeader, _desktopUserAgent);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(
          HttpHeaders.refererHeader,
          'https://music.163.com/',
        );
        if (cookie.isNotEmpty) {
          request.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final decoded = jsonDecode(body);
        final vipSignal = _songUrlResponseHasVipSignal(decoded);
        final playable = _firstPlayableFromSongUrlResponse(
          decoded,
          vipMaybe: vipSignal,
        );
        if (playable != null) {
          return {...resultBase, ...playable};
        }
        if (vipSignal) {
          sawVipBlocked = true;
        }
      }
      if (sawVipBlocked) {
        return {...resultBase, 'vipBlocked': true, 'message': 'VIP歌曲，需会员播放'};
      }
      return {...resultBase, 'message': '接口未返回可播放地址'};
    } catch (error) {
      return {...resultBase, 'message': '播放地址请求失败：$error'};
    } finally {
      client.close(force: true);
    }
  }

  List<Uri> _songUrlApiUris(String songId) {
    final numericId = int.tryParse(songId);
    final ids = jsonEncode([numericId ?? songId]);
    final qualityOrder =
        <String, List<String>>{
          'standard': ['standard'],
          'higher': ['higher', 'standard'],
          'exhigh': ['exhigh', 'higher', 'standard'],
          'lossless': ['lossless', 'exhigh', 'higher', 'standard'],
        }[audioQuality] ??
        const ['higher', 'standard'];
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final uris = <Uri>[];
    for (final level in qualityOrder) {
      uris.add(
        Uri.https('music.163.com', '/api/song/enhance/player/url/v1', {
          'ids': ids,
          'level': level,
          'encodeType': 'mp3',
          'timestamp': now,
        }),
      );
      uris.add(
        Uri.https('music.163.com', '/api/song/enhance/player/url/v1', {
          'ids': ids,
          'level': level,
          'encodeType': 'aac',
          'timestamp': now,
        }),
      );
    }
    uris.add(
      Uri.https('music.163.com', '/api/song/enhance/player/url', {
        'ids': ids,
        'br': '320000',
        'timestamp': now,
      }),
    );
    uris.add(
      Uri.https('music.163.com', '/api/song/enhance/player/url', {
        'ids': ids,
        'br': '128000',
        'timestamp': now,
      }),
    );
    return uris;
  }

  Map<String, dynamic>? _firstPlayableFromSongUrlResponse(
    dynamic decoded, {
    bool vipMaybe = false,
  }) {
    if (decoded is! Map) return null;
    final candidate = decoded['data'] ?? decoded['urls'] ?? decoded['songs'];
    final list = candidate is List ? candidate : [candidate];
    for (final item in list) {
      if (item is! Map) continue;
      var url = _stringOf(item['url']);
      if (url.isEmpty) url = _stringOf(item['playUrl']);
      if (url.isEmpty) url = _stringOf(item['src']);
      if (url.isEmpty) continue;
      if (url.startsWith('//')) url = 'https:$url';
      return {
        'url': url,
        'br': _intOf(item['br'] ?? item['bitrate']),
        'level': _stringOf(item['level'] ?? item['type']),
        'vipMaybe': vipMaybe,
        'message': '',
      };
    }
    return null;
  }

  bool _songUrlResponseHasVipSignal(dynamic decoded) {
    if (decoded is! Map) return false;
    final candidate = decoded['data'] ?? decoded['urls'] ?? decoded['songs'];
    final list = candidate is List ? candidate : [candidate];
    final rootMessage = _stringOf(decoded['message'] ?? decoded['msg']);
    for (final item in list) {
      if (item is! Map) continue;
      final fee = _intOf(item['fee'] ?? item['feeType']);
      final code = _intOf(item['code'] ?? decoded['code']);
      final message = [
        rootMessage,
        _stringOf(item['message'] ?? item['msg']),
        _stringOf(item['level']),
        _stringOf(item['freeTrialInfo']),
        _stringOf(item['freeTrialPrivilege']),
        _stringOf(item['chargeInfoList']),
      ].join(' ');
      final mentionsVip =
          message.contains('VIP') ||
          message.contains('会员') ||
          message.contains('付费') ||
          message.contains('尊享') ||
          message.contains('vip');
      if (fee == 1 || fee == 4) return true;
      if (code == 403 && mentionsVip) return true;
      if (mentionsVip) return true;
    }
    return false;
  }

  MirrorItem? get nextSong {
    final index = _nextSongIndex();
    return index >= 0 ? currentPlaylist[index] : null;
  }

  MirrorItem? get previousSong {
    final index = _previousSongIndex();
    return index >= 0 ? currentPlaylist[index] : null;
  }

  int _nextSongIndex({bool naturalEnd = false}) {
    return _playbackOrder.nextIndex(
      songs: currentPlaylist,
      currentIndex: currentSongIndex,
      mode: player.mode,
      naturalEnd: naturalEnd,
    );
  }

  int _previousSongIndex() {
    return _playbackOrder.previousIndex(
      songs: currentPlaylist,
      currentIndex: currentSongIndex,
      mode: player.mode,
    );
  }

  Future<void> playNext({bool autoAdvance = false}) async {
    final targetIndex = _nextSongIndex();
    final target = targetIndex >= 0 ? currentPlaylist[targetIndex] : null;
    if (target != null) {
      await clickSong(
        target,
        fromList: currentPlaylist,
        sourceIndex: targetIndex,
        autoAdvance: autoAdvance,
        skipDirection: 1,
        resetSkipGuard: autoAdvance,
      );
      return;
    }
    await playerControl('next', preferNativeList: false);
  }

  Future<void> playPrevious({bool autoAdvance = false}) async {
    final targetIndex = _previousSongIndex();
    final target = targetIndex >= 0 ? currentPlaylist[targetIndex] : null;
    if (target != null) {
      await clickSong(
        target,
        fromList: currentPlaylist,
        sourceIndex: targetIndex,
        autoAdvance: autoAdvance,
        skipDirection: -1,
        resetSkipGuard: autoAdvance,
      );
      return;
    }
    await playerControl('previous', preferNativeList: false);
  }

  Future<void> _handleSystemMediaCommand(
    String action,
    Map<String, dynamic> arguments,
  ) async {
    if (action == 'coverColorChanged') {
      if (!dynamicColorEnabled) return;
      final songId = _stringOf(arguments['songId']);
      if (songId.isNotEmpty &&
          player.songId.isNotEmpty &&
          songId != player.songId) {
        return;
      }
      final color = _nativeOpaqueColor(arguments['color']);
      if (color == null) return;
      final coverUrl = _absoluteMusicUrl(_stringOf(arguments['coverUrl']));
      final source = _activePlaybackDynamicSongId == songId
          ? _activePlaybackDynamicSource
          : _dynamicColorSourceForSongState(
              songId: songId,
              title: player.title,
              artist: player.displayArtist,
            );
      _setDynamicColorSource(source);
      final playlistColorAlreadyResolved =
          source == 'playlist' &&
          songId.isNotEmpty &&
          _playlistDynamicColorSongId == songId &&
          _playlistDynamicColorArgb != null;
      if (songId.isNotEmpty && coverUrl.startsWith('http')) {
        songCoverCache = {...songCoverCache, songId: coverUrl};
      }
      if (coverUrl.startsWith('http') && player.coverUrl != coverUrl) {
        player = _playerWith(coverUrl: coverUrl);
      }
      if (!playlistColorAlreadyResolved) {
        await _applyDynamicThemeColor(
          color,
          coverUrl: coverUrl,
          songId: songId,
          force: true,
          syncDesktopLyrics: false,
          authoritative: true,
        );
      }
      _scheduleSongCoverNotify();
      return;
    }
    if (action == '__systemThemeChanged') {
      final next = arguments['dark'] == true;
      if (systemDarkMode != next) {
        systemDarkMode = next;
        if (themeMode == 'system') {
          notifyListeners();
        }
      }
      return;
    }
    if (action == 'ended') {
      final endedSongId = _stringOf(arguments['songId']);
      if (endedSongId.isNotEmpty &&
          player.songId.isNotEmpty &&
          endedSongId != player.songId) {
        return;
      }
      _handleNativeTrackEnded();
      return;
    }
    if (action == 'previous') {
      await playPrevious(autoAdvance: true);
      return;
    }
    if (action == 'next') {
      await playNext(autoAdvance: true);
      return;
    }
    if (action == 'pause') {
      _localPauseRequested = true;
      player = _playerWith(playing: false);
      notifyListeners();
      await refreshPlayerState();
      return;
    }
    if (action == 'audioFocusPaused') {
      _localPauseRequested = false;
      _playIntentHoldUntil = null;
      _playIntentPlaying = null;
      player = _playerWith(playing: false);
      notifyListeners();
      await refreshPlayerState();
      return;
    }
    if (action == 'headsetDisconnected') {
      _localPauseRequested = true;
      _playIntentHoldUntil = null;
      _playIntentPlaying = null;
      player = _playerWith(playing: false);
      status = '耳机断开，已暂停';
      notifyListeners();
      await refreshPlayerState();
      return;
    }
    if (action == 'play') {
      _localPauseRequested = false;
      if (!_nativePlaybackActive && player.hasSong) {
        await clickSong(
          player.asMirrorItem(),
          fromList: currentPlaylist,
          sourceIndex: currentSongIndex,
          dynamicColorSource: _activePlaybackDynamicSource,
        );
        return;
      }
      player = _playerWith(playing: true);
      notifyListeners();
      await refreshPlayerState();
      return;
    }
    if (action == 'seek') {
      final positionMs = _intOf(arguments['positionMs']);
      if (player.durationMilliseconds > 0) {
        await seekPlayerTo(positionMs / player.durationMilliseconds);
      }
      return;
    }
    await refreshPlayerState();
  }

  Future<void> openSongDetail(MirrorItem song) async {
    _songDetailRequestKey = song.id.isNotEmpty
        ? song.id
        : (song.href.isNotEmpty ? song.href : song.title);
    final cachedCover = coverFor(song);
    final currentCover = song.id == player.songId ? player.coverUrl : '';
    final coverUrl = [
      cachedCover,
      currentCover,
      song.imageUrl,
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    final detailSong = MirrorItem(
      domId: song.domId,
      kind: song.kind,
      title: song.title,
      subtitle: song.subtitle,
      imageUrl: coverUrl,
      href: song.href,
    );
    songDetailLoading = true;
    songDetail = SongDetail.loading(detailSong);
    status = '正在打开歌曲详情：${song.title}';
    notifyListeners();
    final payload = jsonEncode({
      'id': song.id,
      'href': song.href,
      'title': song.title,
      'artist': song.subtitle,
      'coverUrl': coverUrl,
    });
    await _runJavaScript(
      'window.__EMOC_SONG_DETAIL__ = $payload; $_songDetailSnapshotScript',
    );
  }

  Future<void> openCurrentSongDetail() async {
    if (!player.hasSong) return;
    await openSongDetail(player.asMirrorItem());
  }

  Future<void> refreshPlayerState() async {
    if (_nativePlaybackPending) return;
    if (_nativePlaybackActive) {
      await _syncNativePlayerState();
      return;
    }
    if (player.hasSong) return;
    await _runJavaScript(_playerSnapshotScript);
  }

  Future<void> _syncNativePlayerState() async {
    try {
      final state = await NativeBridge.playerState();
      final active = state['active'] == true;
      if (!active) {
        _nativePlaybackActive = false;
        player = _playerWith(playing: false);
        notifyListeners();
        return;
      }
      final currentMs = _intOf(state['currentMs']);
      final durationMs = _intOf(state['durationMs']);
      final nativePlaying = state['playing'] == true;
      final nativeCoverUrl = _absoluteMusicUrl(_stringOf(state['coverUrl']));
      final nativeSongId = _stringOf(state['songId']);
      final effectiveSongId = nativeSongId.isNotEmpty
          ? nativeSongId
          : player.songId;
      final nativeTitle = _stringOf(state['title']);
      final nativeArtist = _stringOf(state['artist']);
      final effectiveTitle = nativeTitle.isNotEmpty
          ? nativeTitle
          : player.title;
      final effectiveArtist = nativeArtist.isNotEmpty
          ? nativeArtist
          : player.artist;
      final previousPlayer = player;
      final effectiveDynamicSource = _dynamicColorSourceForSongState(
        songId: effectiveSongId,
        title: effectiveTitle,
        artist: effectiveArtist,
      );
      _setDynamicColorSource(effectiveDynamicSource);
      final nativeCoverSongId = _stringOf(state['coverSongId']);
      final nativeCoverBelongsToSong =
          nativeCoverUrl.startsWith('http') &&
          (effectiveSongId.isEmpty || nativeCoverSongId == effectiveSongId);
      final effectiveCoverUrl = _knownCoverForSongState(
        songId: effectiveSongId,
        title: effectiveTitle,
        artist: effectiveArtist,
        fallback: nativeCoverBelongsToSong ? nativeCoverUrl : '',
      );
      final nativeCoverChanged =
          effectiveCoverUrl.startsWith('http') &&
          effectiveCoverUrl != player.coverUrl;
      final nativeEnded =
          state['ended'] == true ||
          (durationMs > 0 &&
              currentMs >= durationMs - 700 &&
              !nativePlaying &&
              player.playing);
      if (_localPauseRequested && nativePlaying) {
        unawaited(NativeBridge.pausePlayer());
      }
      var effectivePlaying = nativePlaying && !_localPauseRequested;
      if (_playIntentHoldActive && _playIntentPlaying != null && !nativeEnded) {
        effectivePlaying = _playIntentPlaying!;
        if (_playIntentPlaying == nativePlaying && !_localPauseRequested) {
          _playIntentHoldUntil = null;
          _playIntentPlaying = null;
        }
      } else {
        _playIntentHoldUntil = null;
        _playIntentPlaying = null;
      }
      player = _playerWith(
        songId: effectiveSongId.isNotEmpty ? effectiveSongId : null,
        playing: effectivePlaying,
        coverUrl: effectiveCoverUrl.startsWith('http')
            ? effectiveCoverUrl
            : (effectiveSongId != previousPlayer.songId
                  ? ''
                  : previousPlayer.coverUrl),
        currentSeconds: (currentMs / 1000).floor(),
        durationSeconds: durationMs > 0
            ? (durationMs / 1000).ceil()
            : player.durationSeconds,
        currentMilliseconds: currentMs,
        durationMilliseconds: durationMs > 0
            ? durationMs
            : player.durationMilliseconds,
      );
      if (effectiveCoverUrl.startsWith('http') && effectiveSongId.isNotEmpty) {
        songCoverCache = {
          ...songCoverCache,
          effectiveSongId: effectiveCoverUrl,
        };
      }
      final shouldForceDynamic =
          nativeCoverChanged ||
          (effectiveSongId.isNotEmpty &&
              effectiveSongId != _dynamicColorSongId) ||
          (effectiveCoverUrl.startsWith('http') &&
              effectiveCoverUrl != _dynamicColorCoverUrl);
      final nativeCoverColor = _nativeOpaqueColor(state['coverColor']);
      final nativeCoverColorSongId = _stringOf(state['coverColorSongId']);
      final nativeColorMatches =
          dynamicColorEnabled &&
          nativeCoverColor != null &&
          (effectiveSongId.isEmpty
              ? nativeCoverColorSongId.isEmpty
              : nativeCoverColorSongId == effectiveSongId);
      final hasCurrentColorAuthority =
          effectiveSongId.isNotEmpty &&
          _nativeDynamicColorSongId == effectiveSongId &&
          _nativeDynamicColorArgb != null;
      final shouldApplyNativeColor =
          nativeColorMatches &&
          !hasCurrentColorAuthority &&
          (themeSeedColor.toARGB32() != nativeCoverColor.toARGB32() ||
              effectiveSongId != _dynamicColorSongId);
      if (shouldApplyNativeColor) {
        unawaited(
          _applyDynamicThemeColor(
            nativeCoverColor,
            coverUrl: effectiveCoverUrl,
            songId: effectiveSongId,
            force: true,
            syncDesktopLyrics: false,
          ),
        );
      } else if (!nativeColorMatches && !hasCurrentColorAuthority) {
        if (effectiveDynamicSource == 'playlist') {
          final playlistSong = currentPlaylist.firstWhere(
            (song) => _songStateMatches(
              song,
              songId: effectiveSongId,
              title: effectiveTitle,
              artist: effectiveArtist,
            ),
            orElse: () => player.asMirrorItem(),
          );
          unawaited(
            _playlistModule.refreshPlaybackColor(
              requestId: _playRequestId,
              song: playlistSong,
              songId: effectiveSongId,
              force: shouldForceDynamic,
            ),
          );
        } else {
          _requestDynamicThemeFromCover(
            effectiveCoverUrl,
            songId: effectiveSongId,
            force: shouldForceDynamic,
          );
        }
      }
      if (_playerPresentationChanged(previousPlayer, player)) {
        notifyListeners();
      } else {
        _notifyPlaybackProgress();
      }
      if (nativeEnded && !_localPauseRequested) {
        _handleNativeTrackEnded();
      }
    } catch (_) {}
  }

  bool _playerPresentationChanged(
    PlayerSnapshot previous,
    PlayerSnapshot next,
  ) {
    return previous.visible != next.visible ||
        previous.songId != next.songId ||
        previous.title != next.title ||
        previous.artist != next.artist ||
        previous.source != next.source ||
        previous.coverUrl != next.coverUrl ||
        previous.playing != next.playing ||
        previous.durationMilliseconds != next.durationMilliseconds ||
        previous.volume != next.volume ||
        previous.mode != next.mode;
  }

  void _notifyPlaybackProgress() {
    playbackRevision.value += 1;
    _syncDesktopLyrics();
  }

  void _handleNativeTrackEnded() {
    if (_autoAdvanceInProgress) return;
    _autoAdvanceInProgress = true;
    final endedSongId = player.songId;
    _autoAdvanceWatchdog?.cancel();
    _autoAdvanceWatchdog = Timer(const Duration(seconds: 16), () {
      if (!_autoAdvanceInProgress) return;
      if (player.songId != endedSongId && player.playing) {
        _autoAdvanceInProgress = false;
        return;
      }
      if (_nativePlaybackPending && _pendingAutoAdvance) {
        _handleBlockedPendingSong('自动续播超时', autoSkip: true);
        return;
      }
      _autoAdvanceInProgress = false;
      if (!_localPauseRequested && player.songId == endedSongId) {
        _handleNativeTrackEnded();
      }
    });
    unawaited(_advanceAfterNativeEnd());
  }

  Future<void> _advanceAfterNativeEnd() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final targetIndex = _nextSongIndex(naturalEnd: true);
      final target = targetIndex >= 0 ? currentPlaylist[targetIndex] : null;
      if (target == null) {
        try {
          await NativeBridge.stopPlayer();
        } catch (_) {}
        _nativePlaybackActive = false;
        _nativePlaybackPending = false;
        player = _playerWith(
          playing: false,
          currentSeconds: player.durationSeconds,
          currentMilliseconds: player.durationMilliseconds,
        );
        notifyListeners();
        return;
      }
      await clickSong(
        target,
        fromList: currentPlaylist,
        sourceIndex: targetIndex,
        autoAdvance: true,
        skipDirection: 1,
        resetSkipGuard: true,
      );
    } finally {
      if (!_nativePlaybackPending || !_pendingAutoAdvance) {
        _autoAdvanceInProgress = false;
        _autoAdvanceWatchdog?.cancel();
      }
    }
  }

  Future<void> playerControl(
    String action, {
    bool preferNativeList = true,
  }) async {
    if (preferNativeList && action == 'previous') {
      await playPrevious(autoAdvance: true);
      return;
    }
    if (preferNativeList && action == 'next') {
      await playNext(autoAdvance: true);
      return;
    }
    if (action == 'toggle') {
      if (_nativePlaybackPending) return;
      if (_nativePlaybackActive) {
        final shouldPlay = !player.playing;
        _localPauseRequested = !shouldPlay;
        _playIntentPlaying = shouldPlay;
        _playIntentHoldUntil = DateTime.now().add(const Duration(seconds: 4));
        player = _playerWith(playing: shouldPlay);
        notifyListeners();
        try {
          if (shouldPlay) {
            await NativeBridge.resumePlayer();
          } else {
            await NativeBridge.pausePlayer();
          }
        } catch (error) {
          _playIntentHoldUntil = null;
          _playIntentPlaying = null;
          if (shouldPlay &&
              player.hasSong &&
              error.toString().contains('NO_ACTIVE_PLAYER')) {
            // The cached player card can outlive the Android player process.
            // Rebuild the same track instead of leaving a dead play button.
            _nativePlaybackActive = false;
            _localPauseRequested = false;
            await clickSong(
              player.asMirrorItem(),
              fromList: currentPlaylist,
              sourceIndex: currentSongIndex,
            );
            return;
          }
          if (shouldPlay) {
            _localPauseRequested = true;
            player = _playerWith(playing: false);
          }
          status = '播放控制失败：$error';
          notifyListeners();
          return;
        }
        await Future<void>.delayed(
          Duration(milliseconds: shouldPlay ? 650 : 120),
        );
        if (!_playIntentHoldActive || !shouldPlay) {
          await _syncNativePlayerState();
        }
        return;
      }
      if (player.hasSong) {
        _localPauseRequested = false;
        await clickSong(
          player.asMirrorItem(),
          fromList: currentPlaylist,
          sourceIndex: currentSongIndex,
        );
      }
      return;
    }
    if (action == 'mode') {
      if (_modeSwitching) return;
      _modeSwitching = true;
      final nextMode = player.mode == 'loop'
          ? 'shuffle'
          : player.mode == 'shuffle'
          ? 'one'
          : 'loop';
      try {
        await _setPlaybackMode(nextMode);
      } finally {
        _modeSwitching = false;
      }
      return;
    }
    if (action == 'previous' || action == 'next') {
      final targetIndex = action == 'next'
          ? _nextSongIndex()
          : _previousSongIndex();
      final target = targetIndex >= 0 ? currentPlaylist[targetIndex] : null;
      if (target != null) {
        await clickSong(
          target,
          fromList: currentPlaylist,
          sourceIndex: targetIndex,
          autoAdvance: true,
          skipDirection: action == 'next' ? 1 : -1,
          resetSkipGuard: true,
        );
      }
      return;
    }
    await _runJavaScript(_playerControlScript(action));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await refreshPlayerState();
  }

  Future<void> setPlayerVolume(double value) async {
    desiredVolume = value.clamp(0, 1).toDouble();
    player = PlayerSnapshot(
      visible: player.visible,
      songId: player.songId,
      title: player.title,
      artist: player.artist,
      source: player.source,
      coverUrl: player.coverUrl,
      playing: player.playing,
      currentSeconds: player.currentSeconds,
      durationSeconds: player.durationSeconds,
      currentMilliseconds: player.currentMilliseconds,
      durationMilliseconds: player.durationMilliseconds,
      volume: desiredVolume,
      mode: player.mode,
    );
    notifyListeners();
    try {
      await NativeBridge.setString(
        'desiredVolume',
        desiredVolume.toStringAsFixed(3),
      );
    } catch (_) {}
    if (_nativePlaybackActive) {
      try {
        await NativeBridge.setPlayerVolume(desiredVolume);
      } catch (_) {}
      return;
    }
  }

  Future<void> seekPlayerTo(double fraction) async {
    if (player.durationSeconds <= 0) return;
    final normalized = fraction.clamp(0, 1).toDouble();
    final target = (player.durationSeconds * normalized).round();
    final targetMs =
        (player.durationMilliseconds > 0
                ? player.durationMilliseconds * normalized
                : target * 1000)
            .round();
    _seekHoldSeconds = target;
    _seekHoldUntil = DateTime.now().add(const Duration(milliseconds: 2500));
    player = _playerWith(currentSeconds: target, currentMilliseconds: targetMs);
    notifyListeners();
    if (_nativePlaybackActive) {
      try {
        await NativeBridge.seekPlayer(Duration(milliseconds: targetMs));
      } catch (_) {}
      await _syncNativePlayerState();
      return;
    }
  }

  Future<void> loadPlayerQueue() async {
    queueLoading = true;
    notifyListeners();
    if (currentPlaylist.isNotEmpty) {
      playerQueue = currentPlaylist;
      queueLoading = false;
      _scheduleCurrentPlaylistCacheSave();
      notifyListeners();
      return;
    }
    await _runJavaScript(_queueSnapshotScript);
  }

  Future<void> addCurrentSongToPlaylist(MirrorItem playlist) async {
    final songId = player.songId.isNotEmpty
        ? player.songId
        : (currentSongIndex >= 0 && currentSongIndex < currentPlaylist.length
              ? currentPlaylist[currentSongIndex].id
              : '');
    if (songId.isEmpty || playlist.id.isEmpty) {
      status = '当前歌曲或歌单 ID 不完整，无法收藏';
      notifyListeners();
      return;
    }
    status = '正在收藏到：${playlist.title}';
    notifyListeners();
    try {
      if (playlist.kind == 'liked') {
        await _musicMutationApiClient.setSongLiked(songId, true);
      } else {
        await _musicMutationApiClient.addSongToPlaylist(playlist.id, songId);
      }
      await _invalidatePlaylistSongsCache(playlist.id);
      status = '已收藏到：${playlist.title}';
      _showNotice('收藏成功');
      notifyListeners();
      unawaited(loadLibrary());
    } catch (error) {
      status = '收藏失败：$error';
      _showNotice('收藏失败：$error');
      notifyListeners();
    }
  }

  Future<void> likeCurrentSong() async {
    final songId = player.songId.isNotEmpty
        ? player.songId
        : (currentSongIndex >= 0 && currentSongIndex < currentPlaylist.length
              ? currentPlaylist[currentSongIndex].id
              : '');
    if (songId.isEmpty) {
      _showNotice('当前歌曲 ID 不完整，无法收藏');
      return;
    }
    status = '正在添加到我喜欢的音乐';
    notifyListeners();
    try {
      await _musicMutationApiClient.setSongLiked(songId, true);
      final likedPlaylists = libraryPlaylists
          .where((item) => item.kind == 'liked')
          .toList(growable: false);
      if (likedPlaylists.isNotEmpty) {
        await _invalidatePlaylistSongsCache(likedPlaylists.first.id);
      }
      status = '已添加到我喜欢的音乐';
      _showNotice('收藏成功');
      notifyListeners();
      unawaited(loadLibrary());
    } catch (error) {
      status = '收藏失败：$error';
      _showNotice('收藏失败：$error');
      notifyListeners();
    }
  }

  void _clearPendingPlaybackRequest() {
    _pendingSong = null;
    _pendingPlaylist = const [];
    _pendingSongIndex = -1;
    _pendingPreviousPlayer = null;
    _pendingPreviousNativeActive = false;
    _pendingAutoAdvance = false;
    _pendingSkipDirection = 1;
    _pendingDynamicColorSource = _dynamicColorSource;
  }

  PlayerSnapshot _snapshotForSong(
    MirrorItem song, {
    bool playing = false,
    String songId = '',
    String coverUrl = '',
  }) {
    final effectiveSongId = songId.isNotEmpty ? songId : song.id;
    final effectiveCoverUrl = coverUrl.startsWith('http')
        ? coverUrl
        : coverFor(song);
    return PlayerSnapshot(
      visible: true,
      songId: effectiveSongId,
      title: song.title,
      artist: song.subtitle,
      source: '',
      coverUrl: effectiveCoverUrl,
      playing: playing,
      currentSeconds: 0,
      durationSeconds: 0,
      currentMilliseconds: 0,
      durationMilliseconds: 0,
      volume: desiredVolume,
      mode: player.mode,
    );
  }

  bool _validPlaybackMode(String? mode) {
    return mode == 'loop' || mode == 'shuffle' || mode == 'one';
  }

  Future<void> _setPlaybackMode(String mode, {bool persist = true}) async {
    if (!_validPlaybackMode(mode)) return;
    player = _playerWith(mode: mode);
    notifyListeners();
    if (persist) {
      try {
        await NativeBridge.setString('playbackMode', mode);
      } catch (_) {}
    }
  }

  int _indexOfSongInList(
    MirrorItem song,
    List<MirrorItem> list, {
    int sourceIndex = -1,
  }) {
    if (list.isEmpty) return -1;
    if (sourceIndex >= 0 && sourceIndex < list.length) {
      final candidate = list[sourceIndex];
      if (identical(candidate, song) || _sameSong(candidate, song)) {
        return sourceIndex;
      }
    }
    final identityIndex = list.indexWhere((item) => identical(item, song));
    if (identityIndex >= 0) return identityIndex;
    if (song.id.isNotEmpty) {
      final index = list.indexWhere((item) => item.id == song.id);
      if (index >= 0) return index;
    }
    if (song.href.isNotEmpty) {
      final index = list.indexWhere((item) => item.href == song.href);
      if (index >= 0) return index;
    }
    return list.indexWhere((item) => _sameSong(item, song));
  }

  bool _sameSong(MirrorItem a, MirrorItem b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty) return a.id == b.id;
    if (a.href.isNotEmpty && b.href.isNotEmpty) return a.href == b.href;
    return a.title == b.title && a.subtitle == b.subtitle;
  }

  bool _pendingRequestMatches(String songId) {
    final pending = _pendingSong;
    if (pending == null) return false;
    if (songId.isEmpty || pending.id.isEmpty) return true;
    return songId == pending.id;
  }

  void _commitPendingSong({
    String resolvedCoverUrl = '',
    String resolvedSongId = '',
  }) {
    final pending = _pendingSong;
    if (pending == null) return;
    final effectiveSongId = resolvedSongId.isNotEmpty
        ? resolvedSongId
        : pending.id;
    _activePlaybackDynamicSource = _pendingDynamicColorSource;
    _activePlaybackDynamicSongId = effectiveSongId;
    _dynamicColorTargetSongId = effectiveSongId;
    if (_pendingPlaylist.isNotEmpty) {
      currentPlaylist = _pendingPlaylist;
    }
    currentSongIndex = _pendingSongIndex;
    _scheduleCurrentPlaylistCacheSave();
    playerBarVisible = true;
    player = _snapshotForSong(
      pending,
      songId: effectiveSongId,
      coverUrl: resolvedCoverUrl,
    );
    if (!_songDetailMatchesPlayer(player)) {
      songDetail = null;
      songDetailLoading = false;
      queueLyricLines = const [];
      _lastDesktopLyricsDetailRequestKey = '';
      _lastDesktopLyricsPayloadKey = '';
    }
    if (effectiveSongId.isNotEmpty && player.coverUrl.startsWith('http')) {
      songCoverCache = {...songCoverCache, effectiveSongId: player.coverUrl};
    }
    _requestDynamicThemeFromCoverForSource(
      _pendingDynamicColorSource,
      player.coverUrl,
      songId: effectiveSongId,
      force: resolvedCoverUrl.startsWith('http'),
    );
  }

  void _schedulePlaylistDynamicThemeRecovery({
    required int requestId,
    required MirrorItem song,
    required String songId,
    required String source,
  }) {
    if (!dynamicColorEnabled || source != 'playlist') return;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        final currentCover = _absoluteMusicUrl(
          _knownCoverForDynamicColor(song),
        ).trim();
        if (requestId != _playRequestId ||
            !dynamicColorEnabled ||
            _activePlaybackDynamicSource != 'playlist' ||
            _activePlaybackDynamicSongId != songId ||
            (_playlistDynamicColorSongId == songId &&
                _playlistDynamicColorArgb != null &&
                currentCover == _playlistDynamicColorCoverUrl)) {
          return;
        }
        unawaited(
          _playlistModule.refreshPlaybackColor(
            requestId: requestId,
            song: song,
            songId: songId,
            force: true,
          ),
        );
      }),
    );
  }

  void _restoreBeforePendingSong() {
    final previous = _pendingPreviousPlayer;
    _nativePlaybackActive = _pendingPreviousNativeActive;
    if (previous != null) {
      player = previous;
      playerBarVisible = true;
      _dynamicColorTargetSongId = previous.songId;
    } else {
      player = PlayerSnapshot.empty;
      playerBarVisible = false;
      _dynamicColorTargetSongId = '';
    }
  }

  void _handleBlockedPendingSong(String reason, {required bool autoSkip}) {
    final blockedPlaylist = _pendingPlaylist;
    final blockedIndex = _pendingSongIndex;
    final skipDirection = _pendingSkipDirection;
    _nativePlaybackPending = false;
    _restoreBeforePendingSong();
    _clearPendingPlaybackRequest();
    final warning = _shortPlaybackWarning(reason);
    status = autoSkip && blockedPlaylist.isNotEmpty
        ? _skipStatusFor(reason)
        : warning;
    if ((!autoSkip || blockedPlaylist.isEmpty) &&
        _shouldShowPlaybackNotice(warning)) {
      _showNotice(warning);
    }
    notifyListeners();

    if (!autoSkip || blockedPlaylist.isEmpty) {
      _autoAdvanceInProgress = false;
      return;
    }
    _autoAdvanceSkipGuard += 1;
    if (_autoAdvanceSkipGuard >= blockedPlaylist.length) {
      unawaited(NativeBridge.stopPlayer());
      _nativePlaybackActive = false;
      _autoAdvanceInProgress = false;
      player = _playerWith(playing: false);
      status = '没有可播放歌曲';
      notifyListeners();
      return;
    }

    final start = blockedIndex >= 0 ? blockedIndex : currentSongIndex;
    final nextIndex =
        (start + skipDirection + blockedPlaylist.length) %
        blockedPlaylist.length;
    unawaited(
      clickSong(
        blockedPlaylist[nextIndex],
        fromList: blockedPlaylist,
        sourceIndex: nextIndex,
        autoAdvance: true,
        skipDirection: skipDirection,
      ),
    );
  }

  String _shortPlaybackWarning(String reason) {
    final value = reason.trim();
    if (value.contains('VIP') || value.contains('会员') || value.contains('尊享')) {
      return 'VIP歌曲，需会员播放';
    }
    if (value.contains('超时')) return '播放超时';
    if (value.contains('版权') || value.contains('地区')) return '暂无版权或地区受限';
    if (value.length <= 18) return value;
    return '${value.substring(0, 18)}...';
  }

  bool _shouldShowPlaybackNotice(String warning) {
    final value = warning.trim();
    if (value.isEmpty) return false;
    if (value.contains('VIP') || value.contains('会员') || value.contains('尊享')) {
      return true;
    }
    final transientMarkers = <String>[
      '官网',
      '接口',
      '播放地址',
      '播放链接',
      '播放器',
      '启动失败',
      '加载失败',
      '请求',
      '返回',
      '超时',
      '未找到',
      '版权',
      '地区',
    ];
    return !transientMarkers.any(value.contains);
  }

  String _skipStatusFor(String reason) {
    if (reason.contains('VIP') ||
        reason.contains('会员') ||
        reason.contains('尊享')) {
      return '已跳过VIP歌曲';
    }
    return '已跳过不可播放歌曲';
  }

  PlayerSnapshot _playerWith({
    bool? visible,
    String? songId,
    String? title,
    String? artist,
    String? source,
    String? coverUrl,
    bool? playing,
    int? currentSeconds,
    int? durationSeconds,
    int? currentMilliseconds,
    int? durationMilliseconds,
    double? volume,
    String? mode,
  }) {
    final nextCurrentSeconds = currentSeconds ?? player.currentSeconds;
    final nextDurationSeconds = durationSeconds ?? player.durationSeconds;
    final nextCurrentMilliseconds =
        currentMilliseconds ??
        (currentSeconds == null
            ? player.currentMilliseconds
            : nextCurrentSeconds * 1000);
    final nextDurationMilliseconds =
        durationMilliseconds ??
        (durationSeconds == null
            ? player.durationMilliseconds
            : nextDurationSeconds * 1000);
    return PlayerSnapshot(
      visible: visible ?? player.visible,
      songId: songId ?? player.songId,
      title: title ?? player.title,
      artist: artist ?? player.artist,
      source: source ?? player.source,
      coverUrl: coverUrl ?? player.coverUrl,
      playing: playing ?? player.playing,
      currentSeconds: nextCurrentSeconds,
      durationSeconds: nextDurationSeconds,
      currentMilliseconds: nextCurrentMilliseconds,
      durationMilliseconds: nextDurationMilliseconds,
      volume: volume ?? player.volume,
      mode: mode ?? player.mode,
    );
  }

  Future<void> updateSearchQuery(String query) async {
    searchQuery = query;
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      searchSuggestions = const [];
      searchResults = const [];
      searchLoading = false;
      notifyListeners();
      return;
    }
    searchLoading = true;
    notifyListeners();
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_loadSearchSuggestions(query)),
    );
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    searchQuery = '';
    searchSuggestions = const [];
    searchResults = const [];
    searchLoading = false;
    status = dailySongs.isEmpty ? status : '已返回首页每日推荐';
    notifyListeners();
  }

  Future<void> submitSearch(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    searchQuery = value;
    searchSuggestions = const [];
    searchLoading = true;
    status = '正在搜索：$value';
    notifyListeners();
    final encoded = Uri.encodeComponent(value);
    final controller = await _ensureWebController();
    if (controller == null) return;
    await controller.loadRequest(
      Uri.parse('https://music.163.com/#/search/m/?s=$encoded&type=1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _extractPage('search');
    if (searchResults.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _extractPage('search');
    }
  }

  Future<void> openSuggestion(MirrorItem suggestion) async {
    final keyword =
        (suggestion.href.contains('/search/') ? searchQuery : suggestion.title)
            .replaceFirst(RegExp(r'^搜索\s*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    searchSuggestions = const [];
    notifyListeners();
    await submitSearch(keyword.isEmpty ? searchQuery : keyword);
  }

  Future<WebViewController?> _ensureWebController() async {
    if (webController != null) return webController;
    try {
      _configureWebView();
      notifyListeners();
      return webController;
    } catch (error) {
      status = 'Web 会话初始化失败：$error';
      loginLoading = false;
      dailyLoading = false;
      libraryLoading = false;
      playlistLoading = false;
      searchLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> _useDesktopWebSession() async {
    final controller = await _ensureWebController();
    if (controller == null) return;
    try {
      await controller.setUserAgent(_desktopUserAgent);
    } catch (_) {}
  }

  void _configureWebView() {
    if (webController != null) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F1014))
      ..setUserAgent(_desktopUserAgent)
      ..addJavaScriptChannel(
        'EmoCMirror',
        onMessageReceived: (message) => _handleWebMessage(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            pageUrl = url;
            unawaited(_installWebMediaBlockDuringNavigation());
            notifyListeners();
          },
          onPageFinished: (url) async {
            pageUrl = url;
            await _runJavaScript(_onPageReadyScript);
            if (loginGateVisible && smsLoginVisible) {
              await Future<void>.delayed(const Duration(milliseconds: 700));
              await prepareLoginQr();
            } else if (loginGateVisible) {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            } else if (_restoreLoginOnLoad) {
              _restoreLoginOnLoad = false;
              await Future<void>.delayed(const Duration(milliseconds: 900));
              await _runJavaScript(_sessionProbeScript);
              await _extractLoginProjection();
              await enterApp();
            }
          },
          onWebResourceError: (error) {
            status = '官网加载失败：${error.description}';
            dailyLoading = false;
            libraryLoading = false;
            playlistLoading = false;
            searchLoading = false;
            notifyListeners();
          },
        ),
      );
    webController = controller;
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      unawaited(platformController.setMediaPlaybackRequiresUserGesture(true));
      unawaited(
        platformController.setMixedContentMode(MixedContentMode.alwaysAllow),
      );
    }
  }

  Future<void> _installWebMediaBlockDuringNavigation() async {
    for (final delay in <int>[40, 120, 280, 600]) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      await _runJavaScript(_onPageReadyScript);
    }
  }

  Future<void> _openBehindWeb(MirrorItem item) async {
    if (item.href.isNotEmpty) {
      await _navigateOfficial(item.href);
      return;
    }
    final domId = jsonEncode(item.domId);
    await _runJavaScript('''
      (function () {
        var id = $domId;
        function roots() {
          var list = [document];
          var frame = document.querySelector('#g_iframe');
          try { if (frame && frame.contentDocument) list.push(frame.contentDocument); } catch (e) {}
          return list;
        }
        for (var r = 0; r < roots().length; r++) {
          var el = roots()[r].querySelector('[data-emoc-id="' + id + '"]');
          if (el) {
            var target = el.matches('a,button') ? el : el.querySelector('a,button');
            (target || el).click();
            return true;
          }
        }
        return false;
      })();
    ''');
  }

  Future<void> _loadSearchSuggestions(String query) async {
    final encoded = jsonEncode(query);
    await _runJavaScript(
      'window.__EMOC_SEARCH_QUERY__ = $encoded; $_searchScript',
    );
  }

  Future<void> _extractLoginProjection() async {
    await _runJavaScript(_loginProjectionScript);
  }

  Future<void> _extractPage(String context, {String targetId = ''}) async {
    final requestId = ++_snapshotRequestSerial;
    _activeSnapshotRequests[context] = requestId;
    final waiter = Completer<void>();
    _snapshotWaiters[requestId] = waiter;
    final encodedContext = jsonEncode(context);
    final encodedTargetId = jsonEncode(targetId);
    final setupScript =
        'window.__EMOC_SNAPSHOT_REQUEST_ID__ = $requestId; '
        'window.__EMOC_SNAPSHOT_CONTEXT__ = $encodedContext; '
        'window.__EMOC_SNAPSHOT_TARGET_ID__ = $encodedTargetId;';
    await _runJavaScript(setupScript);
    if (context == 'daily') {
      await _runJavaScript(_dailySnapshotScript);
      await _waitForSnapshot(requestId, context);
      return;
    }
    if (context == 'library') {
      await _runJavaScript(_librarySnapshotScript);
      await _waitForSnapshot(requestId, context);
      return;
    }
    if (context == 'playlist') {
      await _runJavaScript(_playlistSnapshotScript);
      await _waitForSnapshot(requestId, context);
      return;
    }
    await _runJavaScript(
      'window.__EMOC_CONTEXT__ = $encodedContext; $_snapshotScript',
    );
    await _waitForSnapshot(requestId, context);
  }

  Future<void> _waitForSnapshot(int requestId, String context) async {
    final waiter = _snapshotWaiters[requestId];
    if (waiter == null) return;
    try {
      await waiter.future.timeout(
        Duration(seconds: context == 'playlist' ? 12 : 6),
        onTimeout: () {},
      );
    } finally {
      _snapshotWaiters.remove(requestId);
      if (_activeSnapshotRequests[context] == requestId) {
        _activeSnapshotRequests.remove(context);
      }
    }
  }

  void _finishSnapshotRequest(int requestId) {
    final waiter = _snapshotWaiters[requestId];
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<void> _navigateOfficial(String url) async {
    final controller = await _ensureWebController();
    if (controller == null) return;
    await _useDesktopWebSession();
    final encoded = jsonEncode(url);
    if (pageUrl.startsWith('https://music.163.com')) {
      await _runJavaScript('window.location.href = $encoded;');
    } else {
      await controller.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _runJavaScript(String source) async {
    try {
      final controller = await _ensureWebController();
      if (controller == null) return;
      await controller.runJavaScript(source);
    } catch (error) {
      status = 'Web 会话执行失败：$error';
      loginLoading = false;
      dailyLoading = false;
      libraryLoading = false;
      playlistLoading = false;
      searchLoading = false;
      notifyListeners();
    }
  }

  void _handleWebMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final type = _stringOf(decoded['type']);
      if (type == 'login') {
        _handleLogin(decoded);
      } else if (type == 'qrLogin') {
        _handleQrLogin(decoded);
      } else if (type == 'smsLogin') {
        _handleSmsLogin(decoded);
      } else if (type == 'suggestions') {
        _handleSuggestions(decoded);
      } else if (type == 'player') {
        _handlePlayer(decoded);
      } else if (type == 'songDetail') {
        _handleSongDetail(decoded);
      } else if (type == 'queue') {
        _handleQueue(decoded);
      } else if (type == 'songUrl') {
        _handleSongUrl(decoded);
      } else if (type == 'playError') {
        final requestId = _intOf(decoded['requestId']);
        if (requestId > 0 && requestId != _playRequestId) return;
        if (requestId == 0 &&
            !_nativePlaybackPending &&
            !_nativePlaybackActive) {
          return;
        }
        final reason = _stringOf(decoded['reason']).isEmpty
            ? '该歌曲暂无法播放'
            : _stringOf(decoded['reason']);
        status = reason;
        _showNotice(reason);
        notifyListeners();
      } else {
        _handleSnapshot(decoded);
      }
    } catch (error) {
      status = '解析内容失败：$error';
      notifyListeners();
    }
  }

  void _handleLogin(Map<String, dynamic> data) {
    final projectedLoggedIn = data['loggedIn'] == true;
    if (projectedLoggedIn) {
      loggedIn = true;
      _clearSwitchAccountBackup();
      _trustSavedLogin = false;
    } else if (!_trustSavedLogin && !(accountActive && !loginGateVisible)) {
      loggedIn = false;
    }
    final projectedAccountName = _stringOf(data['accountName']);
    if (_hasRealAccountName(projectedAccountName)) {
      accountName = projectedAccountName;
    }
    final projectedAvatarUrl = _absoluteMusicUrl(_stringOf(data['avatarUrl']));
    if (projectedAvatarUrl.isNotEmpty) {
      avatarUrl = projectedAvatarUrl;
    }
    if (_stringOf(data['qrImage']).isNotEmpty) {
      loginQrImage = _stringOf(data['qrImage']);
    }
    final projectedMethods = _listOf(data['methods'])
        .map(_stringOf)
        .where((item) => item.isNotEmpty && item.length <= 12)
        .toSet()
        .toList(growable: true);
    if (!projectedMethods.any(
      (item) => item.contains('验证码') || item.contains('手机'),
    )) {
      projectedMethods.add('验证码登录');
    }
    loginMethods = projectedMethods.take(6).toList(growable: false);
    loginLoading = false;
    if (accountActive) {
      loginMessage = '登录成功，正在进入应用';
    } else if (loginQrData.isEmpty && loginQrImage.isEmpty) {
      loginMessage = '未生成二维码，点刷新重试';
    } else if (loginMessage.startsWith('正在') ||
        loginMessage.startsWith('使用网易云音乐') ||
        loginMessage.startsWith('未生成')) {
      loginMessage = '使用网易云音乐扫码登录';
    }
    notifyListeners();
    if (accountActive && loginGateVisible) {
      unawaited(_rememberCurrentAccount(id: _stringOf(data['accountId'])));
      unawaited(_persistLoginState());
      _loginTimer?.cancel();
      _scheduleEnterApp(const Duration(milliseconds: 700));
    } else if (accountActive) {
      unawaited(_rememberCurrentAccount(id: _stringOf(data['accountId'])));
      unawaited(_persistLoginState());
    }
  }

  void _handleQrLogin(Map<String, dynamic> data) {
    final qrData = _stringOf(data['qrData']);
    final message = _stringOf(data['message']);
    final code = _stringOf(data['code']);
    if (qrData.isNotEmpty) {
      loginQrData = qrData;
      loginQrImage = '';
      loginLoading = false;
      loginMessage = '使用网易云音乐扫码登录';
    }
    if (message.isNotEmpty) {
      loginMessage = message;
    }
    if (code == '802') {
      loginMessage = '使用网易云音乐扫码登录';
    } else if (code == '803') {
      loggedIn = true;
      _clearSwitchAccountBackup();
      loginMessage = '登录成功，正在进入应用';
      _loginTimer?.cancel();
      final generation = _loginFlowGeneration;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 250), () async {
          if (generation != _loginFlowGeneration) return;
          await _runJavaScript(_sessionProbeScript);
          if (generation != _loginFlowGeneration) return;
          await _extractLoginProjection();
          if (generation != _loginFlowGeneration) return;
          await _persistLoginState();
        }),
      );
      _scheduleEnterApp(const Duration(milliseconds: 700));
    } else if (code == '800') {
      loginMessage = '二维码已过期，请刷新';
    }
    notifyListeners();
  }

  Future<void> setDynamicColorEnabled(bool value) async {
    dynamicColorEnabled = value;
    await NativeBridge.setString('dynamicColorEnabled', value.toString());
    _clearDynamicColorRequestState();
    _clearNativeDynamicColorAuthority();
    if (!value) {
      themeSeedColor = const Color(0xFF3F7BFF);
      await NativeBridge.setString(
        'themeSeedColor',
        themeSeedColor.toARGB32().toString(),
      );
      notifyListeners();
      return;
    }
    notifyListeners();
    if (_nativePlaybackActive) {
      await _syncNativePlayerState();
    }
    final synced = await _refreshDynamicThemeFromNativePlayback(
      force: true,
      sourceHint: _activePlaybackDynamicSource,
    );
    if (!synced) _refreshDynamicThemeFromCurrentCover(force: true);
  }

  Future<void> setShowSongCovers(bool value) async {
    if (showSongCovers == value) return;
    showSongCovers = value;
    notifyListeners();
    unawaited(
      NativeBridge.setString(
        'showSongCovers',
        value.toString(),
      ).timeout(const Duration(seconds: 2)).catchError((_) {}),
    );
    if (!value) return;
    unawaited(prepareSongArtworkBatch(dailySongs.take(12).toList()));
    unawaited(prepareSongArtworkBatch(playlistSongs.take(18).toList()));
    if (displayPlayer.hasSong) {
      unawaited(prepareSongArtwork(displayPlayer.asMirrorItem()));
    }
  }

  Future<void> setLyricsPlayerStyle(int value) async {
    final next = value.clamp(0, 2);
    if (lyricsPlayerStyle == next) return;
    lyricsPlayerStyle = next;
    notifyListeners();
    try {
      await NativeBridge.setString('lyricsPlayerStyle', next.toString());
    } catch (_) {}
  }

  Future<void> setDesktopLyricsEnabled(bool value) async {
    await _applyDesktopLyricsStyle();
    final applied = value
        ? await NativeBridge.setDesktopLyricsEnabled(
            true,
            requestPermission: true,
          ).catchError((_) => false)
        : await NativeBridge.setDesktopLyricsEnabled(
            false,
          ).catchError((_) => false);
    desktopLyricsEnabled = value ? applied : false;
    await NativeBridge.setString(
      'desktopLyricsEnabled',
      desktopLyricsEnabled.toString(),
    );
    if (value && !applied) {
      _showNotice('请先授予悬浮窗权限');
    }
    if (desktopLyricsEnabled) {
      _syncDesktopLyrics(force: true);
    }
    notifyListeners();
  }

  Future<void> updateDesktopLyricsSettings({
    double? opacity,
    double? fontSize,
    int? fontWeight,
    bool? locked,
    bool? multiLine,
    bool? centerLineLocked,
    bool? autoHideInForeground,
    bool? autoHideWhenPaused,
    bool? followDynamicColor,
    Color? backgroundColor,
    Color? textColor,
  }) async {
    desktopLyricsOpacity = (opacity ?? desktopLyricsOpacity)
        .clamp(0.0, 0.85)
        .toDouble();
    desktopLyricsFontSize = (fontSize ?? desktopLyricsFontSize)
        .clamp(14.0, 32.0)
        .toDouble();
    desktopLyricsFontWeight = (fontWeight ?? desktopLyricsFontWeight).clamp(
      300,
      900,
    );
    desktopLyricsLocked = locked ?? desktopLyricsLocked;
    desktopLyricsMultiLine = multiLine ?? desktopLyricsMultiLine;
    desktopLyricsCenterLineLocked =
        centerLineLocked ?? desktopLyricsCenterLineLocked;
    desktopLyricsAutoHideInForeground =
        autoHideInForeground ?? desktopLyricsAutoHideInForeground;
    desktopLyricsAutoHideWhenPaused =
        autoHideWhenPaused ?? desktopLyricsAutoHideWhenPaused;
    desktopLyricsFollowDynamicColor =
        followDynamicColor ?? desktopLyricsFollowDynamicColor;
    desktopLyricsBackgroundColor =
        backgroundColor ?? desktopLyricsBackgroundColor;
    desktopLyricsTextColor = textColor ?? desktopLyricsTextColor;
    await Future.wait([
      NativeBridge.setString(
        'desktopLyricsOpacity',
        desktopLyricsOpacity.toStringAsFixed(3),
      ),
      NativeBridge.setString(
        'desktopLyricsFontSize',
        desktopLyricsFontSize.toStringAsFixed(1),
      ),
      NativeBridge.setString(
        'desktopLyricsFontWeight',
        desktopLyricsFontWeight.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsLocked',
        desktopLyricsLocked.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsMultiLine',
        desktopLyricsMultiLine.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsCenterLineLocked',
        desktopLyricsCenterLineLocked.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsAutoHideInForeground',
        desktopLyricsAutoHideInForeground.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsAutoHideWhenPaused',
        desktopLyricsAutoHideWhenPaused.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsFollowDynamicColor',
        desktopLyricsFollowDynamicColor.toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsBackgroundColor',
        desktopLyricsBackgroundColor.toARGB32().toString(),
      ),
      NativeBridge.setString(
        'desktopLyricsTextColor',
        desktopLyricsTextColor.toARGB32().toString(),
      ),
    ]);
    await _applyDesktopLyricsStyle();
    _syncDesktopLyrics(force: true);
    notifyListeners();
  }

  Future<void> _restoreDesktopLyricsOverlay() async {
    await _ensureDesktopLyricsOverlayActive(forceSync: true);
  }

  Future<bool> _ensureDesktopLyricsOverlayActive({
    bool forceSync = false,
  }) async {
    if (!desktopLyricsEnabled) return false;
    try {
      final active = await NativeBridge.isDesktopLyricsActive().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
      if (!active) {
        await _applyDesktopLyricsStyle(force: true, ignoreHold: true);
        final applied = await NativeBridge.setDesktopLyricsEnabled(
          true,
          requestPermission: false,
        ).catchError((_) => false);
        desktopLyricsEnabled = applied;
        await NativeBridge.setString(
          'desktopLyricsEnabled',
          desktopLyricsEnabled.toString(),
        );
        if (!applied) {
          _lastDesktopLyricsPayloadKey = '';
          return false;
        }
      } else if (forceSync) {
        await _applyDesktopLyricsStyle(force: true, ignoreHold: true);
      }
      if (forceSync) {
        _syncDesktopLyrics(force: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _probeStartupLoginState() async {
    if (loginGateVisible || loggedIn) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (loginGateVisible || loggedIn || _restoreLoginOnLoad) return;
    try {
      await _runJavaScript(_sessionProbeScript);
      await _extractLoginProjection();
    } catch (_) {}
    if (accountActive) {
      await enterApp();
      return;
    }
    loginGateVisible = true;
    smsLoginVisible = false;
    smsLoginBusy = false;
    loginLoading = false;
    loginMessage = '验证码登录';
    notifyListeners();
    unawaited(openSmsLogin());
  }

  Future<void> _applyDesktopLyricsStyle({
    bool force = false,
    bool ignoreHold = false,
  }) {
    final useDynamicColor =
        desktopLyricsFollowDynamicColor && dynamicColorEnabled;
    if (useDynamicColor && !ignoreHold && _desktopLyricsStyleHoldActive) {
      return Future<void>.value();
    }
    final backgroundColor = useDynamicColor
        ? themeSeedColor
        : desktopLyricsBackgroundColor;
    final textColor = useDynamicColor
        ? _desktopLyricsDynamicTextColor(themeSeedColor)
        : desktopLyricsTextColor;
    final styleKey = [
      desktopLyricsOpacity.toStringAsFixed(3),
      desktopLyricsFontSize.toStringAsFixed(1),
      desktopLyricsFontWeight,
      desktopLyricsLocked,
      desktopLyricsMultiLine,
      desktopLyricsCenterLineLocked,
      desktopLyricsAutoHideInForeground,
      desktopLyricsAutoHideWhenPaused,
      desktopLyricsFollowDynamicColor,
      backgroundColor.toARGB32(),
      textColor.toARGB32(),
    ].join('|');
    if (!force && styleKey == _lastDesktopLyricsStyleKey) {
      return Future<void>.value();
    }
    _lastDesktopLyricsStyleKey = styleKey;
    return NativeBridge.setDesktopLyricsStyle(
      opacity: desktopLyricsOpacity,
      fontSize: desktopLyricsFontSize,
      fontWeight: desktopLyricsFontWeight,
      locked: desktopLyricsLocked,
      multiLine: desktopLyricsMultiLine,
      centerLineLocked: desktopLyricsCenterLineLocked,
      autoHideInForeground: desktopLyricsAutoHideInForeground,
      autoHideWhenPaused: desktopLyricsAutoHideWhenPaused,
      followDynamicColor: desktopLyricsFollowDynamicColor,
      backgroundColor: backgroundColor.toARGB32(),
      textColor: textColor.toARGB32(),
    );
  }

  Color _desktopLyricsDynamicTextColor(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.62, 0.92).toDouble())
        .withLightness(0.82)
        .toColor();
  }

  void _syncDesktopLyrics({bool force = false}) {
    if (!desktopLyricsEnabled) return;
    final snapshot = displayPlayer;
    if (snapshot.hasSong &&
        !_songDetailMatchesPlayer(snapshot) &&
        !songDetailLoading) {
      _requestDesktopLyricsDetail(snapshot);
    }
    final text = _desktopLyricsText(snapshot).trim();
    final title = snapshot.hasSong ? snapshot.title : 'EmoC';
    final artist = snapshot.hasSong ? snapshot.displayArtist : '';
    final key = [
      text,
      title,
      artist,
      desktopLyricsOpacity.toStringAsFixed(3),
      desktopLyricsFontSize.toStringAsFixed(1),
      desktopLyricsLocked,
      desktopLyricsMultiLine,
      snapshot.playing,
    ].join('|');
    if (!force && key == _lastDesktopLyricsPayloadKey) return;
    _lastDesktopLyricsPayloadKey = key;
    unawaited(
      NativeBridge.updateDesktopLyrics(
        text: text.isEmpty ? '用音乐安放此刻' : text,
        title: title,
        artist: artist,
        playing: snapshot.playing,
      ).catchError((_) {}),
    );
  }

  bool _songDetailMatchesPlayer(PlayerSnapshot snapshot) {
    final detail = songDetail;
    if (detail == null || !snapshot.hasSong) return false;
    if (snapshot.songId.isNotEmpty && detail.song.id == snapshot.songId) {
      return true;
    }
    return _normalizeForMatch(detail.song.title) ==
        _normalizeForMatch(snapshot.title);
  }

  String _desktopLyricsText(PlayerSnapshot snapshot) {
    if (snapshot.hasSong && _songDetailMatchesPlayer(snapshot)) {
      final timed = songDetail?.lyrics ?? const <LyricLine>[];
      if (timed.isNotEmpty) {
        final index = _currentDesktopLyricIndex(
          timed,
          snapshot.currentTimeSeconds,
        );
        final range = desktopLyricsMultiLine
            ? <int>[index, index + 1, index + 2]
            : <int>[index];
        final lines = range
            .where((lineIndex) => lineIndex >= 0 && lineIndex < timed.length)
            .map((lineIndex) => timed[lineIndex].text.trim())
            .where((line) => line.isNotEmpty)
            .toList(growable: false);
        if (lines.isNotEmpty) return lines.join('\n');
      }
      final textLines = songDetail?.lyricLines ?? const <String>[];
      if (textLines.isNotEmpty) {
        return desktopLyricsMultiLine
            ? textLines.take(3).join('\n')
            : textLines.first;
      }
    }
    if (queueLyricLines.isNotEmpty) {
      return desktopLyricsMultiLine
          ? queueLyricLines.take(3).join('\n')
          : queueLyricLines.first;
    }
    return snapshot.hasSong ? snapshot.title : '';
  }

  int _currentDesktopLyricIndex(List<LyricLine> lines, double currentSeconds) {
    var index = 0;
    final time = currentSeconds + 0.35;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= time) {
        index = i;
      } else {
        break;
      }
    }
    return index.clamp(0, lines.length - 1).toInt();
  }

  void _requestDesktopLyricsDetail(PlayerSnapshot snapshot) {
    final key = snapshot.songId.isNotEmpty ? snapshot.songId : snapshot.title;
    if (key.isEmpty || key == _lastDesktopLyricsDetailRequestKey) return;
    _lastDesktopLyricsDetailRequestKey = key;
    unawaited(_loadDesktopLyricsDetail(snapshot.asMirrorItem()));
  }

  Future<void> _loadDesktopLyricsDetail(MirrorItem song) async {
    try {
      final direct = await _requestSongDetailDirect(song);
      final current = displayPlayer;
      final stillCurrent = song.id.isNotEmpty && current.songId.isNotEmpty
          ? song.id == current.songId
          : _normalizeForMatch(song.title) == _normalizeForMatch(current.title);
      if (direct != null && stillCurrent) {
        songDetail = direct;
        songDetailLoading = false;
        queueLyricLines = direct.lyricLines;
        _lastDesktopLyricsPayloadKey = '';
        notifyListeners();
        _syncDesktopLyrics(force: true);
        return;
      }
      await openSongDetail(song);
    } catch (_) {}
  }

  Future<SongDetail?> _requestSongDetailDirect(MirrorItem song) async {
    final songId = song.id.trim();
    if (songId.isEmpty) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 5);
    try {
      final cookie = await NativeBridge.getCookies(
        'https://music.163.com/',
      ).timeout(const Duration(seconds: 2), onTimeout: () => '');
      final uris = [
        Uri.https('music.163.com', '/api/song/lyric', {
          'id': songId,
          'lv': '-1',
          'kv': '-1',
          'tv': '-1',
        }),
        Uri.https('music.163.com', '/api/song/lyric/v1', {
          'id': songId,
          'lv': '-1',
          'kv': '-1',
          'tv': '-1',
        }),
      ];
      for (final uri in uris) {
        try {
          final decoded = _mapOf(await _getMusicJson(client, uri, cookie));
          final lyric = _stringOf(_mapOf(decoded['lrc'])['lyric']);
          final translated = _stringOf(_mapOf(decoded['tlyric'])['lyric']);
          if (lyric.isEmpty && translated.isEmpty) continue;
          return SongDetail.fromJson({
            'songId': songId,
            'title': song.title,
            'artist': song.subtitle,
            'coverUrl': coverFor(song),
            'lyric': lyric,
            'translatedLyric': translated,
          }, song);
        } catch (_) {}
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  String _normalizeForMatch(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> clearCache() async {
    _playlistSongCache.clear();
    _playlistRevealCounts.clear();
    _playlistRevealPersistTimer?.cancel();
    songCoverCache = <String, String>{};
    CoverRuntimeCache.instance.clear();
    _lastSavedPlayerCacheKey = '';
    _lastSavedPlaylistCacheKey = '';
    _dynamicColorCache.clear();
    _clearDynamicColorRequestState();
    _clearNativeDynamicColorAuthority();
    await _clearContentCache();
    status = '缓存已清除';
    _showNotice('缓存已清除');
    notifyListeners();
  }

  Future<void> openExternalLink(String url) async {
    final opened = await NativeBridge.openExternalUrl(url);
    if (!opened) {
      _showNotice('无法打开外部链接');
    }
  }

  Future<void> createPlaylist(String title) async {
    final name = title.trim();
    if (name.isEmpty) return;
    libraryLoading = true;
    status = '正在新建歌单：$name';
    notifyListeners();
    try {
      final created = await _musicMutationApiClient.createPlaylist(name);
      if (created.id.isNotEmpty) {
        final createdPlaylist = MirrorItem(
          domId: 'api_playlist_${created.id}',
          kind: 'playlist',
          title: created.name,
          subtitle: '0 首',
          imageUrl: '',
          href: 'https://music.163.com/#/my/m/music/playlist?id=${created.id}',
        );
        final current = _currentLibraryBase()
            .where((item) => item.id != created.id)
            .toList(growable: false);
        _setLibraryPlaylists(<MirrorItem>[
          ...current.where((item) => item.kind == 'liked'),
          createdPlaylist,
          ...current.where((item) => item.kind != 'liked'),
        ]);
        await _saveLibraryPlaylistCache();
      }
      libraryLoading = false;
      status = '已新建歌单：$name';
      _showNotice('新建成功');
      notifyListeners();
      if (created.id.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await loadLibrary();
      }
    } catch (error) {
      libraryLoading = false;
      status = '新建歌单失败：$error';
      _showNotice('新建失败：$error');
      notifyListeners();
    }
  }

  Future<void> pinPlaylist(MirrorItem playlist) async {
    if (playlist.id.isEmpty) return;
    pinnedPlaylistIds = <String>[
      playlist.id,
      for (final id in pinnedPlaylistIds)
        if (id != playlist.id) id,
    ];
    libraryPlaylists = _sortLibraryPlaylists(_currentLibraryBase());
    notifyListeners();
    try {
      await NativeBridge.setString(
        'pinnedPlaylistIds',
        jsonEncode(pinnedPlaylistIds),
      );
      await _saveLibraryPlaylistCache();
    } catch (_) {}
  }

  Future<void> unpinPlaylist(MirrorItem playlist) async {
    if (playlist.id.isEmpty) return;
    pinnedPlaylistIds = pinnedPlaylistIds
        .where((id) => id != playlist.id)
        .toList(growable: false);
    libraryPlaylists = _sortLibraryPlaylists(_currentLibraryBase());
    notifyListeners();
    try {
      await NativeBridge.setString(
        'pinnedPlaylistIds',
        jsonEncode(pinnedPlaylistIds),
      );
      await _saveLibraryPlaylistCache();
    } catch (_) {}
  }

  Future<void> deletePlaylist(MirrorItem playlist) async {
    if (playlist.id.isEmpty) return;
    if (playlist.kind == 'liked') {
      _showNotice('我喜欢的音乐不能删除');
      return;
    }
    final original = libraryPlaylists;
    final originalBase = _libraryPlaylistsBase;
    final originalPinned = pinnedPlaylistIds;
    final originalSelected = selectedLibraryPlaylist;
    _libraryPlaylistsBase = _currentLibraryBase()
        .where((item) => item.id != playlist.id)
        .toList(growable: false);
    libraryPlaylists = _sortLibraryPlaylists(_libraryPlaylistsBase);
    pinnedPlaylistIds = originalPinned
        .where((id) => id != playlist.id)
        .toList(growable: false);
    if (selectedLibraryPlaylist?.id == playlist.id) {
      selectedLibraryPlaylist = null;
    }
    status = '正在删除歌单：${playlist.title}';
    notifyListeners();
    try {
      await _musicMutationApiClient.deletePlaylist(playlist.id);
      status = '已删除歌单：${playlist.title}';
      _forgetPlaylistRevealCount(playlist.id);
      await _invalidatePlaylistSongsCache(playlist.id);
      await NativeBridge.setString(
        'pinnedPlaylistIds',
        jsonEncode(pinnedPlaylistIds),
      );
      await _saveLibraryPlaylistCache();
      _showNotice('删除成功');
      notifyListeners();
    } catch (error) {
      libraryPlaylists = original;
      _libraryPlaylistsBase = originalBase;
      pinnedPlaylistIds = originalPinned;
      selectedLibraryPlaylist = originalSelected;
      status = '删除歌单失败：$error';
      _showNotice('删除歌单失败：$error');
      notifyListeners();
    }
  }

  Future<bool> removeSongFromPlaylist(
    MirrorItem playlist,
    MirrorItem song,
  ) async {
    if (playlist.id.isEmpty || song.id.isEmpty) {
      _showNotice('歌曲或歌单ID缺失');
      return false;
    }
    final original = playlistSongs;
    final nextSongs = original
        .where((item) => !_sameSong(item, song))
        .toList(growable: false);
    playlistSongs = nextSongs;
    _playlistSongCache[playlist.id] = nextSongs;
    notifyListeners();
    try {
      if (playlist.kind == 'liked') {
        await _musicMutationApiClient.setSongLiked(song.id, false);
      } else {
        await _musicMutationApiClient.removeSongFromPlaylist(
          playlist.id,
          song.id,
        );
      }
      status = '已删除：${song.title}';
      unawaited(_saveRecentPlaylistSongsCache(playlist.id, nextSongs));
      notifyListeners();
      return true;
    } catch (error) {
      playlistSongs = original;
      _playlistSongCache[playlist.id] = original;
      status = '删除失败：$error';
      _showNotice('删除失败：$error');
      notifyListeners();
      return false;
    }
  }

  void _handleSmsLogin(Map<String, dynamic> data) {
    smsLoginBusy = false;
    final phase = _stringOf(data['phase']);
    final message = _stringOf(data['message']).isEmpty
        ? (phase == 'send' ? '验证码请求已提交' : '登录请求已提交')
        : _stringOf(data['message']);
    smsLoginMessage = message;
    loginMessage = message;
    final code = _intOf(data['code']);
    final success = data['success'] == true || code == 200;
    if (phase == 'login' && success) {
      loggedIn = true;
      final projectedAccountName = _stringOf(data['accountName']);
      if (_hasRealAccountName(projectedAccountName)) {
        accountName = projectedAccountName;
      }
      final projectedAvatarUrl = _absoluteMusicUrl(
        _stringOf(data['avatarUrl']),
      );
      if (projectedAvatarUrl.isNotEmpty) {
        avatarUrl = projectedAvatarUrl;
      }
      _clearSwitchAccountBackup();
      smsLoginMessage = '登录成功，正在进入应用';
      loginMessage = '登录成功，正在进入应用';
      unawaited(_rememberCurrentAccount(id: _stringOf(data['accountId'])));
      unawaited(_persistLoginState());
      _loginTimer?.cancel();
      unawaited(_runJavaScript(_sessionProbeScript));
      _scheduleEnterApp(const Duration(milliseconds: 900));
    }
    notifyListeners();
  }

  void _handleSuggestions(Map<String, dynamic> data) {
    searchSuggestions = _dedupeItems(
      _listOf(data['items'])
          .map((item) => MirrorItem.fromJson(_mapOf(item)))
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
    );
    searchLoading = false;
    notifyListeners();
  }

  void _handleSnapshot(Map<String, dynamic> data) {
    final context = _stringOf(data['context']);
    final requestId = _intOf(data['requestId']);
    if (requestId > 0 && _activeSnapshotRequests[context] != requestId) {
      _finishSnapshotRequest(requestId);
      return;
    }
    if (data['stale'] == true) {
      final message = _stringOf(data['message']);
      if (context == 'daily') {
        dailyLoading = false;
      } else if (context == 'library') {
        libraryLoading = false;
      } else if (context == 'playlist') {
        playlistLoading = !_playlistAllowEmptySnapshot && playlistSongs.isEmpty;
      } else if (context == 'search') {
        searchLoading = false;
      }
      if (message.isNotEmpty) status = message;
      _finishSnapshotRequest(requestId);
      notifyListeners();
      return;
    }
    if (context == 'playlist') {
      final targetId = _stringOf(data['targetId']);
      final selectedId = selectedLibraryPlaylist?.id ?? '';
      if (selectedId.isNotEmpty &&
          targetId.isNotEmpty &&
          targetId != selectedId) {
        _finishSnapshotRequest(requestId);
        return;
      }
    }
    final nextItems = _dedupeItems(
      _listOf(data['items'])
          .map((item) => MirrorItem.fromJson(_mapOf(item)))
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
    );
    pageUrl = _stringOf(data['url']).isEmpty ? pageUrl : _stringOf(data['url']);
    if (context == 'daily') {
      final freshDailySongs = nextItems
          .where((item) => item.kind == 'song')
          .toList(growable: false);
      if (freshDailySongs.isNotEmpty || dailySongs.isEmpty) {
        dailySongs = freshDailySongs;
      }
      _rememberCovers(freshDailySongs);
      unawaited(_saveItemsCache('cacheDailySongs', freshDailySongs));
      dailyLoading = false;
      status = dailySongs.isEmpty
          ? '每日推荐暂未加载到歌曲'
          : freshDailySongs.isEmpty
          ? '暂未刷新到新推荐，继续显示缓存 ${dailySongs.length} 首歌'
          : '已加载每日推荐 ${dailySongs.length} 首歌';
    } else if (context == 'library') {
      final freshPlaylists = nextItems
          .where((item) => item.kind == 'liked' || item.kind == 'playlist')
          .toList(growable: false);
      if (freshPlaylists.isNotEmpty || libraryPlaylists.isEmpty) {
        _setLibraryPlaylists(
          freshPlaylists,
          updateBase: freshPlaylists.isNotEmpty,
        );
      }
      unawaited(_saveLibraryPlaylistCache());
      libraryLoading = false;
      status = libraryPlaylists.isEmpty
          ? '歌单暂未加载到内容'
          : freshPlaylists.isEmpty
          ? '暂未刷新到新歌单，继续显示缓存 ${libraryPlaylists.length} 个'
          : '已加载歌单 ${libraryPlaylists.length} 个';
    } else if (context == 'playlist') {
      final selectedId = selectedLibraryPlaylist?.id ?? '';
      final freshPlaylistSongs = nextItems
          .where((item) => item.kind == 'song')
          .toList(growable: false);
      if (freshPlaylistSongs.isNotEmpty) {
        // A late WebView snapshot can contain only the first visible page.
        // Never let that shorter projection replace a complete API result.
        if (playlistSongs.isEmpty ||
            freshPlaylistSongs.length >= playlistSongs.length) {
          playlistSongs = freshPlaylistSongs;
        }
        if (selectedId.isNotEmpty) {
          final cached = _playlistSongCache[selectedId] ?? const <MirrorItem>[];
          if (cached.isEmpty || playlistSongs.length >= cached.length) {
            _playlistSongCache[selectedId] = playlistSongs;
          }
        }
      } else if (playlistSongs.isEmpty && selectedId.isNotEmpty) {
        playlistSongs = _playlistSongCache[selectedId] ?? const [];
      }
      _rememberCovers(playlistSongs);
      final keepWaitingForPlaylist =
          freshPlaylistSongs.isEmpty &&
          playlistSongs.isEmpty &&
          selectedId.isNotEmpty &&
          !_playlistAllowEmptySnapshot;
      playlistLoading = keepWaitingForPlaylist;
      final message = _stringOf(data['message']);
      status = keepWaitingForPlaylist
          ? '正在加载歌单'
          : playlistSongs.isEmpty
          ? (message.isEmpty ? '无歌曲' : message)
          : '已加载歌单 ${playlistSongs.length} 首歌';
    } else if (context == 'search') {
      searchResults = nextItems
          .where((item) => item.kind == 'song')
          .toList(growable: false);
      searchLoading = false;
      status = searchResults.isEmpty
          ? '搜索暂无歌曲结果'
          : '已加载搜索结果 ${searchResults.length} 首歌';
    }
    _finishSnapshotRequest(requestId);
    notifyListeners();
  }

  void _handlePlayer(Map<String, dynamic> data) {
    if (_nativePlaybackPending || _nativePlaybackActive) return;
    final next = PlayerSnapshot.fromJson(data);
    if (!next.hasSong && player.hasSong) {
      return;
    }
    final previous = player;
    final nextSongId = next.songId.isEmpty ? previous.songId : next.songId;
    final songChanged =
        next.songId.isNotEmpty && next.songId != previous.songId;
    final coverFromList = songCoverCache[nextSongId] ?? '';
    var nextCurrentSeconds = next.currentSeconds;
    var nextCurrentMilliseconds = next.currentMilliseconds;
    final seekTarget = _seekHoldSeconds;
    if (_seekHoldActive &&
        seekTarget != null &&
        nextSongId == previous.songId &&
        nextCurrentSeconds < seekTarget - 1) {
      nextCurrentSeconds = seekTarget;
      nextCurrentMilliseconds = seekTarget * 1000;
    } else if (seekTarget != null &&
        nextSongId == previous.songId &&
        nextCurrentSeconds >= seekTarget - 1) {
      _seekHoldUntil = null;
      _seekHoldSeconds = null;
    }
    if (nextSongId == previous.songId &&
        previous.currentSeconds > 0 &&
        nextCurrentSeconds == 0 &&
        (previous.playing || next.playing)) {
      nextCurrentSeconds = previous.currentSeconds;
      nextCurrentMilliseconds = previous.currentMilliseconds;
    }
    final nextDurationSeconds = next.durationSeconds == 0
        ? previous.durationSeconds
        : next.durationSeconds;
    final nextDurationMilliseconds = next.durationMilliseconds == 0
        ? previous.durationMilliseconds
        : next.durationMilliseconds;
    final nextMode = _validPlaybackMode(next.mode) ? next.mode : previous.mode;
    player = PlayerSnapshot(
      visible: next.visible || previous.visible,
      songId: nextSongId,
      title: songChanged
          ? next.title
          : (next.title.isEmpty ? previous.title : next.title),
      artist: songChanged
          ? next.artist
          : (next.artist.isEmpty ? previous.artist : next.artist),
      source: songChanged
          ? next.source
          : (next.source.isEmpty ? previous.source : next.source),
      coverUrl: next.coverUrl.isEmpty
          ? (songChanged
                ? coverFromList
                : (coverFromList.isEmpty ? previous.coverUrl : coverFromList))
          : next.coverUrl,
      playing: next.playing,
      currentSeconds: nextCurrentSeconds,
      durationSeconds: nextDurationSeconds,
      currentMilliseconds: nextCurrentMilliseconds,
      durationMilliseconds: nextDurationMilliseconds,
      volume: desiredVolume,
      mode: nextMode,
    );
    if (player.songId.isNotEmpty && currentPlaylist.isNotEmpty) {
      final index = _indexOfSongInList(
        player.asMirrorItem(),
        currentPlaylist,
        sourceIndex: currentSongIndex,
      );
      if (index >= 0) currentSongIndex = index;
    }
    if (player.songId.isNotEmpty && player.coverUrl.startsWith('http')) {
      songCoverCache = {...songCoverCache, player.songId: player.coverUrl};
    }
    notifyListeners();
  }

  Future<void> _handleSongUrl(Map<String, dynamic> data) async {
    final requestId = _intOf(data['requestId']);
    if (requestId > 0 && requestId != _playRequestId) return;
    final songId = _stringOf(data['songId']);
    if (!_pendingRequestMatches(songId)) return;
    final url = _stringOf(data['url']);
    final message = _stringOf(data['message']);
    final vipMaybe = data['vipMaybe'] == true;
    _nativePlaybackPending = false;
    if (data['vipBlocked'] == true) {
      final reason = message.isEmpty ? 'VIP歌曲，需会员播放' : message;
      status = reason;
      _handleBlockedPendingSong(reason, autoSkip: _pendingAutoAdvance);
      return;
    }
    if (url.isEmpty) {
      final reason = message.isEmpty ? '官网没有返回可播放地址' : message;
      status = reason;
      _handleBlockedPendingSong(reason, autoSkip: _pendingAutoAdvance);
      return;
    }
    try {
      if (desiredVolume <= 0.02) {
        desiredVolume = 0.7;
        await NativeBridge.setString(
          'desiredVolume',
          desiredVolume.toStringAsFixed(3),
        );
      }
      final pendingSong = _pendingSong;
      final pendingDynamicColorSource = _pendingDynamicColorSource;
      var resolvedCoverUrl = '';
      var resolvedSongId = songId;
      if (pendingSong != null) {
        resolvedSongId = pendingSong.id.isNotEmpty ? pendingSong.id : songId;
        resolvedCoverUrl = _knownCoverForDynamicColor(
          pendingSong,
          fallback: _absoluteMusicUrl(_stringOf(data['coverUrl'])),
        );
        if (resolvedCoverUrl.startsWith('http') && resolvedSongId.isNotEmpty) {
          songCoverCache = {
            ...songCoverCache,
            resolvedSongId: resolvedCoverUrl,
          };
        }
      }
      _commitPendingSong(
        resolvedCoverUrl: resolvedCoverUrl,
        resolvedSongId: resolvedSongId,
      );
      _nativePlaybackActive = true;
      if (resolvedCoverUrl.startsWith('http')) {
        unawaited(CoverRuntimeCache.instance.prefetch([resolvedCoverUrl]));
      }
      await NativeBridge.playUrl(url, player);
      if (requestId > 0 && requestId != _playRequestId) return;
      _localPauseRequested = false;
      await NativeBridge.setPlayerVolume(desiredVolume);
      if (requestId > 0 && requestId != _playRequestId) return;
      player = _playerWith(playing: true);
      _autoAdvanceInProgress = false;
      _autoAdvanceWatchdog?.cancel();
      status = '正在播放：${player.title}';
      _clearPendingPlaybackRequest();
      notifyListeners();
      if (desktopLyricsEnabled) {
        unawaited(_ensureDesktopLyricsOverlayActive(forceSync: true));
      }
      _scheduleInterfaceColorReviewFromDesktopLyrics(
        requestId > 0 ? requestId : _playRequestId,
      );
      if (pendingSong != null) {
        if (!resolvedCoverUrl.startsWith('http')) {
          unawaited(
            _resolveCurrentPlaybackCover(
              requestId: requestId > 0 ? requestId : _playRequestId,
              song: pendingSong,
              songId: resolvedSongId,
              source: pendingDynamicColorSource,
            ),
          );
        }
        _schedulePlaylistDynamicThemeRecovery(
          requestId: requestId > 0 ? requestId : _playRequestId,
          song: pendingSong,
          songId: resolvedSongId,
          source: pendingDynamicColorSource,
        );
      }
      await refreshPlayerState();
    } catch (error) {
      if (requestId > 0 && requestId != _playRequestId) return;
      status = '播放器启动失败：$error';
      if (vipMaybe &&
          _nativePlaybackFailureLooksAccessDenied(error.toString())) {
        status = 'VIP歌曲，需会员播放';
      }
      _handleBlockedPendingSong(status, autoSkip: _pendingAutoAdvance);
    }
  }

  Future<void> _resolveCurrentPlaybackCover({
    required int requestId,
    required MirrorItem song,
    required String songId,
    required String source,
  }) async {
    final cover = await ensureSongCover(song, force: true);
    if (!cover.startsWith('http') || requestId != _playRequestId) return;
    final currentMatches = songId.isNotEmpty
        ? player.songId == songId
        : _normalizeForMatch(player.title) == _normalizeForMatch(song.title);
    if (!currentMatches) return;
    if (songId.isNotEmpty) {
      songCoverCache = {...songCoverCache, songId: cover};
    }
    await CoverRuntimeCache.instance.prefetch([cover]);
    if (requestId != _playRequestId) return;
    final coverChanged = player.coverUrl != cover;
    if (coverChanged) {
      player = _playerWith(coverUrl: cover);
      try {
        await NativeBridge.updatePlayerMetadata(player);
      } catch (_) {}
    }
    if (source == 'playlist') {
      await _playlistModule.refreshPlaybackColor(
        requestId: requestId,
        song: song,
        songId: songId,
        force: true,
      );
    } else {
      _requestDynamicThemeFromCoverForSource(
        source,
        cover,
        songId: songId,
        force: true,
      );
    }
    _scheduleSongCoverNotify();
  }

  bool _nativePlaybackFailureLooksAccessDenied(String value) {
    final text = value.toLowerCase();
    return text.contains('403') ||
        text.contains('401') ||
        text.contains('bad_http_status') ||
        text.contains('forbidden') ||
        text.contains('unauthorized') ||
        text.contains('access') ||
        text.contains('denied');
  }

  void _handleSongDetail(Map<String, dynamic> data) {
    final incomingId = _stringOf(data['songId']);
    final requestIsSongId = RegExp(r'^\d+$').hasMatch(_songDetailRequestKey);
    if (requestIsSongId &&
        incomingId.isNotEmpty &&
        incomingId != _songDetailRequestKey) {
      return;
    }
    final fallback = songDetail?.song ?? player.asMirrorItem();
    final detail = SongDetail.fromJson(data, fallback);
    songDetail = detail;
    songDetailLoading = false;
    status = detail.lyricLines.isEmpty ? '歌曲暂无歌词' : '已加载完整歌词';
    final detailCover = [
      detail.coverUrl,
      detail.song.imageUrl,
    ].firstWhere((url) => url.startsWith('http'), orElse: () => '');
    if (detailCover.startsWith('http') && _songDetailMatchesPlayer(player)) {
      final detailSongId = detail.song.id.isNotEmpty
          ? detail.song.id
          : player.songId;
      if (detailSongId.isNotEmpty) {
        songCoverCache = {...songCoverCache, detailSongId: detailCover};
      }
      final coverChanged = player.coverUrl != detailCover;
      if (coverChanged) {
        player = _playerWith(coverUrl: detailCover);
      }
      _requestDynamicThemeFromCoverForSource(
        _activePlaybackDynamicSource,
        detailCover,
        songId: detailSongId,
        force: coverChanged,
      );
    }
    if (_songDetailMatchesPlayer(player) && detail.lyricLines.isNotEmpty) {
      queueLyricLines = detail.lyricLines;
    }
    notifyListeners();
  }

  void _showNotice(String message) {
    if (message.trim().isEmpty) return;
    if (DateTime.now().isBefore(_startupNoticeSuppressUntil)) return;
    final token = ++_noticeToken;
    _noticeHideTimer?.cancel();
    noticeMessage = message.trim();
    notifyListeners();
    _noticeHideTimer = Timer(const Duration(seconds: 3), () {
      if (_noticeToken != token) return;
      noticeMessage = '';
      notifyListeners();
    });
  }

  void _handleQueue(Map<String, dynamic> data) {
    final officialQueue = _dedupeItems(
      _listOf(data['items'])
          .map((item) => MirrorItem.fromJson(_mapOf(item)))
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
    );
    final localQueue = currentPlaylist;
    final localCurrentIndex = _indexOfSongInList(
      player.asMirrorItem(),
      localQueue,
      sourceIndex: currentSongIndex,
    );
    final officialCurrentIndex = _indexOfSongInList(
      player.asMirrorItem(),
      officialQueue,
    );
    final keepLocalQueue =
        localQueue.isNotEmpty &&
        (officialQueue.isEmpty ||
            (localCurrentIndex >= 0 &&
                localQueue.length >= officialQueue.length));
    playerQueue = keepLocalQueue ? localQueue : officialQueue;
    if (keepLocalQueue && localCurrentIndex >= 0) {
      currentSongIndex = localCurrentIndex;
    }
    if (!keepLocalQueue && currentPlaylist.isEmpty && playerQueue.isNotEmpty) {
      currentPlaylist = playerQueue;
      currentSongIndex = _indexOfSongInList(
        player.asMirrorItem(),
        currentPlaylist,
        sourceIndex: officialCurrentIndex,
      );
    }
    queueLyricLines = _lyricLines(_stringOf(data['lyric']));
    queueLoading = false;
    _scheduleCurrentPlaylistCacheSave();
    notifyListeners();
  }

  void _startPlayerPolling() {
    _playerTimer ??= Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(refreshPlayerState()),
    );
    unawaited(refreshPlayerState());
  }

  Future<void> moveTaskToBack() async {
    try {
      await NativeBridge.moveTaskToBack();
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (player.hasSong) {
      _lastPlayerWithSong = player;
      final cacheKey = _playerCacheKey(player);
      if (cacheKey != _lastSavedPlayerCacheKey) {
        _lastSavedPlayerCacheKey = cacheKey;
        unawaited(_savePlayerCache(player));
      }
      if (!_nativePlaybackActive && !_nativePlaybackPending) {
        _requestDynamicThemeFromCoverForSource(
          _activePlaybackDynamicSource,
          player.coverUrl,
          songId: player.songId,
        );
      }
    }
    if (desktopLyricsEnabled) {
      unawaited(_applyDesktopLyricsStyle());
    }
    _syncDesktopLyrics();
    super.notifyListeners();
  }
}
