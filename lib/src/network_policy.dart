part of '../main.dart';

class NetworkPlaybackPolicy extends ChangeNotifier {
  NetworkPlaybackPolicy({
    Future<Map<String, dynamic>> Function()? probe,
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : _probe = probe ?? NativeBridge.networkState,
       _read = read ?? NativeBridge.getString,
       _write = write ?? NativeBridge.setString;

  final Future<Map<String, dynamic>> Function() _probe;
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;
  static const storageKey = 'networkPolicy.v1';
  static const qualities = {
    'standard': '标准',
    'higher': '较高',
    'exhigh': '极高',
    'lossless': '无损',
  };
  String wifiQuality = 'higher';
  String mobileQuality = 'standard';
  bool wifiPrefetch = true;
  bool mobilePrefetch = false;
  bool allowMobilePlayback = true;
  bool fallbackQuality = true;
  bool connected = true;
  bool metered = true;
  bool wifi = false;
  bool known = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  bool get restrictedNetwork => metered || !wifi;
  bool get canStream =>
      connected && (!restrictedNetwork || allowMobilePlayback);
  bool get canPrefetch =>
      connected && (restrictedNetwork ? mobilePrefetch : wifiPrefetch);
  String get quality => restrictedNetwork ? mobileQuality : wifiQuality;
  String get networkLabel => !known
      ? '网络状态未知'
      : !connected
      ? '离线'
      : restrictedNetwork
      ? '移动或按流量计费网络'
      : 'Wi-Fi';

  Future<void> restore({String fallback = 'higher'}) async {
    wifiQuality = qualities.containsKey(fallback) ? fallback : 'higher';
    try {
      final raw = await _read(storageKey).timeout(const Duration(seconds: 2));
      if (_disposed) return;
      final data = raw == null ? <String, dynamic>{} : _mapOf(jsonDecode(raw));
      if (qualities.containsKey(data['wifiQuality'])) {
        wifiQuality = data['wifiQuality'];
      }
      if (qualities.containsKey(data['mobileQuality'])) {
        mobileQuality = data['mobileQuality'];
      }
      wifiPrefetch = data['wifiPrefetch'] != false;
      mobilePrefetch = data['mobilePrefetch'] == true;
      allowMobilePlayback = data['allowMobilePlayback'] != false;
      fallbackQuality = data['fallbackQuality'] != false;
    } catch (_) {}
    await refresh();
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    try {
      applyNetwork(await _probe().timeout(const Duration(seconds: 2)));
    } catch (_) {}
  }

  void applyNetwork(Map<String, dynamic> state) {
    if (_disposed) return;
    final nextConnected = state['connected'] != false;
    final nextMetered = state['metered'] != false;
    final nextWifi = state['wifi'] == true;
    if (known &&
        connected == nextConnected &&
        metered == nextMetered &&
        wifi == nextWifi) {
      return;
    }
    known = true;
    connected = nextConnected;
    metered = nextMetered;
    wifi = nextWifi;
    notifyListeners();
  }

  Future<void> update({
    String? wifiAudio,
    String? mobileAudio,
    bool? prefetchWifi,
    bool? prefetchMobile,
    bool? mobilePlayback,
    bool? downgrade,
  }) {
    if (qualities.containsKey(wifiAudio)) wifiQuality = wifiAudio!;
    if (qualities.containsKey(mobileAudio)) mobileQuality = mobileAudio!;
    wifiPrefetch = prefetchWifi ?? wifiPrefetch;
    mobilePrefetch = prefetchMobile ?? mobilePrefetch;
    allowMobilePlayback = mobilePlayback ?? allowMobilePlayback;
    fallbackQuality = downgrade ?? fallbackQuality;
    notifyListeners();
    final payload = jsonEncode({
      'wifiQuality': wifiQuality,
      'mobileQuality': mobileQuality,
      'wifiPrefetch': wifiPrefetch,
      'mobilePrefetch': mobilePrefetch,
      'allowMobilePlayback': allowMobilePlayback,
      'fallbackQuality': fallbackQuality,
    });
    final write = _writes.then((_) => _write(storageKey, payload));
    _writes = write.catchError((_) {});
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension NetworkPolicyIntegration on AppModel {
  void _handleNetworkPolicyChanged() {
    CoverRuntimeCache.instance.allowPrefetch = networkPolicy.canPrefetch;
    if (_nativePlaybackActive) unawaited(_refreshTransitionQueue());
    if (_nativePlaybackActive &&
        player.playing &&
        !player.songId.startsWith('local:') &&
        networkPolicy.connected &&
        networkPolicy.restrictedNetwork &&
        !networkPolicy.allowMobilePlayback) {
      _localPauseRequested = true;
      player = _playerWith(playing: false);
      unawaited(NativeBridge.pausePlayer().catchError((_) {}));
      _showNotice('移动网络播放已关闭，已暂停');
    }
    notifyListeners();
  }
}

class NetworkPolicyPage extends StatelessWidget {
  const NetworkPolicyPage({required this.policy, super.key});
  final NetworkPlaybackPolicy policy;

  Future<void> _save(BuildContext context, Future<void> write) async {
    try {
      await write;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设置保存失败')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: policy,
    builder: (context, _) => Scaffold(
      backgroundColor: AppScope.of(context).visualStyle == 'liquid'
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('网络与音质')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          AppCardSurface(
            model: AppScope.of(context),
            child: ListTile(
              leading: Icon(
                policy.connected ? Icons.network_check : Icons.wifi_off,
              ),
              title: Text(policy.networkLabel),
            ),
          ),
          const SizedBox(height: 16),
          for (final mobile in [false, true]) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCardSurface(
                model: AppScope.of(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: mobile
                            ? policy.mobileQuality
                            : policy.wifiQuality,
                        decoration: InputDecoration(
                          labelText: mobile ? '移动网络音质' : 'Wi-Fi 音质',
                        ),
                        items: NetworkPlaybackPolicy.qualities.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => _save(
                          context,
                          policy.update(
                            wifiAudio: mobile ? null : value,
                            mobileAudio: mobile ? value : null,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        title: Text(mobile ? '移动网络预加载' : 'Wi-Fi 预加载'),
                        value: mobile
                            ? policy.mobilePrefetch
                            : policy.wifiPrefetch,
                        onChanged: (value) => _save(
                          context,
                          policy.update(
                            prefetchWifi: mobile ? null : value,
                            prefetchMobile: mobile ? value : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          AppCardSurface(
            model: AppScope.of(context),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('允许移动网络播放'),
                  value: policy.allowMobilePlayback,
                  onChanged: (value) =>
                      _save(context, policy.update(mobilePlayback: value)),
                ),
                SwitchListTile(
                  title: const Text('音质请求失败时自动降级'),
                  value: policy.fallbackQuality,
                  onChanged: (value) =>
                      _save(context, policy.update(downgrade: value)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
