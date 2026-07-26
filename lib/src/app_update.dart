part of '../main.dart';

enum AppUpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  downloaded,
  error,
}

@immutable
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.apkUrl,
    required this.apkName,
    required this.apkSize,
    required this.htmlUrl,
    required this.digest,
  });

  factory AppReleaseInfo.fromMap(Map<String, dynamic> map) {
    final tag = _stringOf(map['tagName']);
    return AppReleaseInfo(
      tag: tag,
      version: _normalizeAppVersion(
        _stringOf(map['version']).isNotEmpty ? _stringOf(map['version']) : tag,
      ),
      name: _stringOf(map['name']),
      notes: _stringOf(map['body']),
      apkUrl: _stringOf(map['apkUrl']),
      apkName: _stringOf(map['apkName']),
      apkSize: _intOf(map['apkSize']),
      htmlUrl: _stringOf(map['htmlUrl']),
      digest: _stringOf(map['digest']),
    );
  }

  final String tag;
  final String version;
  final String name;
  final String notes;
  final String apkUrl;
  final String apkName;
  final int apkSize;
  final String htmlUrl;
  final String digest;

  bool get hasInstaller => apkUrl.startsWith('https://');
}

class AppUpdateManager extends ChangeNotifier {
  static const _lastPromptedReleaseKey = 'lastPromptedUpdateRelease';

  AppUpdatePhase phase = AppUpdatePhase.idle;
  String currentVersionName = '1.0.7';
  int currentVersionCode = 0;
  AppReleaseInfo? latestRelease;
  String downloadedTag = '';
  String downloadedVersion = '';
  String downloadedPath = '';
  String errorMessage = '';
  double downloadProgress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  String _startupPromptTag = '';
  bool _initialized = false;
  bool _checking = false;
  bool _downloading = false;

  bool get hasUpdate {
    final release = latestRelease;
    return release != null &&
        release.hasInstaller &&
        _compareAppVersions(release.version, currentVersionName) > 0;
  }

  bool get hasDownloadedInstaller =>
      downloadedPath.isNotEmpty &&
      downloadedVersion.isNotEmpty &&
      _compareAppVersions(downloadedVersion, currentVersionName) > 0;

  bool get hasLatestInstaller {
    final release = latestRelease;
    if (!hasDownloadedInstaller) return false;
    return release == null ||
        _compareAppVersions(downloadedVersion, release.version) == 0;
  }

  bool get startupPromptPending => _startupPromptTag.isNotEmpty && hasUpdate;

  bool get isBusy => _checking || _downloading;

  String get versionActionLabel {
    if (_downloading) return '${(downloadProgress * 100).round()}%';
    if (hasLatestInstaller) return '安装';
    if (hasUpdate) return '更新';
    if (hasDownloadedInstaller) return '安装';
    if (_checking) return '检查中';
    return '检查更新';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadInstalledVersion();
    await _loadDownloadedInstaller();
    await checkForUpdates(promptWhenNew: true);
  }

