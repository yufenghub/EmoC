import 'dart:async';
import 'dart:convert';

import 'package:emoc/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MirrorItem song(int id) => MirrorItem(
  domId: 'song_$id',
  kind: 'song',
  title: 'Song $id',
  subtitle: 'Artist',
  imageUrl: '',
  href: 'https://music.163.com/#/song?id=$id',
);

void main() {
  test(
    'recent playback and search history are deduplicated and restored',
    () async {
      String? saved;
      final history = ListeningHistory(
        read: (_) async => saved,
        write: (_, value) async {
          saved = value;
        },
      );
      addTearDown(history.dispose);
      await history.recordSong(song(1), at: DateTime(2026, 9, 1));
      await history.recordSong(song(2));
      await history.recordSong(song(1), at: DateTime(2026, 9, 15));
      await history.recordSearch('  Piano  ');
      await history.recordSearch('piano');
      expect(history.recent.map((entry) => entry.song.id), ['1', '2']);
      expect(history.recent.first.playedAt, DateTime(2026, 9, 15));
      expect(history.searches, ['piano']);
      final restored = ListeningHistory(
        read: (_) async => saved,
        write: (_, _) async {},
      );
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.recent.map((entry) => entry.song.id), ['1', '2']);
      expect(restored.searches, ['piano']);
    },
  );

  test('disabled history does not record and deletion persists', () async {
    String? saved;
    final history = ListeningHistory(
      write: (_, value) async {
        saved = value;
      },
    );
    addTearDown(history.dispose);
    await history.recordSong(song(1));
    await history.recordSearch('first');
    await history.setRecording(playback: false, searches: false);
    await history.recordSong(song(2));
    await history.recordSearch('second');
    expect(history.recent, hasLength(1));
    expect(history.searches, ['first']);
    await history.removeSong(song(1));
    await history.removeSearch('first');
    expect(jsonDecode(saved!)['recent'], isEmpty);
    expect(jsonDecode(saved!)['searches'], isEmpty);
  });

  test('clear wins over a delayed older write', () async {
    final gate = Completer<void>();
    String? saved;
    var count = 0;
    final history = ListeningHistory(
      write: (_, value) async {
        if (count++ == 0) await gate.future;
        saved = value;
      },
    );
    addTearDown(history.dispose);
    final old = history.recordSearch('old');
    final cleared = history.clearSearches();
    gate.complete();
    await Future.wait([old, cleared]);
    expect(jsonDecode(saved!)['searches'], isEmpty);
  });

  test('history is bounded and survives a malformed saved value', () async {
    final history = ListeningHistory(
      read: (_) async => '{broken',
      write: (_, _) async {},
    );
    addTearDown(history.dispose);
    await history.restore();
    for (var index = 0; index < 510; index++) {
      await history.recordSong(song(index));
      await history.recordSearch('query $index');
    }
    expect(history.recent, hasLength(ListeningHistory.maxRecent));
    expect(history.searches, hasLength(ListeningHistory.maxSearches));
  });

  testWidgets('recent history renders and removes a row', (tester) async {
    final model = AppModel(history: ListeningHistory(write: (_, _) async {}));
    addTearDown(model.dispose);
    await model.listeningHistory.recordSong(song(1));
    await tester.pumpWidget(
      MaterialApp(home: ListeningHistoryPage(model: model)),
    );
    expect(find.text('Song 1'), findsOneWidget);
    await tester.tap(find.byTooltip('删除记录'));
    await tester.pumpAndSettle();
    expect(find.text('暂无播放记录'), findsOneWidget);
  });
}
