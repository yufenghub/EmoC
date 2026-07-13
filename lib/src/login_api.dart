part of '../main.dart';

class SmsLoginApiResult {
  const SmsLoginApiResult({
    required this.success,
    this.message = '',
    this.code = 0,
    this.accountId = '',
    this.accountName = '',
    this.cookies = '',
  });

  final bool success;
  final String message;
  final int code;
  final String accountId;
  final String accountName;
  final String cookies;
}

class _SmsApiAttempt {
  const _SmsApiAttempt({
    required this.path,
    required this.method,
    required this.body,
    required this.headers,
    this.verifyOnly = false,
  });

  final String path;
  final String method;
  final String body;
  final Map<String, String> headers;
  final bool verifyOnly;
}

class _SmsApiResponse {
  const _SmsApiResponse({required this.statusCode, required this.data});

  final int statusCode;
  final Map<String, dynamic> data;
}

class SmsLoginApiClient {
  final HttpClient _client = HttpClient()..autoUncompress = true;
  final Map<String, String> _cookies = <String, String>{};

  void reset() {
    _cookies.clear();
  }

  void dispose() {
    _client.close(force: true);
    _cookies.clear();
  }

  Future<SmsLoginApiResult> sendCode(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) {
      return const SmsLoginApiResult(success: false, message: '请输入手机号');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final deviceId = 'Android_${cleanPhone}_$stamp';
    final fullParams = _form(<String, String>{
      'cellphone': cleanPhone,
      'phone': cleanPhone,
      'ctcode': '86',
      'countrycode': '86',
      'os': 'android',
      'channel': 'netease',
      'appver': '9.1.65',
      'clienttype': 'android',
      'deviceId': deviceId,
      'buildver': stamp,
      'mobilename': 'Pixel 8 Pro',
    });
    final simplePhone = _form(<String, String>{
      'phone': cleanPhone,
      'ctcode': '86',
    });
    final simpleCellphone = _form(<String, String>{
      'cellphone': cleanPhone,
      'ctcode': '86',
    });
    final headers = _androidHeaders();
    final attempts = <_SmsApiAttempt>[
      _SmsApiAttempt(
        path: '/api/sms/captcha/sent?$fullParams&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/sms/captcha/sent',
        method: 'POST',
        body: fullParams,
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/sent?$fullParams&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/sent',
        method: 'POST',
        body: fullParams,
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/sms/captcha/sent?$simplePhone&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/sms/captcha/sent?$simpleCellphone&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/sent?$simplePhone&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/sent?$simpleCellphone&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: headers,
      ),
    ];

    var last = '';
    for (final attempt in attempts) {
      try {
        final response = await _request(attempt);
        final code = _intOf(
          response.data['code'] ?? _mapOf(response.data['data'])['code'],
        );
        final message = _messageOf(response.data, response.statusCode);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          last = message;
          continue;
        }
        if ((code == 200 || response.data['success'] == true) &&
            response.data['data'] != false &&
            !_looksFailed(message)) {
          return SmsLoginApiResult(
            success: true,
            code: code == 0 ? 200 : code,
            message: '验证码请求已提交，请查看短信',
            cookies: cookieHeader,
          );
        }
        last = message;
      } catch (error) {
        last = error.toString();
      }
    }
    return SmsLoginApiResult(
      success: false,
      message: last.isEmpty ? '验证码未发送成功，请稍后重试或使用扫码登录' : '验证码未发送成功：$last',
      cookies: cookieHeader,
    );
  }

  Future<SmsLoginApiResult> login(String phone, String code) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final cleanCode = code.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty || cleanCode.isEmpty) {
      return const SmsLoginApiResult(success: false, message: '请输入手机号和验证码');
    }
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final base = <String, String>{
      'phone': cleanPhone,
      'cellphone': cleanPhone,
      'captcha': cleanCode,
      'countrycode': '86',
      'ctcode': '86',
      'rememberLogin': 'true',
      'csrf_token': csrfToken,
    };
    final androidBody = _form(<String, String>{
      ...base,
      'os': 'android',
      'channel': 'netease',
      'appver': '9.1.65',
      'deviceId': 'Android_${cleanPhone}_$stamp',
      'buildver': stamp,
      'mobilename': 'Pixel 8 Pro',
      'clienttype': 'android',
    });
    final webBody = _form(<String, String>{
      ...base,
      'os': 'pc',
      'channel': 'netease',
      'appver': '3.0.18',
      'deviceId': 'PC_${cleanPhone}_$stamp',
      'requestId': '${stamp}_${DateTime.now().microsecond}',
      'type': '1',
      'clienttype': 'web',
    });
    final browserBody = _form(<String, String>{
      ...base,
      'os': 'web',
      'channel': 'netease',
      'appver': '2.10.13',
      'requestId': '${stamp}_${DateTime.now().microsecond}',
      'type': '1',
    });
    final androidHeaders = _androidHeaders();
    final webHeaders = _webHeaders();
    final attempts = <_SmsApiAttempt>[
      _SmsApiAttempt(
        path: '/api/sms/captcha/verify?$androidBody&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: androidHeaders,
        verifyOnly: true,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/verify?$androidBody&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: androidHeaders,
        verifyOnly: true,
      ),
      _SmsApiAttempt(
        path: '/api/captcha/verify',
        method: 'POST',
        body: androidBody,
        headers: androidHeaders,
        verifyOnly: true,
      ),
      _SmsApiAttempt(
        path: '/api/w/login/cellphone',
        method: 'POST',
        body: webBody,
        headers: webHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/login/cellphone',
        method: 'POST',
        body: webBody,
        headers: webHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/login/cellphone?$webBody&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: webHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/w/login/cellphone',
        method: 'POST',
        body: browserBody,
        headers: webHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/login/cellphone',
        method: 'POST',
        body: browserBody,
        headers: webHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/login/cellphone',
        method: 'POST',
        body: androidBody,
        headers: androidHeaders,
      ),
      _SmsApiAttempt(
        path: '/api/login/cellphone?$androidBody&timestamp=$stamp',
        method: 'GET',
        body: '',
        headers: androidHeaders,
      ),
    ];

    var last = '';
    var verified = false;
    for (final attempt in attempts) {
      try {
        final response = await _request(attempt);
        final data = response.data;
        final profile = _profileOf(data);
        final codeValue = _intOf(data['code'] ?? _mapOf(data['data'])['code']);
        if (attempt.verifyOnly && codeValue == 200) {
          verified = true;
          continue;
        }
        if (codeValue == 200 || profile.isNotEmpty) {
          if (profile.isEmpty) {
            final session = await probeSession();
            if (session.success) return session;
          }
          return SmsLoginApiResult(
            success: true,
            code: codeValue == 0 ? 200 : codeValue,
            accountId: _stringOf(profile['userId'] ?? profile['id']),
            accountName: _stringOf(
              profile['nickname'] ?? profile['userName'] ?? profile['name'],
            ),
            message: '登录成功',
            cookies: cookieHeader,
          );
        }
        last = _messageOf(data, response.statusCode);
      } catch (error) {
        last = error.toString();
      }
    }
    if (verified && last.toUpperCase().contains('ENC')) {
      last = '验证码已校验，但登录服务拒绝当前设备参数（ENC）';
    }
    return SmsLoginApiResult(
      success: false,
      message: last.isEmpty ? '验证码登录失败，请检查验证码或使用扫码登录' : '验证码登录失败：$last',
      cookies: cookieHeader,
    );
  }

  Future<SmsLoginApiResult> probeSession() async {
    try {
      final response = await _request(
        _SmsApiAttempt(
          path:
              '/api/w/nuser/account/get?timestamp=${DateTime.now().millisecondsSinceEpoch}',
          method: 'GET',
          body: '',
          headers: _webHeaders(),
        ),
      );
      final profile = _profileOf(response.data);
      if (profile.isNotEmpty) {
        return SmsLoginApiResult(
          success: true,
          code: 200,
          accountId: _stringOf(profile['userId'] ?? profile['id']),
          accountName: _stringOf(
            profile['nickname'] ?? profile['userName'] ?? profile['name'],
          ),
          message: '登录成功',
          cookies: cookieHeader,
        );
      }
    } catch (_) {}
    return SmsLoginApiResult(success: false, cookies: cookieHeader);
  }

  String get cookieHeader {
    if (_cookies.isEmpty) return '';
    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  String get csrfToken => _cookies['__csrf'] ?? '';

  Future<_SmsApiResponse> _request(_SmsApiAttempt attempt) async {
    final uri = Uri.parse('https://music.163.com${attempt.path}');
    final request = await _client.openUrl(attempt.method, uri);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      AppModel._desktopUserAgent,
    );
    for (final entry in attempt.headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    if (_cookies.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader);
    }
    if (attempt.method == 'POST') {
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded;charset=UTF-8',
      );
      request.write(attempt.body);
    }
    final response = await request.close().timeout(const Duration(seconds: 12));
    _captureCookies(response.headers[HttpHeaders.setCookieHeader] ?? const []);
    final text = await utf8.decodeStream(response);
    final data = _decodeMap(text);
    return _SmsApiResponse(statusCode: response.statusCode, data: data);
  }

  void _captureCookies(List<String> setCookies) {
    for (final value in setCookies) {
      final pair = value.split(';').first.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final name = pair.substring(0, index);
      final cookieValue = pair.substring(index + 1);
      if (name.isNotEmpty) _cookies[name] = cookieValue;
    }
  }

  Map<String, String> _androidHeaders() {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      HttpHeaders.refererHeader: 'https://music.163.com/',
      'Origin': 'https://music.163.com',
      'X-Requested-With': 'com.netease.cloudmusic',
      HttpHeaders.cacheControlHeader: 'no-cache',
    };
  }

  Map<String, String> _webHeaders() {
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json, text/plain, */*',
      HttpHeaders.refererHeader: 'https://music.163.com/',
      'Origin': 'https://music.163.com',
      'X-Requested-With': 'XMLHttpRequest',
      HttpHeaders.cacheControlHeader: 'no-cache',
    };
  }

  String _form(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  Map<String, dynamic> _decodeMap(String text) {
    try {
      final decoded = jsonDecode(text);
      return _mapOf(decoded);
    } catch (_) {
      return <String, dynamic>{'code': 0, 'message': text};
    }
  }

  Map<String, dynamic> _profileOf(Map<String, dynamic> data) {
    final direct = _mapOf(data['profile']);
    if (direct.isNotEmpty) return direct;
    final accountProfile = _mapOf(_mapOf(data['account'])['profile']);
    if (accountProfile.isNotEmpty) return accountProfile;
    return _mapOf(_mapOf(data['data'])['profile']);
  }

  String _messageOf(Map<String, dynamic> data, int statusCode) {
    final nested = _mapOf(data['data']);
    final message = _stringOf(
      data['message'] ??
          data['msg'] ??
          data['errmsg'] ??
          nested['message'] ??
          nested['msg'],
    );
    if (message.isNotEmpty) return message;
    return '接口返回 ${data['code'] ?? statusCode}';
  }

  bool _looksFailed(String message) {
    return RegExp(
      r'接口.*(未找到|不存在)|not\s*found|404|无权限|权限|风控|频繁|失败|参数|ENC',
      caseSensitive: false,
    ).hasMatch(message);
  }
}
