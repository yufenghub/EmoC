part of '../main.dart';

typedef PlainMusicRequest =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, dynamic> data, {
      required bool useGet,
    });

class MusicApiException implements Exception {
  const MusicApiException(this.message, {this.code = 0});

  final String message;
  final int code;

  @override
  String toString() => code > 0 ? '$message（错误码 $code）' : message;
}

class MusicMutationApiClient {
  MusicMutationApiClient({
    String baseUrl = 'https://music.163.com',
    Future<String> Function(String url)? cookieLoader,
    PlainMusicRequest? plainRequestOverride,
  }) : this._internal(baseUrl, cookieLoader, plainRequestOverride);

  MusicMutationApiClient._internal(
    this._baseUrl,
    this._cookieLoader,
    this._plainRequestOverride,
  );

  final String _baseUrl;
  final Future<String> Function(String url)? _cookieLoader;
  final PlainMusicRequest? _plainRequestOverride;
  static const String _nonce = '0CoJUm6Qyw8W8jud';
  static const String _iv = '0102030405060708';
  static const String _publicKey = '010001';
  static const String _modulus =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b7251'
      '52b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ec'
      'bda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d8'
      '13cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
  static const String _secretAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  Future<void> _mutationTail = Future<void>.value();
  final String _clientCookieId = _randomHex(32);
  final String _wnmcid = _newWnmcid();

  Future<({String id, String name})> createPlaylist(String name) {
    return _serial(() async {
      final response = await _sendPlainRequest(
        '/api/playlist/create',
        <String, dynamic>{'name': name, 'privacy': '0', 'type': 'NORMAL'},
      );
      final playlist = _mapOf(response['playlist'] ?? response['data']);
      return (
        id: _stringOf(playlist['id'] ?? response['id']),
        name: _stringOf(playlist['name']).trim().isNotEmpty
            ? _stringOf(playlist['name']).trim()
            : name,
      );
    });
  }

  Future<void> deletePlaylist(String playlistId) {
    return _serial(() async {
      final typedId = int.tryParse(playlistId) ?? playlistId;
      await _sendPlainRequest('/api/playlist/delete', <String, dynamic>{
        'pid': typedId,
      }, useGet: true);
    });
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) {
    return _manipulatePlaylist(
      operation: 'add',
      playlistId: playlistId,
      songId: songId,
    );
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) {
    return _manipulatePlaylist(
      operation: 'del',
      playlistId: playlistId,
      songId: songId,
    );
  }

  Future<void> setSongLiked(String songId, bool liked) {
    return _serial(() async {
      final typedSongId = int.tryParse(songId) ?? songId;
      final likeValue = liked.toString();
      await _request(
        '/weapi/radio/like',
        <String, dynamic>{
          'alg': 'itembased',
          'trackId': typedSongId,
          'like': liked,
          'time': DateTime.now().millisecondsSinceEpoch,
        },
        queryParameters: <String, String>{
          'alg': 'itembased',
          'trackId': '$typedSongId',
          'like': likeValue,
          'time': '3',
        },
      );
    });
  }

  Future<void> _manipulatePlaylist({
    required String operation,
    required String playlistId,
    required String songId,
  }) {
    return _serial(() async {
      final typedSongId = int.tryParse(songId) ?? songId;
      final trackIds = jsonEncode(<dynamic>[typedSongId]);
      await _request('/weapi/playlist/manipulate/tracks', <String, dynamic>{
        'op': operation,
        'pid': int.tryParse(playlistId) ?? playlistId,
        'trackIds': trackIds,
        'imme': 'true',
      });
    });
  }

