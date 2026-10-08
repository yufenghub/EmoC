import 'package:emoc/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metered network uses mobile rules and offline disables prefetch', () async {
    final policy = NetworkPlaybackPolicy(write: (_, _) async {});
    addTearDown(policy.dispose);
    policy.applyNetwork({'connected': true, 'wifi': true, 'metered': false});
    expect(policy.quality, 'higher');
    expect(policy.canPrefetch, isTrue);
    await policy.update(wifiAudio: 'lossless', mobilePlayback: false);
    policy.applyNetwork({'connected': true, 'wifi': true, 'metered': true});
    expect(policy.quality, 'standard');
    expect(policy.canStream, isFalse);
    expect(policy.canPrefetch, isFalse);
    policy.applyNetwork({'connected': false, 'wifi': true, 'metered': false});
    expect(policy.canStream, isFalse);
    expect(policy.canPrefetch, isFalse);
  });

  test('policy persists independent quality settings', () async {
    String? saved;
    final policy = NetworkPlaybackPolicy(write: (_, value) async { saved = value; });
    addTearDown(policy.dispose);
    await policy.update(wifiAudio: 'lossless', mobileAudio: 'exhigh', prefetchMobile: true, downgrade: false);
    final restored = NetworkPlaybackPolicy(read: (_) async => saved, write: (_, _) async {},
      probe: () async => {'connected': true, 'wifi': false, 'metered': true});
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.wifiQuality, 'lossless');
    expect(restored.quality, 'exhigh');
    expect(restored.canPrefetch, isTrue);
    expect(restored.fallbackQuality, isFalse);
  });
}
