import 'package:emoc/main.dart';
import 'package:flutter_test/flutter_test.dart';

const local = MirrorItem(domId: 'local_1', kind: 'local', title: 'Local song', subtitle: 'Artist',
  imageUrl: '', href: 'content://com.android.providers.media.documents/document/audio%3A12');

void main() {
  test('local identity round-trips through player and cached JSON', () {
    final snapshot = PlayerSnapshot.fromJson({'songId': local.id, 'title': local.title});
    expect(snapshot.asMirrorItem().href, local.href);
    expect(snapshot.asMirrorItem().isLocal, isTrue);
    expect(MirrorItem.fromJson(local.toJson()).id, local.id);
  });

  test('local import merges duplicates and preserves playlists and lyrics', () async {
    String? saved;
    final library = LocalMusicLibrary(read: (_) async => saved, write: (_, value) async { saved = value; });
    addTearDown(library.dispose);
    await library.mergeImport({'tracks': [local.toJson(), local.toJson()], 'roots': ['content://tree/music']});
    final playlist = await library.createPlaylist('Offline');
    await library.setPlaylistSongs(playlist, [local.id, local.id, 'missing']);
    await library.attachLyrics(local.id, '[00:01.00]Hello');
    expect(library.tracks, hasLength(1));
    expect(library.playlistSongs(playlist), hasLength(1));
    final restored = LocalMusicLibrary(read: (_) async => saved, write: (_, _) async {});
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.tracks.single.href, local.href);
    expect(restored.lyricsFor(local.id), '[00:01.00]Hello');
    expect(restored.playlistSongs(playlist).single.id, local.id);
    await restored.removeTrack(local.id);
    expect(restored.playlistSongs(playlist), isEmpty);
    expect(restored.lyricsFor(local.id), isEmpty);
  });
}
