part of '../main.dart';

class QueuedPlaybackTrack {
  const QueuedPlaybackTrack(
    this.song,
    this.index,
    this.url,
    this.preparedAt,
    this.gainDb,
    this.peak,
  );
  final MirrorItem song;
  final int index;
  final String url;
  final DateTime preparedAt;
  final double gainDb;
  final double peak;

  bool reusableFor(MirrorItem target) =>
      song.id == target.id &&
      DateTime.now().difference(preparedAt) < const Duration(minutes: 2);
}

extension PlaybackTransitions on AppModel {
  Future<void> setVolumeNormalization(bool enabled) async {
    volumeNormalizationEnabled = enabled;
    notifyListeners();
    await NativeBridge.setVolumeNormalization(enabled);
    await NativeBridge.setString('volumeNormalizationEnabled', '$enabled');
  }

  Future<void> setPlaybackTransition({bool? enabled, int? seconds}) async {
    continuousPlayback = enabled ?? continuousPlayback;
    crossfadeSeconds = (seconds ?? crossfadeSeconds).clamp(0, 8);
    notifyListeners();
    unawaited(_refreshTransitionQueue());
    await NativeBridge.setString('continuousPlayback', '$continuousPlayback');
    await NativeBridge.setString('crossfadeSeconds', '$crossfadeSeconds');
  }

  Future<void> _refreshTransitionQueue() async {
    final revision = ++_queueRevision;
    _queuedTrack = null;
    try {
      await NativeBridge.clearQueuedTrack();
      if (revision == _queueRevision) await _prepareNextTrack();
    } on PlatformException catch (error) {
      debugPrint('Playback queue: ${error.code}');
    }
  }

  Future<void> _prepareNextTrack() async {
    if (_disposed ||
        !continuousPlayback ||
        !_nativePlaybackActive ||
        _pendingSong != null) {
      return;
    }
    final index = _playbackOrder.peekNextIndex(
      songs: currentPlaylist,
      currentIndex: currentSongIndex,
      mode: player.mode,
    );
    if (index < 0) return;
    final song = currentPlaylist[index];
    if (!song.isLocal &&
        (!networkPolicy.canPrefetch || !networkPolicy.canStream)) {
      return;
    }
    final revision = ++_queueRevision;
    final requestId = _playRequestId;
    final currentId = player.songId;
    try {
      final result = song.isLocal
          ? <String, dynamic>{'url': song.href}
          : await _requestSongUrlDirect(song, requestId);
      if (_disposed ||
          requestId != _playRequestId ||
          revision != _queueRevision) {
        return;
      }
      final url = _stringOf(result['url']);
      if (url.isEmpty || result['vipBlocked'] == true) return;
      final queued = QueuedPlaybackTrack(
        song,
        index,
        url,
        DateTime.now(),
        _doubleOf(result['gainDb']),
        _doubleOf(result['peak']),
      );
      _queuedTrack = queued;
      final accepted = await NativeBridge.queueNextTrack(
        expectedSongId: currentId,
        song: song,
        url: url,
        crossfadeMs: crossfadeSeconds * 1000,
        gainDb: queued.gainDb,
        peak: queued.peak,
      );
      if (!accepted && identical(_queuedTrack, queued)) _queuedTrack = null;
    } on PlatformException catch (error) {
      debugPrint('Next track: ${error.code}');
    }
  }

  Future<void> _acceptTrackTransition(Map<String, dynamic> arguments) async {
    final queued = _queuedTrack;
    if (_disposed ||
        queued == null ||
        _nativePlaybackPending ||
        arguments['previousSongId'] != player.songId ||
        arguments['songId'] != queued.song.id) {
      return;
    }
    _playRequestId++;
    _queueRevision++;
    _queuedTrack = null;
    _playbackOrder.nextIndex(
      songs: currentPlaylist,
      currentIndex: currentSongIndex,
      mode: player.mode,
      naturalEnd: true,
    );
    currentSongIndex = queued.index;
    player = _snapshotForSong(queued.song, playing: true);
    _activePlaybackDynamicSongId = queued.song.id;
    _dynamicColorTargetSongId = queued.song.id;
    _autoAdvanceInProgress = false;
    _autoAdvanceWatchdog?.cancel();
    unawaited(listeningHistory.recordSong(queued.song));
    _scheduleCurrentPlaylistCacheSave();
    notifyListeners();
    unawaited(_prepareNextTrack());
  }
}

class PlaybackTransitionSettings extends StatelessWidget {
  const PlaybackTransitionSettings({required this.model, super.key});
  final AppModel model;

  Future<void> _save(BuildContext context, Future<void> write) async {
    try {
      await write;
    } on PlatformException {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('播放设置保存失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppCardSurface(
    model: model,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.queue_music,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '无缝连续播放',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Switch(
                value: model.continuousPlayback,
                onChanged: (value) =>
                    _save(context, model.setPlaybackTransition(enabled: value)),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            child: model.continuousPlayback
                ? Row(
                    children: [
                      const SizedBox(width: 38),
                      const Text('交叉淡化'),
                      Expanded(
                        child: Slider(
                          value: model.crossfadeSeconds.toDouble(),
                          min: 0,
                          max: 8,
                          divisions: 8,
                          label: model.crossfadeSeconds == 0
                              ? '关闭'
                              : '${model.crossfadeSeconds} 秒',
                          onChanged: (value) {
                            model.crossfadeSeconds = value.round();
                            model.notifyListeners();
                          },
                          onChangeEnd: (value) => _save(
                            context,
                            model.setPlaybackTransition(seconds: value.round()),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          model.crossfadeSeconds == 0
                              ? '关闭'
                              : '${model.crossfadeSeconds}s',
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    ),
  );
}
