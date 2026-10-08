import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:emoc/main.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
);

void main() {
  test('stalled cover bodies release all download slots', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var stalledRequests = 0;
    final allStarted = Completer<void>();
    server.listen((request) async {
      if (request.uri.path.startsWith('/stalled')) {
        stalledRequests++;
        request.response.contentLength = _png.length + 1;
        request.response.add(_png);
        await request.response.flush();
        if (stalledRequests == 6 && !allStarted.isCompleted) {
          allStarted.complete();
        }
        return;
      }
      request.response.add(_png);
      await request.response.close();
    });
    final base =
        'http://127.0.0.1:${server.port}/${DateTime.now().microsecondsSinceEpoch}';
    final cache = CoverRuntimeCache.instance;
    final stalled = List.generate(
      6,
      (index) => cache.load([
        'http://127.0.0.1:${server.port}/stalled-$index?run=$base',
      ]),
    );
    await allStarted.future.timeout(const Duration(seconds: 5));
    final healthy = cache.load(['$base/healthy.png']);

    final results = await Future.wait([
      ...stalled,
      healthy,
    ]).timeout(const Duration(seconds: 10));
    expect(results.take(6), everyElement(isNull));
    expect(results.last?.bytes, orderedEquals(_png));
  });

  test('concurrent cover requests share a download and memory cache', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      request.response.add(_png);
      await request.response.close();
    });
    final url =
        'http://127.0.0.1:${server.port}/${DateTime.now().microsecondsSinceEpoch}.png';
    final cache = CoverRuntimeCache.instance;

    final results = await Future.wait(
      List.generate(12, (_) => cache.load([url])),
    ).timeout(const Duration(seconds: 5));
    expect(results, everyElement(isNotNull));
    expect(requests, 1);
    expect((await cache.load([url]))?.bytes, orderedEquals(_png));
    expect(requests, 1);
  });

  for (final declaresLength in [true, false]) {
    test(
      'oversized cover is rejected (content length: $declaresLength)',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final oversized = Uint8List((3 << 20) + 1)..setAll(0, _png);
        server.listen((request) async {
          if (declaresLength) request.response.contentLength = oversized.length;
          try {
            request.response.add(oversized);
            await request.response.close();
          } on SocketException {
            // Early rejection can interrupt the server's response.
          } on HttpException {
            // Early rejection can interrupt the server's response.
          }
        });
        final url =
            'http://127.0.0.1:${server.port}/${DateTime.now().microsecondsSinceEpoch}.png';
        final cache = CoverRuntimeCache.instance;

        expect(
          await cache.load([url]).timeout(const Duration(seconds: 5)),
          isNull,
        );
        expect(cache.contains([url]), isFalse);
      },
    );
  }
}