  Future<void> _loadInstalledVersion() async {
    try {
      final info = await NativeBridge.getAppVersion();
      final version = _stringOf(info['versionName']);
      if (version.isNotEmpty) currentVersionName = version;
      currentVersionCode = _intOf(info['versionCode']);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _loadDownloadedInstaller() async {
    try {
      final info = await NativeBridge.getDownloadedUpdate();
      if (info['valid'] == true) {
        downloadedTag = _stringOf(info['tagName']);
        downloadedVersion = _stringOf(info['versionName']);
        downloadedPath = _stringOf(info['path']);
        phase = AppUpdatePhase.downloaded;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> checkForUpdates({bool promptWhenNew = false}) async {
    if (_checking) return hasUpdate;
    _checking = true;
    errorMessage = '';
    if (!hasDownloadedInstaller) phase = AppUpdatePhase.checking;
    notifyListeners();
    try {
      final raw = await NativeBridge.checkLatestRelease();
      final release = AppReleaseInfo.fromMap(raw);
      if (release.tag.isEmpty || !release.hasInstaller) {
        throw const FormatException('最新 Release 没有可用的 APK');
      }
      latestRelease = release;
      if (_compareAppVersions(release.version, currentVersionName) > 0) {
        phase =
            hasDownloadedInstaller &&
                _normalizeAppVersion(downloadedVersion) == release.version
            ? AppUpdatePhase.downloaded
            : AppUpdatePhase.available;
        if (promptWhenNew) {
          final lastPrompted =
              await NativeBridge.getString(_lastPromptedReleaseKey) ?? '';
          if (lastPrompted != release.tag) {
            _startupPromptTag = release.tag;
          }
        }
      } else {
        phase = hasDownloadedInstaller
            ? AppUpdatePhase.downloaded
            : AppUpdatePhase.upToDate;
      }
      return hasUpdate;
    } catch (error) {
      errorMessage = _friendlyUpdateError(error);
      if (!hasDownloadedInstaller) phase = AppUpdatePhase.error;
      return false;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<AppReleaseInfo?> consumeStartupPrompt() async {
    if (!startupPromptPending) return null;
    final release = latestRelease;
    _startupPromptTag = '';
    if (release != null) {
      await NativeBridge.setString(_lastPromptedReleaseKey, release.tag);
    }
    notifyListeners();
    return release;
  }

  Future<bool> downloadLatest() async {
    final release = latestRelease;
    if (release == null || !hasUpdate || _downloading) return false;
    if (hasDownloadedInstaller && downloadedVersion == release.version) {
      phase = AppUpdatePhase.downloaded;
      notifyListeners();
      return true;
    }
    _downloading = true;
    phase = AppUpdatePhase.downloading;
    errorMessage = '';
    downloadProgress = 0;
    downloadedBytes = 0;
    totalBytes = release.apkSize;
    notifyListeners();
    try {
      final response = await NativeBridge.downloadUpdate({
        'tagName': release.tag,
        'version': release.version,
        'apkUrl': release.apkUrl,
        'apkName': release.apkName,
        'apkSize': release.apkSize,
        'digest': release.digest,
      });
      if (response['valid'] != true) {
        throw StateError('安装包校验失败');
      }
      downloadedTag = _stringOf(response['tagName']);
      downloadedVersion = _stringOf(response['versionName']);
      downloadedPath = _stringOf(response['path']);
      downloadProgress = 1;
      phase = AppUpdatePhase.downloaded;
      return true;
    } catch (error) {
      errorMessage = _friendlyUpdateError(error);
      phase = AppUpdatePhase.available;
      return false;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  Future<String> installDownloaded() async {
    if (!hasDownloadedInstaller) return '没有可安装的更新';
    try {
      final response = await NativeBridge.installDownloadedUpdate();
      final state = _stringOf(response['state']);
      return switch (state) {
        'permissionRequested' => '请允许 EmoC 安装未知来源应用，返回后将继续安装',
        'launched' => '请在系统安装界面确认更新',
        _ =>
          _stringOf(response['message']).isNotEmpty
              ? _stringOf(response['message'])
              : '无法启动安装',
      };
    } catch (error) {
      return _friendlyUpdateError(error);
    }
  }

  bool handleNativeEvent(String action, Map<String, dynamic> arguments) {
    if (action == 'updateDownloadProgress') {
      downloadedBytes = _intOf(arguments['receivedBytes']);
      totalBytes = _intOf(arguments['totalBytes']);
      final raw = _doubleOf(arguments['progress']);
      downloadProgress = raw.clamp(0.0, 1.0).toDouble();
      notifyListeners();
      return true;
    }
    if (action == 'updateDownloadReady') {
      downloadedTag = _stringOf(arguments['tagName']);
      downloadedVersion = _stringOf(arguments['versionName']);
      downloadedPath = _stringOf(arguments['path']);
      downloadProgress = 1;
      phase = AppUpdatePhase.downloaded;
      notifyListeners();
      return true;
    }
    if (action == 'updateDownloadFailed') {
      errorMessage = _stringOf(arguments['message']);
      phase = AppUpdatePhase.available;
      notifyListeners();
      return true;
    }
    return false;
  }
}

String _normalizeAppVersion(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.startsWith('v')) normalized = normalized.substring(1);
  final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(normalized);
  return match?.group(0) ?? normalized;
}

int _compareAppVersions(String left, String right) {
  List<int> parts(String value) => _normalizeAppVersion(
    value,
  ).split('.').map((part) => int.tryParse(part) ?? 0).toList(growable: false);
  final a = parts(left);
  final b = parts(right);
  final length = max(a.length, b.length);
  for (var index = 0; index < length; index++) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

String _friendlyUpdateError(Object error) {
  final text = error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
  if (text.contains('SocketException') || text.contains('timed out')) {
    return '连接 GitHub 超时，请稍后重试';
  }
  return text.isEmpty ? '更新检查失败' : text;
}
