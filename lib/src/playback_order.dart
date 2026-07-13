part of '../main.dart';

class PlaybackOrderController {
  PlaybackOrderController({Random? random}) : _random = random ?? Random();

  final Random _random;
  String _signature = '';
  List<int> _shuffleOrder = const [];
  int _shuffleCursor = -1;

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

  void reset() {
    _signature = '';
    _shuffleOrder = const [];
    _shuffleCursor = -1;
  }

  int _nextShuffle(List<MirrorItem> songs, int currentIndex) {
    _synchronizeShuffle(songs, currentIndex);
    if (songs.length == 1) return currentIndex;
    if (_shuffleCursor + 1 < _shuffleOrder.length) {
      _shuffleCursor += 1;
      return _shuffleOrder[_shuffleCursor];
    }
    _buildShuffleOrder(songs, currentIndex);
    _shuffleCursor = 1;
    return _shuffleOrder[_shuffleCursor];
  }

  int _previousShuffle(List<MirrorItem> songs, int currentIndex) {
    _synchronizeShuffle(songs, currentIndex);
    if (songs.length == 1) return currentIndex;
    if (_shuffleCursor > 0) {
      _shuffleCursor -= 1;
      return _shuffleOrder[_shuffleCursor];
    }
    _shuffleCursor = _shuffleOrder.length - 1;
    return _shuffleOrder[_shuffleCursor];
  }

  void _synchronizeShuffle(List<MirrorItem> songs, int currentIndex) {
    final signature = _songsSignature(songs);
    if (_signature != signature || _shuffleOrder.length != songs.length) {
      _signature = signature;
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
    _shuffleOrder = <int>[currentIndex, ...remaining];
    _shuffleCursor = 0;
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
