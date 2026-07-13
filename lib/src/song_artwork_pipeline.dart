part of '../main.dart';

String _songArtworkIdentity(MirrorItem song) {
  if (song.id.isNotEmpty) return song.id;
  if (song.href.isNotEmpty) return song.href;
  return '${song.title}|${song.subtitle}';
}

class SongArtworkPipeline {
  SongArtworkPipeline(this.model);

  final AppModel model;
  final Map<String, Future<bool>> _pending = <String, Future<bool>>{};
  final List<_SongArtworkJob> _queue = <_SongArtworkJob>[];
  int _activeJobs = 0;

  static const int _maxActiveJobs = 6;

  bool isReady(MirrorItem song) {
    if (!model.showSongCovers) return true;
    final cover = model.coverFor(song);
    return cover.startsWith('http') &&
        CoverRuntimeCache.instance.contains(_coverImageCandidates(cover));
  }

  Future<bool> prepare(MirrorItem song, {bool forceMetadata = false}) {
    if (!model.showSongCovers) return Future<bool>.value(true);
    final key =
        '${_songArtworkIdentity(song)}|${forceMetadata ? 'force' : 'normal'}';
    final existing = _pending[key];
    if (existing != null) return existing;
    final completer = Completer<bool>();
    final job = _SongArtworkJob(
      key: key,
      song: song,
      forceMetadata: forceMetadata,
      completer: completer,
    );
    _pending[key] = completer.future;
    if (forceMetadata) {
      _queue.insert(0, job);
    } else {
      _queue.add(job);
    }
    _drainQueue();
    return completer.future;
  }

  void _drainQueue() {
    while (_activeJobs < _maxActiveJobs && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _activeJobs += 1;
      unawaited(
        _prepare(job.song, forceMetadata: job.forceMetadata)
            .then(job.completer.complete)
            .catchError((_) {
              if (!job.completer.isCompleted) job.completer.complete(false);
            })
            .whenComplete(() {
              _activeJobs = (_activeJobs - 1).clamp(0, _maxActiveJobs);
              if (identical(_pending[job.key], job.completer.future)) {
                _pending.remove(job.key);
              }
              _drainQueue();
            }),
      );
    }
  }

  Future<bool> _prepare(MirrorItem song, {required bool forceMetadata}) async {
    var cover = model.coverFor(song);
    if (!cover.startsWith('http') || forceMetadata) {
      final resolved = await model.ensureSongCover(song, force: forceMetadata);
      if (resolved.startsWith('http')) cover = resolved;
    }
    if (!cover.startsWith('http')) {
      cover = await model.ensureSongCover(song, force: true);
    }
    if (!cover.startsWith('http')) return false;

    var loaded = await CoverRuntimeCache.instance.load(
      _coverImageCandidates(cover),
    );
    if (loaded == null && !forceMetadata) {
      final refreshed = await model.ensureSongCover(song, force: true);
      if (refreshed.startsWith('http')) {
        cover = refreshed;
        loaded = await CoverRuntimeCache.instance.load(
          _coverImageCandidates(cover),
        );
      }
    }
    return loaded != null;
  }

  Future<bool> prepareBatch(
    List<MirrorItem> songs, {
    bool forceMissingMetadata = false,
  }) async {
    if (!model.showSongCovers || songs.isEmpty) return true;
    var allReady = true;
    for (var start = 0; start < songs.length; start += 6) {
      final results = await Future.wait(
        songs.skip(start).take(6).map((song) {
          return prepare(
            song,
            forceMetadata:
                forceMissingMetadata &&
                !model.coverFor(song).startsWith('http'),
          );
        }),
      );
      if (results.any((ready) => !ready)) allReady = false;
    }
    return allReady;
  }
}

class _SongArtworkJob {
  const _SongArtworkJob({
    required this.key,
    required this.song,
    required this.forceMetadata,
    required this.completer,
  });

  final String key;
  final MirrorItem song;
  final bool forceMetadata;
  final Completer<bool> completer;
}