  Future<T> _serial<T>(Future<T> Function() operation) async {
    final previous = _mutationTail;
    final gate = Completer<void>();
    _mutationTail = gate.future;
    await previous.catchError((_) {});
    try {
      return await operation();
    } finally {
      gate.complete();
    }
  }

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic> data, {
    Map<String, String> queryParameters = const <String, String>{},
  }) async {
    final cookie = await _loadCookie();
    if (!_hasLoginCookie(cookie)) {
      throw const MusicApiException('账号登录状态已失效，请重新登录', code: 301);
    }
    final csrf = _cookieValue(cookie, '__csrf');
    final payload = <String, dynamic>{
      ...data,
      'csrf_token': csrf,
      'e_r': false,
    };
    final encrypted = _encrypt(payload);
    final body = _form(<String, String>{
      'params': encrypted.params,
      'encSecKey': encrypted.encSecKey,
    });
    final query = <String, String>{
      ...queryParameters,
      if (csrf.isNotEmpty) 'csrf_token': csrf,
    };
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = true;
      request.maxRedirects = 3;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        AppModel._desktopUserAgent,
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain, */*',
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded;charset=UTF-8',
      );
      request.headers.set(HttpHeaders.refererHeader, '$_baseUrl/');
      request.headers.set('Origin', _baseUrl);
      request.headers.set('X-Requested-With', 'XMLHttpRequest');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(HttpHeaders.cookieHeader, _normalizedCookie(cookie));
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await utf8.decodeStream(response);
      final decoded = _decodeResponse(text);
      final code = _intOf(decoded['code'] ?? decoded['status']);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (code == 200 || code == 201 || code == 204)) {
        return decoded;
      }
      throw MusicApiException(
        _errorMessage(decoded, response.statusCode),
        code: code == 0 ? response.statusCode : code,
      );
    } on MusicApiException {
      rethrow;
    } on TimeoutException {
      throw const MusicApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw const MusicApiException('网络连接失败，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _plainRequest(
    String path,
    Map<String, dynamic> data, {
    bool useGet = false,
  }) async {
    final cookie = await _loadCookie();
    if (!_hasLoginCookie(cookie)) {
      throw const MusicApiException('账号登录状态已失效，请重新登录', code: 301);
    }
    final csrf = _cookieValue(cookie, '__csrf');
    final fields = <String, String>{
      for (final entry in data.entries) entry.key: '${entry.value}',
      if (csrf.isNotEmpty) 'csrf_token': csrf,
    };
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: useGet
          ? fields
          : (csrf.isEmpty ? null : {'csrf_token': csrf}),
    );
    final client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 12);
    try {
      final request = await (useGet ? client.getUrl(uri) : client.postUrl(uri))
          .timeout(const Duration(seconds: 10));
      request.followRedirects = true;
      request.maxRedirects = 3;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        AppModel._desktopUserAgent,
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/plain, */*',
      );
      request.headers.set(HttpHeaders.refererHeader, '$_baseUrl/');
      request.headers.set('Origin', _baseUrl);
      request.headers.set('X-Requested-With', 'XMLHttpRequest');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set(HttpHeaders.cookieHeader, _normalizedCookie(cookie));
      if (!useGet) {
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded;charset=UTF-8',
        );
        request.write(_form(fields));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final text = await utf8.decodeStream(response);
      final decoded = _decodeResponse(text);
      final code = _intOf(decoded['code'] ?? decoded['status']);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (code == 200 || code == 201 || code == 204)) {
        return decoded;
      }
      throw MusicApiException(
        _errorMessage(decoded, response.statusCode),
        code: code == 0 ? response.statusCode : code,
      );
    } on MusicApiException {
      rethrow;
    } on TimeoutException {
      throw const MusicApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw const MusicApiException('网络连接失败，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _sendPlainRequest(
    String path,
    Map<String, dynamic> data, {
    bool useGet = false,
  }) {
    final override = _plainRequestOverride;
    if (override != null) {
      return override(path, data, useGet: useGet);
    }
    return _plainRequest(path, data, useGet: useGet);
  }

  Future<String> _loadCookie() async {
    final loader = _cookieLoader;
    if (loader != null) {
      return loader(
        '$_baseUrl/',
      ).timeout(const Duration(seconds: 3), onTimeout: () => '');
    }
    return NativeBridge.getCookies(
      '$_baseUrl/',
    ).timeout(const Duration(seconds: 3), onTimeout: () => '');
  }

  ({String params, String encSecKey}) _encrypt(Map<String, dynamic> payload) {
    final secretKey = _randomSecretKey();
    final firstPass = _aesEncrypt(jsonEncode(payload), _nonce);
    final params = _aesEncrypt(firstPass, secretKey);
    return (params: params, encSecKey: _rsaEncrypt(secretKey));
  }

  String _aesEncrypt(String text, String key) {
    final cipher = pc.PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        pc.PaddedBlockCipherParameters<
          pc.ParametersWithIV<pc.KeyParameter>,
          Null
        >(
          pc.ParametersWithIV<pc.KeyParameter>(
            pc.KeyParameter(Uint8List.fromList(utf8.encode(key))),
            Uint8List.fromList(utf8.encode(_iv)),
          ),
          null,
        ),
      );
    return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(text))));
  }

  String _rsaEncrypt(String secretKey) {
    final reversed = secretKey.split('').reversed.join();
    final hexText = utf8
        .encode(reversed)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final value = BigInt.parse(hexText, radix: 16);
    final exponent = BigInt.parse(_publicKey, radix: 16);
    final modulus = BigInt.parse(_modulus, radix: 16);
    return value.modPow(exponent, modulus).toRadixString(16).padLeft(256, '0');
  }

  String _randomSecretKey() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => _secretAlphabet[random.nextInt(_secretAlphabet.length)],
      growable: false,
    ).join();
  }

  String _normalizedCookie(String cookie) {
    final additions = <String>[];
    void addIfMissing(String name, String value) {
      if (_cookieValue(cookie, name).isEmpty) {
        additions.add('$name=$value');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    addIfMissing('__remember_me', 'true');
    addIfMissing('ntes_kaola_ad', '1');
    addIfMissing('_ntes_nuid', _clientCookieId);
    addIfMissing('_ntes_nnid', '$_clientCookieId,$now');
    addIfMissing('WNMCID', _wnmcid);
    addIfMissing('WEVNSM', '1.0.0');
    addIfMissing('NMTID', _randomHex(16));
    addIfMissing('os', 'pc');
    addIfMissing(
      'osver',
      'Microsoft-Windows-10-Professional-build-19045-64bit',
    );
    addIfMissing('channel', 'netease');
    addIfMissing('appver', '3.1.17.204416');
    if (additions.isEmpty) return cookie;
    return <String>[
      cookie.trim(),
      ...additions,
    ].where((value) => value.isNotEmpty).join('; ');
  }

  static String _randomHex(int byteCount) {
    final random = Random.secure();
    return List<String>.generate(
      byteCount,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      growable: false,
    ).join();
  }

  static String _newWnmcid() {
    final random = Random.secure();
    final prefix = List<String>.generate(
      6,
      (_) => String.fromCharCode(97 + random.nextInt(26)),
      growable: false,
    ).join();
    return '$prefix.${DateTime.now().millisecondsSinceEpoch}.01.0';
  }

  bool _hasLoginCookie(String cookie) {
    return _cookieValue(cookie, 'MUSIC_U').isNotEmpty ||
        _cookieValue(cookie, 'MUSIC_A').isNotEmpty;
  }

  String _cookieValue(String cookie, String name) {
    final match = RegExp(
      '(?:^|;\\s*)${RegExp.escape(name)}=([^;]*)',
    ).firstMatch(cookie);
    final value = match?.group(1) ?? '';
    return value.isEmpty ? '' : Uri.decodeComponent(value);
  }

  String _form(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  Map<String, dynamic> _decodeResponse(String text) {
    try {
      return _mapOf(jsonDecode(text));
    } catch (_) {
      return <String, dynamic>{'code': 0, 'message': text.trim()};
    }
  }

  String _errorMessage(Map<String, dynamic> data, int httpStatus) {
    final code = _intOf(data['code'] ?? data['status']);
    if (code == 301 || code == 302 || httpStatus == 401) {
      return '账号登录状态已失效，请重新登录';
    }
    if (code == 405 || code == 406) return '操作过于频繁，请稍后重试';
    if (code == 507) return '歌单数量已达上限';
    if (code == 521) return '该账号需绑定手机号后才能操作歌单';
    if (code == 502) return '歌曲已在歌单中，或操作未生效';
    if (code == 404 || code == 512) return '歌单不存在，或当前账号无修改权限';
    final nested = _mapOf(data['data'] ?? data['result']);
    final message = _stringOf(
      data['message'] ??
          data['msg'] ??
          data['error'] ??
          nested['message'] ??
          nested['msg'],
    );
    if (message.isNotEmpty) return message;
    return '操作失败（${code == 0 ? httpStatus : code}）';
  }
}
