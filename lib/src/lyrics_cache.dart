part of '../main.dart';

class LyricsCache {
  static const storageKey = 'cacheLyrics.v1';
  static const maxBytes = 1 << 20;
  static const maxEntries = 200;
  final _entries = <String, Map<String, dynamic>>{};
  Future<void> _writes = Future.value();
  int _generation = 0;
  int get generation => _generation;
  int get byteSize => utf8.encode(jsonEncode(_entries)).length;
  int get count => _entries.length;

  Future<void> restore() async {
    try {
      final raw = await NativeBridge.getString(
        storageKey,
      ).timeout(const Duration(seconds: 2));
      if (raw == null || raw.length > maxBytes * 2) return;
      final saved = _mapOf(jsonDecode(raw));
      for (final entry in saved.entries) {
        final data = _mapOf(entry.value);
        if (_stringOf(data['lyric']).isNotEmpty) _entries[entry.key] = data;
      }
      _trim();
    } catch (_) {}
  }

  Map<String, dynamic>? lookup(String songId) {
    final cached = _entries.remove(songId);
    if (cached != null) _entries[songId] = cached;
    return cached;
  }

  Future<void> put(String songId, Map<String, dynamic> value, int generation) {
    if (generation != _generation || songId.isEmpty) return Future.value();
    final lyric = _stringOf(value['lyric']);
    if (lyric.isEmpty || lyric.length > 100000) return Future.value();
    _entries.remove(songId);
    _entries[songId] = {
      'songId': songId,
      'lyric': lyric,
      'translatedLyric': _stringOf(value['translatedLyric']),
    };
    _trim();
    return _persist();
  }

  void _trim() {
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries || byteSize > maxBytes)) {
      _entries.remove(_entries.keys.first);
    }
  }

  Future<void> clear() {
    _generation += 1;
    _entries.clear();
    return _persist();
  }

  Future<void> _persist() {
    final value = jsonEncode(_entries);
    _writes = _writes.then((_) async {
      try {
        await NativeBridge.setString(storageKey, value);
      } catch (_) {}
    });
    return _writes;
  }
}
