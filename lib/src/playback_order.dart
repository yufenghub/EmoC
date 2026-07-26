part of '../main.dart';

class PlaybackOrderController {
  PlaybackOrderController({Random? random}) : _random = random ?? Random();

  final Random _random;
  String _signature = '';
  List<int> _shuffleOrder = const [];
  int _shuffleCursor = -1;
  final List<String> _recentShuffleSongs = <String>[];

  int nextIndex({
    required List<MirrorItem> songs,
    required int currentIndex,
    required String mode,
    bool naturalEnd = false,
  }) {
    if (!_validIndex(songs, currentIndex)) return -1;
    if (mode == 'one' && naturalEnd) return currentIndex;
    if (mode == 'shuffle') return _nextShuffle(songs, currentIndex);
    return (currentIndex + 1) % songs.length;
  }

  int previousIndex({
    required List<MirrorItem> songs,
    required int currentIndex,
    required String mode,
  }) {
    if (!_validIndex(songs, currentIndex)) return -1;
    if (mode == 'shuffle') return _previousShuffle(songs, currentIndex);
    return currentIndex > 0 ? currentIndex - 1 : songs.length - 1;
  }

  int indexAfterBlocked({
    required List<MirrorItem> songs,
    required int blockedIndex,
    required String mode,
    required int direction,
  }) {
    if (!_validIndex(songs, blockedIndex)) return -1;
    if (mode == 'shuffle') {
      return direction < 0
          ? _previousShuffle(songs, blockedIndex)
          : _nextShuffle(songs, blockedIndex);
    }
    if (direction < 0) {
      return blockedIndex > 0 ? blockedIndex - 1 : songs.length - 1;
    }
    return (blockedIndex + 1) % songs.length;
  }

  void reset() {
    _signature = '';
    _shuffleOrder = const [];
    _shuffleCursor = -1;
    _recentShuffleSongs.clear();
  }

  int _nextShuffle(List<MirrorItem> songs, int currentIndex) {
    _synchronizeShuffle(songs, currentIndex);
    if (songs.length == 1) return currentIndex;
    if (_shuffleCursor + 1 < _shuffleOrder.length) {
      _shuffleCursor += 1;
      return _recordShuffleTarget(songs, _shuffleOrder[_shuffleCursor]);
    }
    _buildShuffleOrder(songs, currentIndex);
    _shuffleCursor = 1;
    return _recordShuffleTarget(songs, _shuffleOrder[_shuffleCursor]);
  }

  int _previousShuffle(List<MirrorItem> songs, int currentIndex) {
    _synchronizeShuffle(songs, currentIndex);
    if (songs.length == 1) return currentIndex;
    if (_shuffleCursor > 0) {
      _shuffleCursor -= 1;
      return _recordShuffleTarget(songs, _shuffleOrder[_shuffleCursor]);
    }
    _shuffleCursor = _shuffleOrder.length - 1;
    return _recordShuffleTarget(songs, _shuffleOrder[_shuffleCursor]);
  }

  void _synchronizeShuffle(List<MirrorItem> songs, int currentIndex) {
    final signature = _songsSignature(songs);
    if (_signature != signature || _shuffleOrder.length != songs.length) {
      _signature = signature;
      _recentShuffleSongs.clear();
      _buildShuffleOrder(songs, currentIndex);
      return;
    }
    final currentCursor = _shuffleOrder.indexOf(currentIndex);
    if (currentCursor >= 0) {
      _shuffleCursor = currentCursor;
    } else {
      _buildShuffleOrder(songs, currentIndex);
    }
  }

  void _buildShuffleOrder(List<MirrorItem> songs, int currentIndex) {
    final remaining = <int>[
      for (var index = 0; index < songs.length; index++)
        if (index != currentIndex) index,
    ]..shuffle(_random);
    if (remaining.length > 1 && _recentShuffleSongs.isNotEmpty) {
      final recent = _recentShuffleSongs.reversed.take(2).toSet();
      final preferred = remaining.indexWhere(
        (index) => !recent.contains(_songArtworkIdentity(songs[index])),
      );
      if (preferred > 0) {
        final candidate = remaining.removeAt(preferred);
        remaining.insert(0, candidate);
      }
    }
    _shuffleOrder = <int>[currentIndex, ...remaining];
    _shuffleCursor = 0;
  }

  int _recordShuffleTarget(List<MirrorItem> songs, int index) {
    final identity = _songArtworkIdentity(songs[index]);
    if (_recentShuffleSongs.isEmpty || _recentShuffleSongs.last != identity) {
      _recentShuffleSongs.add(identity);
      if (_recentShuffleSongs.length > 3) {
        _recentShuffleSongs.removeAt(0);
      }
    }
    return index;
  }

  bool _validIndex(List<MirrorItem> songs, int index) {
    return songs.isNotEmpty && index >= 0 && index < songs.length;
  }

  String _songsSignature(List<MirrorItem> songs) {
    return [
      songs.length,
      for (final song in songs) _songArtworkIdentity(song),
    ].join('|');
  }
}