class SongViewportController extends ChangeNotifier {
  SongViewportController({
    required this.batchSize,
    required this.eager,
    int? automaticBatchCount,
  }) : automaticBatchCount = automaticBatchCount ?? (eager ? 4 : 1);

  final int batchSize;
  final bool eager;
  final int automaticBatchCount;
  List<MirrorItem> _songs = const [];
  List<MirrorItem>? _sourceSongs;
  List<MirrorItem>? _scheduledSongs;
  bool _sourceShowsCovers = true;
  bool _scheduledShowsCovers = true;
  int _generation = 0;
  int _automaticBatchesRemaining = 0;
  int readyCount = 0;
  bool preparing = false;

  List<MirrorItem> get visibleSongs =>
      _songs.take(readyCount).toList(growable: false);
  bool get hasMore => readyCount < _songs.length;

  bool matches(AppModel model, List<MirrorItem> songs) =>
      identical(_sourceSongs, songs) &&
      _sourceShowsCovers == model.showSongCovers;

  void reset() {
    _sourceSongs = null;
    _scheduledSongs = null;
    _generation += 1;
    _automaticBatchesRemaining = 0;
    _songs = const [];
    readyCount = 0;
    preparing = false;
    notifyListeners();
  }

  void synchronize(
    AppModel model,
    List<MirrorItem> songs, {
    int initialReadyCount = 0,
  }) {
    final showsCovers = model.showSongCovers;
    if ((identical(_sourceSongs, songs) && _sourceShowsCovers == showsCovers) ||
        (identical(_scheduledSongs, songs) &&
            _scheduledShowsCovers == showsCovers)) {
      return;
    }
    _scheduledSongs = songs;
    _scheduledShowsCovers = showsCovers;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!identical(_scheduledSongs, songs) ||
          _scheduledShowsCovers != showsCovers) {
        return;
      }
      _scheduledSongs = null;
      _sourceSongs = songs;
      _sourceShowsCovers = showsCovers;
      _songs = songs.toList(growable: false);
      _generation += 1;
      final restoredReadyCount = initialReadyCount
          .clamp(0, _songs.length)
          .toInt();
      // Keep several viewport lengths ahead so a normal fling reaches rows
      // whose artwork is already warm, without constructing those rows yet.
      _automaticBatchesRemaining = restoredReadyCount > 0
          ? 0
          : automaticBatchCount;
      readyCount = showsCovers ? restoredReadyCount : _songs.length;
      preparing = false;
      notifyListeners();
      if (showsCovers && _songs.isNotEmpty && readyCount == 0) {
        unawaited(prepareNext(model));
      } else if (showsCovers && readyCount > 0) {
        // Restored rows become available immediately. Warm only the first
        // viewport here; later rows resolve as the user approaches them.
        unawaited(
          model.prepareSongArtworkBatch(
            _songs.take(batchSize).toList(growable: false),
          ),
        );
      }
    });
  }

  Future<void> prepareNext(AppModel model) async {
    if (preparing || readyCount >= _songs.length) return;
    if (!model.showSongCovers) {
      readyCount = _songs.length;
      notifyListeners();
      return;
    }
    final generation = _generation;
    if (_automaticBatchesRemaining > 0) {
      _automaticBatchesRemaining -= 1;
    }
    final start = readyCount;
    final end = (start + batchSize).clamp(0, _songs.length);
    preparing = true;
    notifyListeners();
    for (var groupStart = start; groupStart < end; groupStart += 6) {
      final groupEnd = (groupStart + 6).clamp(0, end);
      final preparation = model.prepareSongArtworkBatch(
        _songs.sublist(groupStart, groupEnd),
      );
      // Give cached/healthy artwork a brief head start, but never let one slow
      // CDN candidate keep the whole playlist on a skeleton screen. Each row
      // continues resolving its own cover after it becomes interactive.
      await Future.any<void>([
        preparation.then<void>((_) {}),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ]);
      if (generation != _generation) return;
      readyCount = groupEnd;
      notifyListeners();
    }
    preparing = false;
    notifyListeners();
    if (_automaticBatchesRemaining > 0 && readyCount < _songs.length) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          () => prepareNext(model),
        ),
      );
    }
  }
}
