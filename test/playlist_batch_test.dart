import 'dart:async';
import 'package:emoc/main.dart';
import 'package:flutter_test/flutter_test.dart';

MirrorItem song(int id) => MirrorItem(
  domId: '$id',
  kind: 'song',
  title: 'Song $id',
  subtitle: '',
  imageUrl: '',
  href: 'https://music.163.com/#/song?id=$id',
);

void main() {
  test('batch deduplicates songs and reports partial failures', () async {
    final controller = PlaylistBatchController();
    addTearDown(controller.dispose);
    final called = <String>[];
    await controller.run([song(1), song(2), song(1), song(3)], (song) async {
      called.add(song.id);
      if (song.id == '2') throw const MusicApiException('not owned');
    });
    expect(called, ['1', '2', '3']);
    expect(controller.total, 3);
    expect(controller.processed, 3);
    expect(controller.succeeded.map((item) => item.id), ['1', '3']);
    expect(controller.failures.keys, ['2']);
    expect(controller.running, isFalse);
  });

  test(
    'cancel keeps completed changes and stops subsequent requests',
    () async {
      final controller = PlaylistBatchController();
      addTearDown(controller.dispose);
      final gate = Completer<void>();
      final operation = controller.run([song(1), song(2)], (_) => gate.future);
      controller.cancel();
      gate.complete();
      await operation;
      expect(controller.succeeded, hasLength(1));
      expect(controller.processed, 1);
      expect(controller.canceled, isTrue);
    },
  );

  test('expired session stops the batch without retrying mutations', () async {
    final controller = PlaylistBatchController();
    addTearDown(controller.dispose);
    var calls = 0;
    await controller.run([song(1), song(2)], (_) async {
      calls++;
      throw const MusicApiException('expired', code: 301);
    });
    expect(calls, 1);
    expect(controller.canceled, isTrue);
    expect(controller.failures, hasLength(1));
  });
}
