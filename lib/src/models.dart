part of '../main.dart';

class MirrorItem {
  const MirrorItem({
    required this.domId,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.href,
  });

  final String domId;
  final String kind;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String href;

  String get id => _idFromMusicUrl(href);

  factory MirrorItem.fromJson(Map<String, dynamic> json) {
    return MirrorItem(
      domId: _stringOf(json['domId']),
      kind: _stringOf(json['kind']).isEmpty ? 'link' : _stringOf(json['kind']),
      title: _stringOf(json['title']),
      subtitle: _stringOf(json['subtitle']),
      imageUrl: _absoluteMusicUrl(_stringOf(json['imageUrl'])),
      href: _absoluteMusicUrl(_stringOf(json['href'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'domId': domId,
      'kind': kind,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'href': href,
    };
  }
}

class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.cookie,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final String cookie;
  final int lastUsedAt;

  String get key => id.isNotEmpty ? id : name;

  bool get hasUsableName => name.isNotEmpty && name != '未登录' && name != '已登录账号';

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      id: _stringOf(json['id']),
      name: _stringOf(json['name']),
      avatarUrl: _absoluteMusicUrl(_stringOf(json['avatarUrl'])),
      cookie: _stringOf(json['cookie']),
      lastUsedAt: _intOf(json['lastUsedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'cookie': cookie,
      'lastUsedAt': lastUsedAt,
    };
  }
}

class PlayerSnapshot {
  const PlayerSnapshot({
    required this.visible,
    required this.songId,
    required this.title,
    required this.artist,
    required this.source,
    required this.coverUrl,
    required this.playing,
    required this.currentSeconds,
    required this.durationSeconds,
    required this.currentMilliseconds,
    required this.durationMilliseconds,
    required this.volume,
    required this.mode,
  });

  final bool visible;
  final String songId;
  final String title;
  final String artist;
  final String source;
  final String coverUrl;
  final bool playing;
  final int currentSeconds;
  final int durationSeconds;
  final int currentMilliseconds;
  final int durationMilliseconds;
  final double volume;
  final String mode;

  bool get hasSong => title.isNotEmpty || songId.isNotEmpty;

  String get displayArtist => artist.isEmpty ? '网易云音乐' : artist;

  String get progressText {
    final current = _formatSeconds(currentTimeSeconds.floor());
    final duration = durationSeconds > 0
        ? _formatSeconds(durationSeconds)
        : '--:--';
    return '$current / $duration';
  }

  double get progress {
    final duration = durationMilliseconds > 0
        ? durationMilliseconds
        : durationSeconds * 1000;
    if (duration <= 0) return 0;
    final current = currentMilliseconds > 0
        ? currentMilliseconds
        : currentSeconds * 1000;
    return (current / duration).clamp(0, 1).toDouble();
  }

  double get currentTimeSeconds {
    if (currentMilliseconds > 0) return currentMilliseconds / 1000;
    return currentSeconds.toDouble();
  }

  MirrorItem asMirrorItem() {
    final href = songId.isEmpty
        ? ''
        : 'https://music.163.com/#/song?id=$songId';
    return MirrorItem(
      domId: 'player_$songId',
      kind: 'song',
      title: title,
      subtitle: [artist, source].where((item) => item.isNotEmpty).join(' · '),
      imageUrl: coverUrl,
      href: href,
    );
  }

  factory PlayerSnapshot.fromJson(Map<String, dynamic> json) {
    final currentSeconds = _intOf(json['currentSeconds']);
    final durationSeconds = _intOf(json['durationSeconds']);
    final currentMilliseconds = _intOf(json['currentMilliseconds']);
    final durationMilliseconds = _intOf(json['durationMilliseconds']);
    return PlayerSnapshot(
      visible: json['visible'] == true,
      songId: _stringOf(json['songId']),
      title: _stringOf(json['title']),
      artist: _stringOf(json['artist']),
      source: _stringOf(json['source']),
      coverUrl: _absoluteMusicUrl(_stringOf(json['coverUrl'])),
      playing: json['playing'] == true,
      currentSeconds: currentSeconds,
      durationSeconds: durationSeconds,
      currentMilliseconds: currentMilliseconds > 0
          ? currentMilliseconds
          : currentSeconds * 1000,
      durationMilliseconds: durationMilliseconds > 0
          ? durationMilliseconds
          : durationSeconds * 1000,
      volume: _doubleOf(json['volume']).clamp(0, 1).toDouble(),
      mode: _stringOf(json['mode']).isEmpty ? 'loop' : _stringOf(json['mode']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'visible': visible,
      'songId': songId,
      'title': title,
      'artist': artist,
      'source': source,
      'coverUrl': coverUrl,
      'playing': playing,
      'currentSeconds': currentSeconds,
      'durationSeconds': durationSeconds,
      'currentMilliseconds': currentMilliseconds,
      'durationMilliseconds': durationMilliseconds,
      'volume': volume,
      'mode': mode,
    };
  }

  static const empty = PlayerSnapshot(
    visible: false,
    songId: '',
    title: '',
    artist: '',
    source: '',
    coverUrl: '',
    playing: false,
    currentSeconds: 0,
    durationSeconds: 0,
    currentMilliseconds: 0,
    durationMilliseconds: 0,
    volume: 0.7,
    mode: 'loop',
  );
}

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final double time;
  final String text;
}

class SongDetail {
  const SongDetail({
    required this.song,
    required this.coverUrl,
    required this.lyricLines,
    required this.lyrics,
    required this.loading,
  });

  final MirrorItem song;
  final String coverUrl;
  final List<String> lyricLines;
  final List<LyricLine> lyrics;
  final bool loading;

  factory SongDetail.loading(MirrorItem song) {
    return SongDetail(
      song: song,
      coverUrl: song.imageUrl,
      lyricLines: const [],
      lyrics: const [],
      loading: true,
    );
  }

  factory SongDetail.fromJson(Map<String, dynamic> json, MirrorItem fallback) {
    final title = _stringOf(json['title']);
    final artist = _stringOf(json['artist']);
    final album = _stringOf(json['album']);
    final id = _stringOf(json['songId']).isEmpty
        ? fallback.id
        : _stringOf(json['songId']);
    final cover = _absoluteMusicUrl(_stringOf(json['coverUrl']));
    final rawLyric = _stringOf(json['lyric']);
    final translatedLyric = _stringOf(json['translatedLyric']);
    final lines = _mergedLyricLines(rawLyric, translatedLyric);
    final lyrics = _mergedLyricTimedLines(rawLyric, translatedLyric);
    return SongDetail(
      song: MirrorItem(
        domId: fallback.domId,
        kind: 'song',
        title: title.isEmpty ? fallback.title : title,
        subtitle: [artist, album].where((item) => item.isNotEmpty).join(' · '),
        imageUrl: cover.isEmpty ? fallback.imageUrl : cover,
        href: id.isEmpty
            ? fallback.href
            : 'https://music.163.com/#/song?id=$id',
      ),
      coverUrl: cover.isEmpty ? fallback.imageUrl : cover,
      lyricLines: lines,
      lyrics: lyrics,
      loading: false,
    );
  }
}
