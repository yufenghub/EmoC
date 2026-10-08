part of '../main.dart';

class ListeningEntry {
  const ListeningEntry({required this.song, required this.playedAt});

  final MirrorItem song;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'playedAt': playedAt.millisecondsSinceEpoch,
  };
}

class ListeningHistory extends ChangeNotifier {
  ListeningHistory({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : _read = read ?? NativeBridge.getString,
       _write = write ?? NativeBridge.setString;

  static const storageKey = 'listeningHistory.v1';
  static const maxRecent = 500;
  static const maxSearches = 30;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  bool recordPlayback = true;
  bool recordSearches = true;
  List<ListeningEntry> _recent = [];
  List<String> _searches = [];
  String? persistenceError;

  List<ListeningEntry> get recent => List.unmodifiable(_recent);
  List<String> get searches => List.unmodifiable(_searches);

  static String songKey(MirrorItem song) => song.id.isNotEmpty
      ? song.id
      : song.href.isNotEmpty
      ? song.href
      : song.domId;

  Future<void> restore() async {
    try {
      final raw = await _read(storageKey).timeout(const Duration(seconds: 2));
      if (_disposed || raw == null || raw.isEmpty) return;
      final data = _mapOf(jsonDecode(raw));
      recordPlayback = data['recordPlayback'] != false;
      recordSearches = data['recordSearches'] != false;
      final seen = <String>{};
      _recent = _listOf(data['recent'])
          .map((value) {
            final item = _mapOf(value);
            return ListeningEntry(
              song: MirrorItem.fromJson(_mapOf(item['song'])),
              playedAt: DateTime.fromMillisecondsSinceEpoch(
                _intOf(item['playedAt']),
              ),
            );
          })
          .where(
            (entry) =>
                entry.song.title.isNotEmpty && seen.add(songKey(entry.song)),
          )
          .take(maxRecent)
          .toList();
      final unique = <String>{};
      _searches = _listOf(data['searches'])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && unique.add(value.toLowerCase()))
          .take(maxSearches)
          .toList();
      notifyListeners();
    } catch (_) {
      // Corrupt or unavailable history must not block application startup.
    }
  }

  Future<void> recordSong(MirrorItem song, {DateTime? at}) {
    if (_disposed || !recordPlayback || song.title.isEmpty) {
      return Future.value();
    }
    final key = songKey(song);
    _recent = [
      ListeningEntry(song: song, playedAt: at ?? DateTime.now()),
      ..._recent.where((entry) => songKey(entry.song) != key),
    ].take(maxRecent).toList();
    return _save();
  }

  Future<void> recordSearch(String value) {
    final query = value.trim();
    if (_disposed || !recordSearches || query.isEmpty) return Future.value();
    _searches = [
      query,
      ..._searches.where((item) => item.toLowerCase() != query.toLowerCase()),
    ].take(maxSearches).toList();
    return _save();
  }

  Future<void> removeSong(MirrorItem song) {
    _recent.removeWhere((entry) => songKey(entry.song) == songKey(song));
    return _save();
  }

  Future<void> removeSearch(String query) {
    _searches.remove(query);
    return _save();
  }

  Future<void> clearRecent() {
    _recent.clear();
    return _save();
  }

  Future<void> clearSearches() {
    _searches.clear();
    return _save();
  }

  Future<void> setRecording({bool? playback, bool? searches}) {
    recordPlayback = playback ?? recordPlayback;
    recordSearches = searches ?? recordSearches;
    return _save();
  }

  Future<void> _save() {
    if (_disposed) return Future.value();
    final payload = jsonEncode({
      'recordPlayback': recordPlayback,
      'recordSearches': recordSearches,
      'recent': _recent.map((entry) => entry.toJson()).toList(),
      'searches': _searches,
    });
    notifyListeners();
    // Serialize snapshots so clearing history cannot be undone by an older write.
    _writes = _writes.then((_) async {
      try {
        await _write(storageKey, payload);
        persistenceError = null;
      } catch (_) {
        persistenceError = '历史记录未能保存';
      }
      if (!_disposed) notifyListeners();
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
