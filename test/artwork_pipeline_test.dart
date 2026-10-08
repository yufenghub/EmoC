import 'dart:async';

import 'package:emoc/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

List<MirrorItem> _songs(String prefix, int count) => List.generate(
  count,
  (index) => MirrorItem(
    domId: '${prefix}_$index',
    kind: 'song',
    title: '$prefix $index',
    subtitle: 'Artist',
    imageUrl: '',
    href: 'https://music.163.com/#/song?id=$index',
  ),
);

class _ArtworkModel extends AppModel {
  final batches = <List<MirrorItem>>[];
  Completer<bool>? pending;

  @override
  Future<bool> prepareSongArtworkBatch(
    List<MirrorItem> songs, {
    bool forceMissingMetadata = false,
  }) {
    batches.add(songs);
    return pending?.future ?? Future.value(true);
  }
}

void main() {
  testWidgets('disposed viewport ignores its scheduled frame', (tester) async {
    final model = _ArtworkModel()..showSongCovers = true;
    addTearDown(model.dispose);
    final viewport = SongViewportController(batchSize: 6, eager: false);
    await tester.pumpWidget(const SizedBox());

    viewport.synchronize(model, _songs('disposed', 12));
    viewport.dispose();
    tester.binding.scheduleFrame();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(model.batches, isEmpty);
  });

  testWidgets('disposed viewport stops after in-flight artwork', (
    tester,
  ) async {
    final model = _ArtworkModel()
      ..showSongCovers = true
      ..pending = Completer<bool>();
    addTearDown(model.dispose);
    final viewport = SongViewportController(batchSize: 12, eager: true);
    await tester.pumpWidget(const SizedBox());
    viewport.synchronize(model, _songs('pending', 24));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(model.batches, hasLength(1));

    viewport.dispose();
    model.pending!.complete(true);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(model.batches, hasLength(1));
  });

  testWidgets('disposed viewport cancels automatic prefetch', (tester) async {
    final model = _ArtworkModel()..showSongCovers = true;
    addTearDown(model.dispose);
    final viewport = SongViewportController(batchSize: 6, eager: true);
    await tester.pumpWidget(const SizedBox());
    viewport.synchronize(model, _songs('automatic', 24));
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(viewport.readyCount, 6);

    viewport.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(model.batches, hasLength(1));
  });

  testWidgets('old prefetch cannot advance a restored playlist', (
    tester,
  ) async {
    final model = _ArtworkModel()..showSongCovers = true;
    addTearDown(model.dispose);
    final viewport = SongViewportController(batchSize: 6, eager: true);
    addTearDown(viewport.dispose);
    await tester.pumpWidget(const SizedBox());
    viewport.synchronize(model, _songs('old', 24));
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(viewport.readyCount, 6);

    viewport.reset();
    viewport.synchronize(model, _songs('new', 24), initialReadyCount: 6);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(viewport.readyCount, 6);
    expect(model.batches, hasLength(2));
  });
}
