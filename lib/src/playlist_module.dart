part of '../main.dart';

class PlaylistModule {
  PlaylistModule(this.model);

  final AppModel model;
  int _loadSerial = 0;
  int _colorSerial = 0;
  String _activeColorKey = '';
  Future<void>? _activeColorRequest;

  Future<void> load(MirrorItem playlist) async {
    final serial = ++_loadSerial;
    bool isCurrent() =>
        serial == _loadSerial &&
        model.selectedLibraryPlaylist?.id == playlist.id;

    var cached = model._playlistSongCache[playlist.id] ?? const <MirrorItem>[];
    model.playlistLoading = true;
    model._playlistAllowEmptySnapshot = false;
    model.activePlaylistTitle = playlist.title;
    model.playlistSongs = cached;
    model.status = '正在打开歌单：${playlist.title}';
    _prewarm(cached);
    model.notifyListeners();

    if (cached.isEmpty) {
      cached = await model._restoreRecentPlaylistSongsCache(playlist.id);
      if (!isCurrent()) return;
      if (cached.isNotEmpty) {
        model._playlistSongCache[playlist.id] = cached;
        model.playlistSongs = cached;
        model._rememberCovers(cached);
        _prewarm(cached);
        model.status = '正在刷新歌单 ${cached.length} 首歌';
        model.notifyListeners();
      }
    }

    final expectedCount = _playlistSongCount(playlist);
    var direct = const <MirrorItem>[];
    for (var attempt = 0; attempt < 3 && direct.isEmpty; attempt++) {
      try {
        direct = await model._requestPlaylistSongsDirect(
          playlist.id,
          expectedCount: expectedCount,
        );
      } catch (_) {}
      if (!isCurrent()) return;
      if (direct.isEmpty && attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 420 + attempt * 360));
      }
    }

    if (!isCurrent()) return;
    if (direct.isNotEmpty) {
      final directIsComplete = expectedCount != null
          ? direct.length >= expectedCount
          : direct.length >= cached.length;
      final accepted = directIsComplete || cached.isEmpty ? direct : cached;
      model.playlistSongs = accepted;
      model._playlistSongCache[playlist.id] = accepted;
      unawaited(model._saveRecentPlaylistSongsCache(playlist.id, accepted));
      model._rememberCovers(accepted);
      _prewarm(accepted);
      final complete = expectedCount == null
          ? accepted.isNotEmpty
          : accepted.length >= expectedCount;
      model.playlistLoading = !complete;
      model.status = complete
          ? '已加载歌单 ${accepted.length} 首歌'
          : '正在继续加载歌单 ${accepted.length}/$expectedCount';
      model.notifyListeners();
      if (complete) return;
    }

    try {
      final playlistId = jsonEncode(playlist.id);
      await model._runJavaScript(
        'window.__EMOC_ACTIVE_PLAYLIST_ID__ = $playlistId;',
      );
      await model._openBehindWeb(playlist);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!isCurrent()) return;
      await model._runJavaScript(
        'window.__EMOC_ACTIVE_PLAYLIST_ID__ = $playlistId;',
      );
      await model._extractPage('playlist', targetId: playlist.id);
      if (!isCurrent()) return;
      if (model.playlistSongs.isEmpty) {
        model._playlistAllowEmptySnapshot = true;
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (!isCurrent()) return;
        await model._extractPage('playlist', targetId: playlist.id);
      }
    } catch (_) {
      if (!isCurrent()) return;
    } finally {
      if (isCurrent()) model._playlistAllowEmptySnapshot = false;
    }

    if (!isCurrent()) return;
    if (model.playlistSongs.isEmpty && cached.isNotEmpty) {
      model.playlistSongs = cached;
    }
    model.playlistLoading = false;
    model.status = model.playlistSongs.isEmpty
        ? '歌单暂时加载失败，请下拉重试'
        : '已加载歌单 ${model.playlistSongs.length} 首歌';
    if (model.playlistSongs.isNotEmpty) {
      model._playlistSongCache[playlist.id] = model.playlistSongs;
      unawaited(
        model._saveRecentPlaylistSongsCache(playlist.id, model.playlistSongs),
      );
      model._rememberCovers(model.playlistSongs);
      _prewarm(model.playlistSongs);
    }
    model.notifyListeners();
  }

  void _prewarm(List<MirrorItem> songs) {
    if (!model.showSongCovers || songs.isEmpty) return;
    unawaited(
      model.prepareSongArtworkBatch(
        songs.take(36).toList(growable: false),
        forceMissingMetadata: true,
      ),
    );
  }

  Future<void> refreshPlaybackColor({
    required int requestId,
    required MirrorItem song,
    required String songId,
    bool force = false,
  }) {
    if (!model.dynamicColorEnabled) return Future<void>.value();
    final requestKey = '$requestId|${songId.isNotEmpty ? songId : song.id}';
    final active = _activeColorRequest;
    // Native playback polling can request a forced refresh every 300 ms while
    // the first cover is still downloading. Reuse that request; restarting it
    // repeatedly increments _colorSerial and can starve playlist colour
    // extraction indefinitely.
    if (_activeColorKey == requestKey && active != null) {
      return active;
    }
    final request = _refreshPlaybackColor(
      requestId: requestId,
      song: song,
      songId: songId,
      requestKey: requestKey,
    );
    _activeColorKey = requestKey;
    _activeColorRequest = request;
    return request;
  }

  Future<void> _refreshPlaybackColor({
    required int requestId,
    required MirrorItem song,
    required String songId,
    required String requestKey,
  }) async {
    final serial = ++_colorSerial;
    try {
      var cover = model.coverFor(song);
      if (!cover.startsWith('http')) {
        cover = await model.ensureSongCover(song, force: true);
      }
      if (serial != _colorSerial ||
          requestId != model._playRequestId ||
          !cover.startsWith('http')) {
        return;
      }
      final cached = await CoverRuntimeCache.instance.load(
        _coverImageCandidates(cover),
      );
      if (serial != _colorSerial ||
          requestId != model._playRequestId ||
          cached == null) {
        return;
      }
      final color = await model._dominantColorFromImageBytes(cached.bytes);
      if (serial != _colorSerial ||
          requestId != model._playRequestId ||
          color == null) {
        return;
      }
      model._setDynamicColorSource('playlist');
      await model._applyDynamicThemeColor(
        color,
        coverUrl: cover,
        songId: songId,
        force: true,
        authoritative: true,
      );
      if (serial == _colorSerial && requestId == model._playRequestId) {
        model._playlistDynamicColorSongId = songId;
        model._playlistDynamicColorArgb = color.toARGB32();
        model._playlistDynamicColorCoverUrl = cover;
      }
    } finally {
      if (serial == _colorSerial && _activeColorKey == requestKey) {
        _activeColorKey = '';
        _activeColorRequest = null;
      }
    }
  }
}
