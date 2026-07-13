part of '../main.dart';

class CoverCacheEntry {
  const CoverCacheEntry({required this.url, required this.bytes});

  final String url;
  final Uint8List bytes;
}

class CoverRuntimeCache extends ChangeNotifier {
  CoverRuntimeCache._();

  static final CoverRuntimeCache instance = CoverRuntimeCache._();

  static const int _maxEntries = 500;
  static const int _maxBytes = 32 << 20;
  static const int _maxDownloadBytes = 3 << 20;
  static const int _maxConcurrentDownloads = 6;
  static const int _maxDiskEntries = 500;

  final LinkedHashMap<String, Uint8List> _memory =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _pending =
      <String, Future<Uint8List?>>{};
  final Map<String, DateTime> _failedAt = <String, DateTime>{};
  final List<Completer<void>> _downloadWaiters = <Completer<void>>[];
  int _memoryBytes = 0;
  int _activeDownloads = 0;
  int _diskWriteCount = 0;
  Timer? _notifyTimer;

  Directory get _diskDirectory => Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}emoc_cover_cache_v1',
  );

  CoverCacheEntry? lookup(Iterable<String> candidates) {
    for (final url in candidates) {
      final bytes = _memory.remove(url);
      if (bytes == null) continue;
      _memory[url] = bytes;
      return CoverCacheEntry(url: url, bytes: bytes);
    }
    return null;
  }

  bool contains(Iterable<String> candidates) {
    return candidates.any(_memory.containsKey);
  }

  Future<CoverCacheEntry?> load(Iterable<String> candidates) async {
    final urls = candidates.where((url) => url.startsWith('http')).toList();
    final cached = lookup(urls);
    if (cached != null) return cached;
    final downloadable = <String>[];
    for (final url in urls) {
      final diskBytes = await _loadFromDisk(url);
      if (diskBytes != null) {
        _store(url, diskBytes);
        return CoverCacheEntry(url: url, bytes: diskBytes);
      }
      final failedAt = _failedAt[url];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < const Duration(seconds: 8)) {
        continue;
      }
      downloadable.add(url);
    }
    if (downloadable.isEmpty) return null;
    final primaryUrl = downloadable.first;
    final primaryBytes = await _loadOne(primaryUrl);
    if (primaryBytes != null) {
      return CoverCacheEntry(url: primaryUrl, bytes: primaryBytes);
    }
    for (var start = 1; start < downloadable.length; start += 3) {
      final wave = downloadable.skip(start).take(3).toList(growable: false);
      final results = await Future.wait(wave.map(_loadOne));
      for (var index = 0; index < wave.length; index++) {
        final bytes = results[index];
        if (bytes != null) {
          return CoverCacheEntry(url: wave[index], bytes: bytes);
        }
      }
    }
    return null;
  }

  Future<void> prefetch(Iterable<String> rawUrls) async {
    final seen = <String>{};
    final urls = <String>[];
    for (final rawUrl in rawUrls) {
      final normalized = _absoluteMusicUrl(rawUrl).trim();
      if (!normalized.startsWith('http') || !seen.add(normalized)) continue;
      urls.add(normalized);
    }
    for (var start = 0; start < urls.length; start += 6) {
      await Future.wait(
        urls.skip(start).take(6).map((url) => load(_coverImageCandidates(url))),
      );
    }
  }

  Future<Uint8List?> _loadOne(String url) {
    final existing = _pending[url];
    if (existing != null) return existing;
    final future = _download(url).whenComplete(() => _pending.remove(url));
    _pending[url] = future;
    return future;
  }

  Future<Uint8List?> _download(String url) async {
    await _acquireDownloadSlot();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      request.followRedirects = true;
      request.maxRedirects = 4;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
      );
      request.headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'image/avif,image/webp,image/*,*/*;q=0.8',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _failedAt[url] = DateTime.now();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > _maxDownloadBytes) {
          _failedAt[url] = DateTime.now();
          return null;
        }
      }
      final bytes = builder.takeBytes();
      if (!_looksLikeImage(bytes)) {
        _failedAt[url] = DateTime.now();
        return null;
      }
      _failedAt.remove(url);
      _store(url, bytes);
      unawaited(_storeOnDisk(url, bytes));
      return bytes;
    } catch (_) {
      _failedAt[url] = DateTime.now();
      return null;
    } finally {
      client.close(force: true);
      _releaseDownloadSlot();
    }
  }

  Future<void> _acquireDownloadSlot() async {
    if (_activeDownloads >= _maxConcurrentDownloads) {
      final waiter = Completer<void>();
      _downloadWaiters.add(waiter);
      await waiter.future;
    }
    _activeDownloads += 1;
  }

  void _releaseDownloadSlot() {
    _activeDownloads = (_activeDownloads - 1).clamp(0, _maxConcurrentDownloads);
    if (_downloadWaiters.isEmpty) return;
    final waiter = _downloadWaiters.removeAt(0);
    if (!waiter.isCompleted) waiter.complete();
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final png =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final gif =
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38;
    final webp =
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return jpeg || png || gif || webp;
  }

  String _diskKey(String url) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in url.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  File _diskFile(String url) => File(
    '${_diskDirectory.path}${Platform.pathSeparator}${_diskKey(url)}.img',
  );

  Future<Uint8List?> _loadFromDisk(String url) async {
    try {
      final file = _diskFile(url);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > const Duration(days: 30)) {
        await file.delete();
        return null;
      }
      final bytes = await file.readAsBytes();
      if (!_looksLikeImage(bytes)) {
        await file.delete();
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeOnDisk(String url, Uint8List bytes) async {
    try {
      final directory = _diskDirectory;
      if (!await directory.exists()) await directory.create(recursive: true);
      await _diskFile(url).writeAsBytes(bytes, flush: false);
      _diskWriteCount += 1;
      if (_diskWriteCount % 24 == 0) unawaited(_trimDiskCache());
    } catch (_) {}
  }

  Future<void> _trimDiskCache() async {
    try {
      final directory = _diskDirectory;
      if (!await directory.exists()) return;
      final files = await directory
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      if (files.length <= _maxDiskEntries) return;
      final entries = <({File file, DateTime modified})>[];
      for (final file in files) {
        entries.add((file: file, modified: (await file.stat()).modified));
      }
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in entries.take(files.length - _maxDiskEntries)) {
        await entry.file.delete();
      }
    } catch (_) {}
  }

  void _store(String url, Uint8List bytes) {
    final previous = _memory.remove(url);
    if (previous != null) _memoryBytes -= previous.lengthInBytes;
    _memory[url] = bytes;
    _memoryBytes += bytes.lengthInBytes;
    while (_memory.length > _maxEntries || _memoryBytes > _maxBytes) {
      final oldestKey = _memory.keys.first;
      final removed = _memory.remove(oldestKey);
      if (removed != null) _memoryBytes -= removed.lengthInBytes;
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyTimer?.isActive == true) return;
    _notifyTimer = Timer(const Duration(milliseconds: 40), () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  void evict(String url) {
    final removed = _memory.remove(url);
    if (removed != null) _memoryBytes -= removed.lengthInBytes;
    _failedAt[url] = DateTime.now();
  }

  void clear() {
    _memory.clear();
    _memoryBytes = 0;
    _failedAt.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    unawaited(() async {
      try {
        if (await _diskDirectory.exists()) {
          await _diskDirectory.delete(recursive: true);
        }
      } catch (_) {}
    }());
  }
}
