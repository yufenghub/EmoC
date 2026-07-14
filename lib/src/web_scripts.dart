part of '../main.dart';

const _onPageReadyScript = r'''
  (function () {
    if (!window.__EMOC_READY_INSTALLED__) {
      window.__EMOC_READY_INSTALLED__ = true;
      window.__EMOC_INSTALL_MEDIA_BLOCK__ = function (targetWindow) {
        try {
          targetWindow = targetWindow || window;
          if (!targetWindow.__EMOC_REALTIME_MEDIA_BLOCKED__) {
            targetWindow.__EMOC_REALTIME_MEDIA_BLOCKED__ = true;
            try { targetWindow.RTCPeerConnection = undefined; } catch (e) {}
            try { targetWindow.webkitRTCPeerConnection = undefined; } catch (e) {}
            try { targetWindow.AudioContext = undefined; } catch (e) {}
            try { targetWindow.webkitAudioContext = undefined; } catch (e) {}
            try {
              var devices = targetWindow.navigator && targetWindow.navigator.mediaDevices;
              if (devices) {
                devices.getUserMedia = function () {
                  return Promise.reject(new DOMException('Blocked by EmoC', 'NotAllowedError'));
                };
                devices.getDisplayMedia = function () {
                  return Promise.reject(new DOMException('Blocked by EmoC', 'NotAllowedError'));
                };
                devices.enumerateDevices = function () { return Promise.resolve([]); };
              }
            } catch (e) {}
          }
          var proto = targetWindow.HTMLMediaElement && targetWindow.HTMLMediaElement.prototype;
          if (!proto || proto.__EMOC_PLAY_BLOCKED__) return;
          proto.__EMOC_ORIGINAL_PLAY__ = proto.play;
          proto.play = function () {
            try { this.pause(); } catch (e) {}
            try { this.muted = true; } catch (e) {}
            return Promise.resolve();
          };
          proto.__EMOC_PLAY_BLOCKED__ = true;
        } catch (e) {}
      };
      window.__EMOC_SWEEP_MEDIA__ = function () {
        function sweep(doc) {
          try {
            Array.prototype.slice.call(doc.querySelectorAll('audio,video')).forEach(function (media) {
              try { media.pause(); } catch (e) {}
              try { media.muted = true; } catch (e) {}
              try { media.volume = 0; } catch (e) {}
              try { media.autoplay = false; } catch (e) {}
            });
          } catch (e) {}
        }
        try { window.__EMOC_INSTALL_MEDIA_BLOCK__(window); } catch (e) {}
        sweep(document);
        try {
          var frame = document.querySelector('#g_iframe');
          if (frame && frame.contentWindow) window.__EMOC_INSTALL_MEDIA_BLOCK__(frame.contentWindow);
          if (frame && frame.contentDocument) sweep(frame.contentDocument);
        } catch (e) {}
      };
      window.__EMOC_SWEEP_BURST__ = function () {
        [0, 80, 200, 500, 1000, 1800].forEach(function (delay) {
          setTimeout(function () {
            try { window.__EMOC_SWEEP_MEDIA__(); } catch (e) {}
          }, delay);
        });
      };
      try { window.__EMOC_MEDIA_SWEEP_TIMER__ = setInterval(window.__EMOC_SWEEP_MEDIA__, 900); } catch (e) {}
      try {
        var domains = [
          ['preconnect', 'https://music.163.com'],
          ['preconnect', 'https://interface.music.163.com'],
          ['preconnect', 'https://interface3.music.163.com'],
          ['preconnect', 'https://m701.music.126.net'],
          ['preconnect', 'https://m801.music.126.net'],
          ['dns-prefetch', '//music.126.net']
        ];
        for (var d = 0; d < domains.length; d++) {
          var link = document.createElement('link');
          link.rel = domains[d][0];
          link.href = domains[d][1];
          document.head.appendChild(link);
        }
      } catch (e) {}
    }
    function lockBar() {
      try {
        var outerBar = document.querySelector('.m-playbar');
        if (outerBar) {
          outerBar.style.cssText = 'position:fixed !important;top:auto !important;bottom:0 !important;left:0 !important;right:0 !important;z-index:999999 !important;display:block !important;opacity:1 !important;visibility:visible !important;pointer-events:auto !important;';
          outerBar.classList.add('m-playbar-lock');
        }
        var innerBar = document.querySelector('#g_player');
        if (innerBar) {
          innerBar.style.cssText = 'position:relative !important;margin-left:0 !important;left:0 !important;width:100% !important;';
        }
        var hand = document.querySelector('.m-playbar .hand');
        if (hand) hand.style.display = 'none';
      } catch (e) {}
    }
    lockBar();
    try { window.__EMOC_SWEEP_MEDIA__ && window.__EMOC_SWEEP_MEDIA__(); } catch (e) {}
    try { window.__EMOC_SWEEP_BURST__ && window.__EMOC_SWEEP_BURST__(); } catch (e) {}
  })();
''';

const _silenceOfficialAudioScript = r'''
  (function () {
    try { window.__EMOC_INSTALL_MEDIA_BLOCK__ && window.__EMOC_INSTALL_MEDIA_BLOCK__(window); } catch (e) {}
    function silence(root) {
      try {
        Array.prototype.slice.call(root.querySelectorAll('audio,video')).forEach(function (media) {
          try { media.pause(); } catch (e) {}
          try { media.muted = true; } catch (e) {}
          try { media.volume = 0; } catch (e) {}
          try { media.autoplay = false; } catch (e) {}
        });
      } catch (e) {}
    }
    silence(document);
    try {
      var frame = document.querySelector('#g_iframe');
      if (frame && frame.contentWindow && window.__EMOC_INSTALL_MEDIA_BLOCK__) window.__EMOC_INSTALL_MEDIA_BLOCK__(frame.contentWindow);
      if (frame && frame.contentDocument) silence(frame.contentDocument);
    } catch (e) {}
    try { window.__EMOC_SWEEP_BURST__ && window.__EMOC_SWEEP_BURST__(); } catch (e) {}
  })();
''';

// ignore: unused_element
const _webAppSkinScript = r'''
  (function () {
    var css = `
      html, body {
        min-width: 0 !important;
        width: 100% !important;
        margin: 0 !important;
        background: #0a0b0e !important;
        overscroll-behavior: none !important;
        -webkit-tap-highlight-color: transparent !important;
        -webkit-user-select: none !important;
        user-select: none !important;
      }
      * {
        box-sizing: border-box !important;
        letter-spacing: 0 !important;
      }
      *::-webkit-scrollbar {
        width: 0 !important;
        height: 0 !important;
        display: none !important;
      }
      a, button, input, textarea, select, [role="button"] {
        -webkit-user-select: auto !important;
        user-select: auto !important;
      }
      img {
        max-width: 100% !important;
      }
      #g_iframe {
        display: block !important;
        width: 100vw !important;
        max-width: 100vw !important;
        min-height: calc(100vh - 72px) !important;
        border: 0 !important;
        background: #0a0b0e !important;
      }
      #g_nav, #g_nav2, #g_top, .g-top, .g-topbar, .m-top {
        max-width: 100vw !important;
      }
      .m-top .wrap, .g-topbar .wrap, .m-subnav .wrap, .m-subnav-up .wrap {
        width: 100vw !important;
        max-width: 100vw !important;
        min-width: 0 !important;
        padding-left: 10px !important;
        padding-right: 10px !important;
      }
      .m-top .logo, .g-topbar .logo {
        margin-left: 0 !important;
      }
      .m-top .m-nav, .g-topbar .m-nav {
        overflow-x: auto !important;
        white-space: nowrap !important;
        max-width: calc(100vw - 118px) !important;
      }
      .m-top .m-nav li, .g-topbar .m-nav li {
        float: none !important;
        display: inline-block !important;
      }
      .m-top .srchbg, .m-top .m-srch, .g-topbar .m-srch {
        max-width: 42vw !important;
      }
      .m-playbar, #g_player, .g-btmbar {
        position: fixed !important;
        left: 0 !important;
        right: 0 !important;
        bottom: 0 !important;
        top: auto !important;
        z-index: 2147483000 !important;
        opacity: 1 !important;
        visibility: visible !important;
        pointer-events: auto !important;
      }
      .m-playbar .hand, .m-playbar .updn {
        display: none !important;
      }
      .m-playbar .wrap, #g_player .wrap {
        width: 100vw !important;
        max-width: 100vw !important;
        left: 0 !important;
        margin-left: 0 !important;
        padding: 0 8px !important;
      }
      .m-playbar .words, .m-playbar .m-pbar {
        max-width: calc(100vw - 190px) !important;
      }
      #g_footer, .g-ft, .m-ft, .m-client, .m-down, .m-back, .n-clmnad, .g-sd, .g-sd1, .g-sd2, .g-sd3, .g-sd4 {
        display: none !important;
      }
      .g-bd, .g-bd1, .g-bd2, .g-bd3, .g-bd4, .g-wrap, .g-mn, .g-mn1, .g-mn2, .g-mn3, .g-mn4,
      .n-minelst, .n-songtb, .n-srchrst, .m-table, .m-table table, .m-cvrlst, .m-cvrlst ul,
      .m-record, .m-tabs, .u-title, .n-rcmd, .n-new, .n-bill {
        width: 100% !important;
        max-width: 100% !important;
        min-width: 0 !important;
        margin-left: 0 !important;
        margin-right: 0 !important;
      }
      .g-bd, .g-bd1, .g-bd2, .g-bd3, .g-bd4, .g-wrap {
        padding-left: 10px !important;
        padding-right: 10px !important;
        padding-bottom: 92px !important;
      }
      .g-mn, .g-mn1, .g-mn2, .g-mn3, .g-mn4 {
        float: none !important;
      }
      .m-table {
        table-layout: fixed !important;
      }
      .m-table th, .m-table td {
        max-width: 44vw !important;
        overflow: hidden !important;
        text-overflow: ellipsis !important;
        white-space: nowrap !important;
      }
      .m-table th:nth-child(n+4), .m-table td:nth-child(n+4) {
        display: none !important;
      }
      .m-table .w1, .m-table .w2, .m-table .w3, .m-table .w4 {
        width: auto !important;
      }
      .m-cvrlst li, .n-minelst li {
        width: 48% !important;
        margin: 0 1% 16px !important;
      }
      .m-cvrlst .u-cover, .m-cvrlst .u-cover img {
        width: 100% !important;
        height: auto !important;
        aspect-ratio: 1 / 1 !important;
      }
      input, textarea {
        font-size: 16px !important;
      }
      @media (min-width: 700px) {
        .m-cvrlst li, .n-minelst li {
          width: 31.33% !important;
        }
        .m-table th:nth-child(4), .m-table td:nth-child(4) {
          display: table-cell !important;
        }
      }
    `;

    function install(doc) {
      if (!doc || !doc.documentElement) return;
      try {
        var viewport = doc.querySelector('meta[name="viewport"]');
        if (!viewport) {
          viewport = doc.createElement('meta');
          viewport.name = 'viewport';
          doc.head.appendChild(viewport);
        }
        viewport.content = 'width=device-width, initial-scale=1, maximum-scale=1, viewport-fit=cover';
        var style = doc.getElementById('emoc-webapp-skin');
        if (!style) {
          style = doc.createElement('style');
          style.id = 'emoc-webapp-skin';
          doc.head.appendChild(style);
        }
        style.textContent = css;
      } catch (e) {}
    }

    function applyAll() {
      install(document);
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentDocument) install(frame.contentDocument);
      } catch (e) {}
    }

    applyAll();
    [120, 350, 800, 1400, 2400, 4000].forEach(function (delay) {
      setTimeout(applyAll, delay);
    });
  })();
''';

const _openLoginScript = r'''
  (function () {
    function clean(el) {
      return (el && el.textContent || '').replace(/\s+/g, '').trim();
    }
    var nodes = Array.prototype.slice.call(document.querySelectorAll('a,button,span,div'));
    for (var i = 0; i < nodes.length; i++) {
      var label = clean(nodes[i]);
      if (label === '登录' || label === '立即登录' || label === '用户登录') {
        var target = nodes[i].closest('a,button') || nodes[i];
        target.click();
        return true;
      }
    }
    return false;
  })();
''';

const _createOfficialQrScript = r'''
  (function () {
    function send(payload) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({ type: 'qrLogin' }, payload)));
    }
    fetch('/api/login/qrcode/unikey?type=3&timestamp=' + Date.now(), {
      credentials: 'include',
      headers: { 'Accept': 'application/json, text/plain, */*' }
    })
      .then(function (response) { return response.json(); })
      .then(function (data) {
        var key = data.unikey || (data.data && (data.data.unikey || data.data.uniKey)) || '';
        if (!key) {
          send({ message: '官网没有返回二维码 key' });
          return;
        }
        window.__EMOC_QR_KEY__ = key;
        send({
          key: key,
          qrData: 'https://music.163.com/login?codekey=' + encodeURIComponent(key),
          message: '使用网易云音乐扫码登录'
        });
      })
      .catch(function (error) {
        send({ message: '二维码生成失败：' + error });
      });
  })();
''';

const _pollOfficialQrScript = r'''
  (function () {
    var key = window.__EMOC_QR_KEY__ || '';
    if (!key) return;
    function send(payload) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({ type: 'qrLogin' }, payload)));
    }
    fetch('/api/login/qrcode/client/login?key=' + encodeURIComponent(key) + '&type=3&timestamp=' + Date.now(), {
      credentials: 'include',
      headers: { 'Accept': 'application/json, text/plain, */*' }
    })
      .then(function (response) { return response.json(); })
      .then(function (data) {
        var code = String(data.code || '');
        var message = data.message || data.msg || '';
        if (code === '801') message = '使用网易云音乐扫码登录';
        if (code === '802') message = '使用网易云音乐扫码登录';
        if (code === '803') message = '登录成功，正在进入应用';
        if (code === '800') message = '二维码已过期，请刷新';
        send({ code: code, message: message });
      })
      .catch(function (error) {
        send({ message: '检查扫码状态失败：' + error });
      });
  })();
''';

// Retained as a compatibility fallback for older official WebView sessions.
// The current login flow uses SmsLoginApiClient directly.
// ignore: unused_element
const _smsCaptchaSentScript = r'''
  (async function () {
    var payload = window.__EMOC_SMS_PAYLOAD__ || {};
    var phone = String(payload.phone || '').replace(/\D/g, '');
    function post(data) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({
        type: 'smsLogin',
        phase: 'send'
      }, data || {})));
    }
    async function apiCaptchaSent() {
      var stamp = String(Date.now());
      var deviceId = 'Android_' + phone + '_' + stamp;
      var params = 'cellphone=' + encodeURIComponent(phone) +
        '&phone=' + encodeURIComponent(phone) +
        '&ctcode=86&countrycode=86' +
        '&os=android&channel=netease&appver=9.1.65' +
        '&clienttype=android' +
        '&deviceId=' + encodeURIComponent(deviceId) +
        '&buildver=' + stamp +
        '&mobilename=Pixel%208%20Pro';
      var simplePhone = 'phone=' + encodeURIComponent(phone) + '&ctcode=86';
      var simpleCellphone = 'cellphone=' + encodeURIComponent(phone) + '&ctcode=86';
      var attempts = [
        { url: '/api/sms/captcha/sent?' + params + '&timestamp=' + Date.now(), method: 'GET' },
        { url: '/api/sms/captcha/sent', method: 'POST', body: params },
        { url: '/api/captcha/sent?' + params + '&timestamp=' + Date.now(), method: 'GET' },
        { url: '/api/captcha/sent', method: 'POST', body: params },
        { url: '/api/sms/captcha/sent?' + simplePhone + '&timestamp=' + Date.now(), method: 'GET' },
        { url: '/api/sms/captcha/sent?' + simpleCellphone + '&timestamp=' + Date.now(), method: 'GET' },
        { url: '/api/captcha/sent?' + simplePhone + '&timestamp=' + Date.now(), method: 'GET' },
        { url: '/api/captcha/sent?' + simpleCellphone + '&timestamp=' + Date.now(), method: 'GET' }
      ];
      var last = '';
      function parseJson(text) {
        try { return JSON.parse(text || '{}'); } catch (e) {
          return { code: 0, message: text || '' };
        }
      }
      function messageOf(data, response) {
        return data.message || data.msg || data.errmsg ||
          (data.data && (data.data.message || data.data.msg)) ||
          ('接口返回 ' + (data.code || response.status));
      }
      function looksFailed(message) {
        return /接口.*(未找到|不存在)|not\s*found|404|无权限|权限|风控|频繁|失败|参数|ENC/i.test(message || '');
      }
      for (var i = 0; i < attempts.length; i++) {
        try {
          var request = attempts[i];
          var response = await fetch(request.url, {
            method: request.method,
            credentials: 'include',
            cache: 'no-store',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Cache-Control': 'no-cache',
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
              'Referer': 'https://music.163.com/',
              'Origin': 'https://music.163.com',
              'X-Requested-With': 'com.netease.cloudmusic'
            },
            body: request.method === 'POST' ? request.body : undefined
          });
          var data = parseJson(await response.text());
          var code = Number(data.code || (data.data && data.data.code) || 0);
          var message = messageOf(data, response);
          if (!response.ok) {
            last = message;
            continue;
          }
          if ((code === 200 || data.success === true) &&
              data.data !== false &&
              !looksFailed(message)) {
            return { ok: true, message: message };
          }
          last = message;
        } catch (e) {
          last = String(e && e.message ? e.message : e);
        }
      }
      return { ok: false, message: last };
    }
    if (!phone) {
      post({ success: false, message: '请输入手机号' });
      return;
    }
    var apiResult = await apiCaptchaSent();
    if (apiResult.ok) {
      post({ success: true, message: '验证码请求已提交，请查看短信' });
      return;
    }
    post({
      success: false,
      message: apiResult.message
        ? ('验证码未发送成功：' + apiResult.message)
        : '验证码未发送成功，请稍后重试或使用扫码登录'
    });
  })();
''';

// Retained as a compatibility fallback for older official WebView sessions.
// The current login flow uses SmsLoginApiClient directly.
// ignore: unused_element
const _smsLoginScript = r'''
  (async function () {
    var payload = window.__EMOC_SMS_PAYLOAD__ || {};
    var phone = String(payload.phone || '').replace(/\D/g, '');
    var code = String(payload.code || '').replace(/\D/g, '');
    function post(data) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({
        type: 'smsLogin',
        phase: 'login'
      }, data || {})));
    }
    async function probeSession() {
      try {
        var response = await fetch('/api/w/nuser/account/get?timestamp=' + Date.now(), {
          credentials: 'include',
          headers: { 'Accept': 'application/json, text/plain, */*' }
        });
        var data = await response.json();
        var profile = data.profile || (data.data && data.data.profile) || {};
        if (profile.userId || profile.id) {
          return {
            ok: true,
            id: profile.userId || profile.id || '',
            name: profile.nickname || profile.userName || profile.name || ''
          };
        }
      } catch (e) {}
      return { ok: false };
    }
    async function apiLogin() {
      var deviceId = 'Android_' + phone + '_' + Date.now();
      function csrf() {
        var match = document.cookie.match(/(?:^|;\s*)__csrf=([^;]+)/);
        return match ? decodeURIComponent(match[1]) : '';
      }
      function parseJson(text) {
        try { return JSON.parse(text); } catch (e) { return { code: 0, message: text || '' }; }
      }
      function form(parts) {
        return Object.keys(parts).map(function (key) {
          return encodeURIComponent(key) + '=' + encodeURIComponent(parts[key]);
        }).join('&');
      }
      var token = csrf();
      var base = {
        phone: phone,
        cellphone: phone,
        captcha: code,
        countrycode: '86',
        ctcode: '86',
        rememberLogin: 'true',
        csrf_token: token
      };
      var androidBody = form(Object.assign({}, base, {
        os: 'android',
        channel: 'netease',
        appver: '9.1.65',
        deviceId: deviceId,
        buildver: String(Date.now()),
        mobilename: 'Pixel 8 Pro',
        clienttype: 'android'
      }));
      var webBody = form(Object.assign({}, base, {
        os: 'pc',
        channel: 'netease',
        appver: '3.0.18',
        deviceId: 'PC_' + phone + '_' + Date.now(),
        requestId: String(Date.now()) + '_' + Math.floor(Math.random() * 100000),
        type: '1',
        clienttype: 'web'
      }));
      var browserBody = form(Object.assign({}, base, {
        os: 'web',
        channel: 'netease',
        appver: '2.10.13',
        requestId: String(Date.now()) + '_' + Math.floor(Math.random() * 100000),
        type: '1'
      }));
      var body = androidBody;
      var androidHeaders = {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'Referer': 'https://music.163.com/',
        'Origin': 'https://music.163.com',
        'X-Requested-With': 'com.netease.cloudmusic'
      };
      var webHeaders = {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'Referer': 'https://music.163.com/',
        'Origin': 'https://music.163.com',
        'X-Requested-With': 'XMLHttpRequest'
      };
      var attempts = [
        { url: '/api/sms/captcha/verify?' + androidBody + '&timestamp=' + Date.now(), method: 'GET', verifyOnly: true, headers: androidHeaders },
        { url: '/api/captcha/verify?' + androidBody + '&timestamp=' + Date.now(), method: 'GET', verifyOnly: true, headers: androidHeaders },
        { url: '/api/captcha/verify', method: 'POST', body: androidBody, verifyOnly: true, headers: androidHeaders },
        { url: '/api/w/login/cellphone', method: 'POST', body: webBody, headers: webHeaders },
        { url: '/api/login/cellphone', method: 'POST', body: webBody, headers: webHeaders },
        { url: '/api/login/cellphone?' + webBody + '&timestamp=' + Date.now(), method: 'GET', headers: webHeaders },
        { url: '/api/w/login/cellphone', method: 'POST', body: browserBody, headers: webHeaders },
        { url: '/api/login/cellphone', method: 'POST', body: browserBody, headers: webHeaders },
        { url: '/api/login/cellphone', method: 'POST', body: androidBody, headers: androidHeaders },
        { url: '/api/login/cellphone?' + androidBody + '&timestamp=' + Date.now(), method: 'GET', headers: androidHeaders }
      ];
      var last = '';
      var verified = false;
      for (var i = 0; i < attempts.length; i++) {
        try {
          var request = attempts[i];
          var response = await fetch(request.url, {
            method: request.method,
            credentials: 'include',
            headers: request.headers,
            body: request.method === 'POST' ? request.body : undefined
          });
          var data = parseJson(await response.text());
          var profile = data.profile || (data.account && data.profile) || (data.data && data.data.profile) || {};
          var codeValue = Number(data.code || (data.data && data.data.code) || 0);
          if (request.verifyOnly && codeValue === 200) {
            verified = true;
            continue;
          }
          if (codeValue === 200 || profile.userId || profile.id) {
            if (!(profile.userId || profile.id)) {
              var session = await probeSession();
              if (session.ok) return session;
            }
            return {
              ok: true,
              id: profile.userId || profile.id || '',
              name: profile.nickname || profile.userName || profile.name || ''
            };
          }
          last = data.message || data.msg || ('接口返回 ' + (data.code || response.status));
        } catch (e) {
          last = String(e && e.message ? e.message : e);
        }
      }
      if (verified && /enc|ENC/.test(last)) {
        return { ok: false, message: '验证码已校验，但登录服务拒绝当前设备参数（ENC）' };
      }
      return { ok: false, message: last };
    }
    if (!phone || !code) {
      post({ success: false, message: '请输入手机号和验证码' });
      return;
    }
    var apiSession = await apiLogin();
    if (apiSession.ok) {
      post({
        success: true,
        code: 200,
        accountId: apiSession.id,
        accountName: apiSession.name,
        message: '登录成功'
      });
      return;
    }
    post({ success: false, message: apiSession.message ? ('验证码登录失败：' + apiSession.message) : '验证码登录失败，请检查验证码或使用扫码登录' });
  })();
''';

const _logoutOfficialScript = r'''
  (function () {
    try {
      fetch('/api/logout?timestamp=' + Date.now(), {
        credentials: 'include',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://music.163.com/'
        }
      }).catch(function () {});
    } catch (e) {}
  })();
''';

const _loginProjectionScript = r'''
  (function () {
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function visible(el) {
      if (!el) return false;
      var r = el.getBoundingClientRect();
      var s = window.getComputedStyle(el);
      return r.width > 20 && r.height > 20 && s.display !== 'none' && s.visibility !== 'hidden' && parseFloat(s.opacity || '1') > 0;
    }
    var loginText = '';
    var avatar = '';
    var account = '';
    var accountId = '';
    var topImgs = Array.prototype.slice.call(document.querySelectorAll('.m-tophead img,.head img,img'));
    for (var i = 0; i < topImgs.length; i++) {
      if (visible(topImgs[i]) && (topImgs[i].src || '').indexOf('avatar') >= 0) {
        avatar = abs(topImgs[i].src);
        break;
      }
    }
    var topNodes = Array.prototype.slice.call(document.querySelectorAll('.m-tophead a,.m-tophead span,.head a,.head span,a,span'));
    for (var t = 0; t < topNodes.length; t++) {
      var text = clean(topNodes[t].getAttribute('title')) || clean(topNodes[t].textContent);
      if (text && text !== '登录' && text.length > 1 && text.length < 24 && visible(topNodes[t])) {
        if ((topNodes[t].href || '').indexOf('/user/home') >= 0 || avatar) {
          account = text;
          var match = String(topNodes[t].href || '').match(/[?&]id=(\d+)/);
          if (match) accountId = match[1];
          break;
        }
      }
    }
    try {
      if (!accountId && window.GUser && (GUser.userId || GUser.userID)) {
        accountId = String(GUser.userId || GUser.userID);
      }
    } catch (e) {}
    var loginLinks = topNodes.filter(function (el) { return clean(el.textContent) === '登录'; });
    var loggedIn = avatar !== '' || (account !== '' && loginLinks.length === 0);

    var qrImage = '';
    var imgs = Array.prototype.slice.call(document.querySelectorAll('img'));
    imgs.sort(function (a, b) {
      return (b.getBoundingClientRect().width * b.getBoundingClientRect().height) -
        (a.getBoundingClientRect().width * a.getBoundingClientRect().height);
    });
    for (var q = 0; q < imgs.length; q++) {
      var src = imgs[q].getAttribute('src') || '';
      var rect = imgs[q].getBoundingClientRect();
      if (visible(imgs[q]) && rect.width >= 120 && rect.height >= 120) {
        qrImage = abs(src);
        break;
      }
      if (src.indexOf('qr') >= 0 || src.indexOf('login') >= 0) {
        qrImage = abs(src);
        break;
      }
    }
    if (!qrImage) {
      var canvases = Array.prototype.slice.call(document.querySelectorAll('canvas'));
      for (var c = 0; c < canvases.length; c++) {
        var cr = canvases[c].getBoundingClientRect();
        if (visible(canvases[c]) && cr.width >= 120 && cr.height >= 120) {
          try { qrImage = canvases[c].toDataURL('image/png'); } catch (e) {}
          if (qrImage) break;
        }
      }
    }
    var methods = [];
    var nodes = Array.prototype.slice.call(document.querySelectorAll('a,button,span'));
    for (var m = 0; m < nodes.length; m++) {
      var label = clean(nodes[m].textContent);
      if (!label || label.length > 12) continue;
      if (label.indexOf('手机') >= 0 ||
          label.indexOf('密码') >= 0 ||
          label.indexOf('验证码') >= 0 ||
          label.indexOf('短信') >= 0 ||
          label.indexOf('微信') >= 0 ||
          label.indexOf('扫码') >= 0 ||
          label.indexOf('其他') >= 0) {
        if (methods.indexOf(label) < 0) methods.push(label);
      }
    }
    EmoCMirror.postMessage(JSON.stringify({
      type: 'login',
      loggedIn: loggedIn,
      accountId: accountId,
      accountName: account || '已登录账号',
      avatarUrl: avatar,
      qrImage: qrImage,
      methods: methods
    }));
  })();
''';

const _sessionProbeScript = r'''
  (function () {
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function post(loggedIn, profile) {
      profile = profile || {};
      EmoCMirror.postMessage(JSON.stringify({
        type: 'login',
        loggedIn: !!loggedIn,
        accountId: String(profile.userId || profile.id || ''),
        accountName: clean(profile.nickname || profile.userName || profile.name || ''),
        avatarUrl: abs(profile.avatarUrl || profile.avatarImgIdStr || ''),
        methods: []
      }));
    }
    fetch('/api/w/nuser/account/get?timestamp=' + Date.now(), {
      credentials: 'include',
      headers: { 'Accept': 'application/json, text/plain, */*' }
    })
      .then(function (response) { return response.json(); })
      .then(function (data) {
        var profile = data.profile || (data.data && data.data.profile) || {};
        post(!!(profile.userId || profile.id), profile);
      })
      .catch(function () {
        post(false, {});
      });
  })();
''';

const _searchScript = r'''
  (function () {
    var query = window.__EMOC_SEARCH_QUERY__ || '';
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    var input = document.querySelector('.m-srch input,input[type="text"]');
    if (input) {
      input.focus();
      input.value = query;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new KeyboardEvent('keyup', { key: query.slice(-1) || 'a', bubbles: true }));
    }
    setTimeout(function () {
      var items = [];
      var seen = {};
      var nodes = Array.prototype.slice.call(document.querySelectorAll('.m-schlist a,.m-suggest a,.u-suggest a,a[href*="/search/"],a[href*="/song?id="],a[href*="/artist?id="],a[href*="/album?id="]'));
      for (var i = 0; i < nodes.length; i++) {
        var title = clean(nodes[i].textContent || nodes[i].getAttribute('title'));
        if (!title || title.length < 1 || title === query) continue;
        var key = title + '|' + (nodes[i].href || '');
        if (seen[key]) continue;
        seen[key] = true;
        if (!nodes[i].getAttribute('data-emoc-id')) nodes[i].setAttribute('data-emoc-id', 'sug_' + i + '_' + Date.now());
        items.push({
          domId: nodes[i].getAttribute('data-emoc-id'),
          kind: 'suggestion',
          title: title,
          subtitle: '相关搜索',
          imageUrl: '',
          href: abs(nodes[i].getAttribute('href') || '')
        });
        if (items.length >= 8) break;
      }
      if (items.length === 0 && query) {
        items.push({ domId: 'direct_search', kind: 'suggestion', title: query, subtitle: '搜索关键词', imageUrl: '', href: '' });
      }
      EmoCMirror.postMessage(JSON.stringify({ type: 'suggestions', items: items }));
    }, 600);
  })();
''';

const _librarySnapshotScript = r'''
  (function () {
    var requestId = Number(window.__EMOC_SNAPSHOT_REQUEST_ID__ || 0);
    function post(items, message) {
      EmoCMirror.postMessage(JSON.stringify({
        type: 'snapshot',
        context: 'library',
        requestId: requestId,
        url: location.href,
        items: items || [],
        message: message || ''
      }));
    }
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function validPlaylistTitle(title) {
      title = clean(title);
      if (!title || title.length > 80) return false;
      if (/^(来自歌单|相关歌单|推荐歌单|热门推荐|包含这首歌的歌单|歌单|更多|查看全部)$/.test(title)) return false;
      return true;
    }
    function fromDom() {
      var items = [];
      var seen = {};
      var roots = [document];
      var frame = document.querySelector('#g_iframe');
      try { if (frame && frame.contentDocument) roots.push(frame.contentDocument); } catch (e) {}
      for (var r = 0; r < roots.length; r++) {
        var anchors = Array.prototype.slice.call(roots[r].querySelectorAll('a[href*="/my/m/music/playlist?id="],a[href*="/playlist?id="]'));
        for (var i = 0; i < anchors.length; i++) {
          var href = anchors[i].getAttribute('href') || anchors[i].href || '';
          var idMatch = href.match(/[?&]id=(\d+)/);
          if (!idMatch) continue;
          var block = anchors[i].closest('li,.item,.j-iflag,.f-cb') || anchors[i];
          var title = clean(anchors[i].getAttribute('title')) || clean(anchors[i].textContent) || clean(block.textContent);
          title = title.replace(/\s+\d+首.*$/, '');
          if (!validPlaylistTitle(title)) continue;
          var key = idMatch[1] + '|' + title;
          if (seen[key]) continue;
          seen[key] = true;
          var img = block.querySelector('img');
          items.push({
            domId: 'playlist_dom_' + idMatch[1],
            kind: title.indexOf('我喜欢的音乐') >= 0 ? 'liked' : 'playlist',
            title: title,
            subtitle: clean(block.textContent).replace(title, '').slice(0, 40),
            imageUrl: abs(img ? (img.getAttribute('data-src') || img.getAttribute('src')) : ''),
            href: 'https://music.163.com/#/my/m/music/playlist?id=' + idMatch[1]
          });
        }
      }
      return items;
    }
    function profileIdFromWindow() {
      var wins = [window];
      var frames = Array.prototype.slice.call(document.querySelectorAll('iframe'));
      for (var i = 0; i < frames.length; i++) {
        try { if (frames[i].contentWindow) wins.push(frames[i].contentWindow); } catch (e) {}
      }
      for (var w = 0; w < wins.length; w++) {
        try {
          var candidate = wins[w];
          if (candidate.GUser && (candidate.GUser.userId || candidate.GUser.userID)) return candidate.GUser.userId || candidate.GUser.userID;
          if (candidate.NEJ_CONF && candidate.NEJ_CONF.userId) return candidate.NEJ_CONF.userId;
          if (candidate.__INITIAL_STATE__ && candidate.__INITIAL_STATE__.user && candidate.__INITIAL_STATE__.user.userId) {
            return candidate.__INITIAL_STATE__.user.userId;
          }
        } catch (e) {}
      }
      return 0;
    }
    function accountId() {
      var uid = profileIdFromWindow();
      if (uid) return Promise.resolve(uid);
      var urls = [
        '/api/w/nuser/account/get?timestamp=' + Date.now(),
        '/api/nuser/account/get?timestamp=' + Date.now(),
        '/api/user/account?timestamp=' + Date.now()
      ];
      return urls.reduce(function (chain, url) {
        return chain.then(function (found) {
          if (found) return found;
          return fetch(url, { credentials: 'include' })
            .then(function (response) { return response.json(); })
            .then(function (data) {
              var profile = data.profile || (data.data && data.data.profile) || {};
              var account = data.account || (data.data && data.data.account) || {};
              return profile.userId || profile.id || account.id || account.userId || 0;
            })
            .catch(function () { return 0; });
        });
      }, Promise.resolve(0));
    }
    accountId()
      .then(function (uid) {
        if (!uid) {
          post([], '未获取到账号 ID');
          return null;
        }
        return fetch('/api/user/playlist?uid=' + encodeURIComponent(uid) + '&limit=1000&offset=0&timestamp=' + Date.now(), {
          credentials: 'include'
        })
          .then(function (response) { return response.json(); })
          .then(function (data) {
            var playlists = data.playlist || (data.data && data.data.playlist) || [];
            var items = [];
            for (var i = 0; i < playlists.length; i++) {
              var p = playlists[i] || {};
              var creator = p.creator || {};
              var title = clean(p.name);
              var isLiked = i === 0 || title.indexOf('我喜欢的音乐') >= 0 || p.specialType === 5;
              if (!title && isLiked) title = '我喜欢的音乐';
              if (!validPlaylistTitle(title)) continue;
              var isMine = String(creator.userId || creator.id || uid) === String(uid);
              if (!isLiked && !isMine) continue;
              var id = String(p.id || '');
              if (!id) continue;
              items.push({
                domId: 'playlist_api_' + id,
                kind: isLiked ? 'liked' : 'playlist',
                title: title || (isLiked ? '我喜欢的音乐' : '创建的歌单'),
                subtitle: (p.trackCount || 0) + ' 首',
                imageUrl: p.coverImgUrl || p.picUrl || '',
                href: 'https://music.163.com/#/my/m/music/playlist?id=' + id
              });
            }
            post(items, '');
          });
      })
      .catch(function (error) {
        post([], '歌单加载失败：' + error);
      });
  })();
''';

const _playlistSnapshotScript = r'''
  (function () {
    var requestId = Number(window.__EMOC_SNAPSHOT_REQUEST_ID__ || 0);
    function post(items, message) {
      var targetId = activePlaylistId();
      EmoCMirror.postMessage(JSON.stringify({
        type: 'snapshot',
        context: 'playlist',
        requestId: requestId,
        targetId: targetId,
        url: location.href,
        items: items || [],
        message: message || ''
      }));
    }
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function activePlaylistId() {
      var explicit = String(window.__EMOC_ACTIVE_PLAYLIST_ID__ || '').trim();
      if (explicit) return explicit;
      var target = String(window.__EMOC_SNAPSHOT_TARGET_ID__ || '').trim();
      if (target) return target;
      var match = String(location.href).match(/[?&]id=(\d+)/);
      return match ? match[1] : '';
    }
    function pageLooksLikePlaylist(id) {
      if (!id) return false;
      var href = String(location.href);
      if (href.indexOf('playlist?id=' + id) >= 0) return true;
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentWindow && String(frame.contentWindow.location.href).indexOf('playlist?id=' + id) >= 0) return true;
      } catch (e) {}
      return false;
    }
    function songIdFrom(value) {
      var match = String(value || '').match(/[?&]id=(\d+)/);
      return match ? match[1] : '';
    }
    function artists(song) {
      var list = song.ar || song.artists || [];
      return list.map(function (item) { return clean(item.name); }).filter(Boolean).join(' / ');
    }
    function album(song) {
      var al = song.al || song.album || {};
      return clean(al.name);
    }
    function songItem(song, index, prefix) {
      song = song || {};
      var id = String(song.id || '').trim();
      if (!id) return null;
      var al = song.al || song.album || {};
      var title = clean(song.name);
      if (!title) return null;
      return {
        domId: (prefix || 'playlist_api') + '_' + id + '_' + index,
        kind: 'song',
        title: title,
        subtitle: [artists(song), album(song)].filter(Boolean).join(' · '),
        imageUrl: al.picUrl || al.pic || '',
        href: 'https://music.163.com/#/song?id=' + id
      };
    }
    function fetchSongDetails(ids) {
      ids = (ids || [])
        .map(function (id) { return Number(id); })
        .filter(function (id, index, all) { return id > 0 && all.indexOf(id) === index; })
        .slice(0, 5000);
      if (!ids.length) return Promise.resolve([]);
      var chunks = [];
      for (var i = 0; i < ids.length; i += 200) chunks.push(ids.slice(i, i + 200));
      var items = [];
      return chunks.reduce(function (chain, chunk, chunkIndex) {
        return chain.then(function () {
          return fetch('/api/song/detail?ids=' + encodeURIComponent(JSON.stringify(chunk)) + '&timestamp=' + Date.now(), {
            credentials: 'include'
          })
            .then(function (response) { return response.json(); })
            .then(function (data) {
              var songs = data.songs || data.data || [];
              for (var s = 0; s < songs.length; s++) {
                var item = songItem(songs[s], chunkIndex * 200 + s, 'playlist_api');
                if (item) items.push(item);
              }
            });
        });
      }, Promise.resolve()).then(function () { return items; });
    }
    function listFrom(value) {
      return Array.isArray(value) ? value : [];
    }
    function songListsFrom(data) {
      var lists = [];
      var roots = [
        data || {},
        (data && data.data) || {},
        (data && data.result) || {},
        (data && data.playlist) || {},
        (data && data.data && data.data.playlist) || {}
      ];
      for (var r = 0; r < roots.length; r++) {
        var root = roots[r] || {};
        if (Array.isArray(root)) lists.push(root);
        [
          root.songs,
          root.tracks,
          root.list,
          root.items,
          root.datas
        ].forEach(function (candidate) {
          if (Array.isArray(candidate) && candidate.length) lists.push(candidate);
        });
      }
      return lists;
    }
    function idListsFrom(data) {
      var ids = [];
      var roots = [
        data || {},
        (data && data.data) || {},
        (data && data.result) || {},
        (data && data.playlist) || {},
        (data && data.data && data.data.playlist) || {}
      ];
      for (var r = 0; r < roots.length; r++) {
        var root = roots[r] || {};
        [
          root.trackIds,
          root.trackids,
          root.ids,
          root.privileges
        ].forEach(function (candidate) {
          listFrom(candidate).forEach(function (item) {
            var id = item && (item.id || item.songId || item.trackId || item);
            if (id) ids.push(id);
          });
        });
      }
      return ids.filter(function (id, index, all) {
        return Number(id) > 0 && all.indexOf(id) === index;
      });
    }
    function parsePlaylistDetail(data, playlistId) {
      var playlist = data.playlist || (data.data && data.data.playlist) || {};
      var returnedId = String(playlist.id || playlist.playlistId || '');
      if (returnedId && returnedId !== String(playlistId)) throw new Error('歌单 ID 不匹配');
      var songLists = songListsFrom(data);
      for (var i = 0; i < songLists.length; i++) {
        var items = songLists[i]
          .map(function (song, index) { return songItem(song, index, 'playlist_api'); })
          .filter(Boolean);
        if (items.length) return items;
      }
      var trackIds = idListsFrom(data);
      if (trackIds.length) return fetchSongDetails(trackIds);
      return [];
    }
    function fromApi(playlistId) {
      var endpoints = [
        '/api/playlist/track/all?id=' + encodeURIComponent(playlistId) + '&limit=5000&offset=0&timestamp=' + Date.now(),
        '/api/v6/playlist/track/all?id=' + encodeURIComponent(playlistId) + '&limit=5000&offset=0&timestamp=' + Date.now(),
        '/api/playlist/detail?id=' + encodeURIComponent(playlistId) + '&n=5000&s=8&limit=5000&offset=0&timestamp=' + Date.now(),
        '/api/v6/playlist/detail?id=' + encodeURIComponent(playlistId) + '&n=5000&s=8&limit=5000&offset=0&timestamp=' + Date.now(),
        '/api/playlist/detail?id=' + encodeURIComponent(playlistId) + '&n=5000&s=0&limit=5000&offset=0&timestamp=' + Date.now(),
        '/api/v6/playlist/detail?id=' + encodeURIComponent(playlistId) + '&n=5000&s=0&limit=5000&offset=0&timestamp=' + Date.now()
      ];
      return endpoints.reduce(function (chain, endpoint) {
        return chain.catch(function () {
          return fetch(endpoint, {
            credentials: 'include',
            headers: { 'Accept': 'application/json, text/plain, */*' }
          })
            .then(function (response) { return response.json(); })
            .then(function (data) {
              return Promise.resolve(parsePlaylistDetail(data, playlistId))
                .then(function (items) {
                  if (items && items.length) return items;
                  throw new Error('empty playlist endpoint');
                });
            });
        });
      }, Promise.reject(new Error('start')));
    }
    function enrichCovers(items, done) {
      var missing = items
        .filter(function (item) { return !item.imageUrl; })
        .map(function (item) {
          var match = String(item.href || '').match(/[?&]id=(\d+)/);
          return match ? Number(match[1]) : 0;
        })
        .filter(function (id) { return id > 0; });
      if (!missing.length) {
        done(items);
        return;
      }
      fetch('/api/song/detail?ids=' + encodeURIComponent(JSON.stringify(missing)) + '&timestamp=' + Date.now(), {
        credentials: 'include'
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          var songs = data.songs || data.data || [];
          var covers = {};
          for (var i = 0; i < songs.length; i++) {
            var song = songs[i] || {};
            var albumInfo = song.al || song.album || {};
            if (song.id && albumInfo.picUrl) covers[String(song.id)] = albumInfo.picUrl;
          }
          for (var j = 0; j < items.length; j++) {
            var match = String(items[j].href || '').match(/[?&]id=(\d+)/);
            if (match && covers[match[1]]) items[j].imageUrl = covers[match[1]];
          }
          done(items);
        })
        .catch(function () { done(items); });
    }
    function fromDom() {
      var targetPlaylistId = activePlaylistId();
      var items = [];
      var seen = {};
      var roots = [document];
      var frame = document.querySelector('#g_iframe');
      try { if (frame && frame.contentDocument) roots.push(frame.contentDocument); } catch (e) {}
      for (var r = 0; r < roots.length; r++) {
        var anchors = Array.prototype.slice.call(roots[r].querySelectorAll('a[href*="/song?id="]'));
        for (var i = 0; i < anchors.length; i++) {
          if (anchors[i].closest('#g_player,.m-playbar,.g-btmbar,.listbd,.listlyric,.m-schlist,.m-suggest,.m-playlist,.m-search')) continue;
          var href = anchors[i].getAttribute('href') || anchors[i].href || '';
          var idMatch = href.match(/[?&]id=(\d+)/);
          if (!idMatch) continue;
          var block = anchors[i].closest('table.m-table tr,.m-table tr,tr[id],.j-tr,.song-list tr,.f-cb,li,.item') || anchors[i].parentElement || anchors[i];
          var title = clean(anchors[i].getAttribute('title')) || clean(anchors[i].textContent);
          if (!title) continue;
          var key = idMatch[1] + '|' + title;
          if (seen[key]) continue;
          seen[key] = true;
          var domId = 'song_dom_' + idMatch[1] + '_' + i;
          try {
            block.setAttribute('data-emoc-id', domId);
            var play = block.querySelector('[data-res-id="' + idMatch[1] + '"],[data-res-action="play"],.ply');
            if (play) play.setAttribute('data-emoc-id', domId + '_play');
          } catch (e) {}
          items.push({
            domId: domId,
            kind: 'song',
            title: title,
            subtitle: clean(block.textContent).replace(title, '').slice(0, 80),
            imageUrl: '',
            href: 'https://music.163.com/#/song?id=' + idMatch[1]
          });
        }
      }
      return items;
    }
    function postDomOrEmpty(message) {
      var tries = 0;
      function attempt() {
        var domItems = fromDom();
        if (domItems.length) {
          enrichCovers(domItems, function (items) { post(items, ''); });
          return;
        }
        tries++;
        if (tries < 7) {
          setTimeout(attempt, 650);
          return;
        }
        post([], message || '无歌曲');
      }
      attempt();
    }
    var playlistId = activePlaylistId();
    if (!playlistId) {
      post([], '未识别到歌单 ID');
      return;
    }
    fromApi(playlistId)
      .then(function (apiItems) {
        if (apiItems && apiItems.length) {
          post(apiItems, '');
          return;
        }
        postDomOrEmpty('无歌曲');
      })
      .catch(function (error) {
        postDomOrEmpty('歌单接口返回失败：' + error);
      });
  })();
''';

const _dailySnapshotScript = r'''
  (function () {
    var requestId = Number(window.__EMOC_SNAPSHOT_REQUEST_ID__ || 0);
    function post(items, message) {
      EmoCMirror.postMessage(JSON.stringify({
        type: 'snapshot',
        context: 'daily',
        requestId: requestId,
        url: location.href,
        items: items || [],
        message: message || ''
      }));
    }
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function songIdFrom(value) {
      var match = String(value || '').match(/[?&]id=(\d+)/);
      return match ? match[1] : '';
    }
    function enrichAndPost(items) {
      if (!items.length) {
        post(items, '每日推荐暂未加载到歌曲表格');
        return;
      }
      var ids = items.map(function (item) { return Number(songIdFrom(item.href)); }).filter(function (id) { return id > 0; });
      if (!ids.length) {
        post(items, '');
        return;
      }
      fetch('/api/song/detail?ids=' + encodeURIComponent(JSON.stringify(ids)) + '&timestamp=' + Date.now(), {
        credentials: 'include'
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          var songs = data.songs || data.data || [];
          var byId = {};
          for (var s = 0; s < songs.length; s++) {
            var song = songs[s] || {};
            var id = String(song.id || '');
            if (!id) continue;
            var album = song.al || song.album || {};
            var artists = song.ar || song.artists || [];
            byId[id] = {
              title: clean(song.name),
              subtitle: [
                artists.map(function (item) { return clean(item.name); }).filter(Boolean).join(' / '),
                clean(album.name)
              ].filter(Boolean).join(' · '),
              imageUrl: album.picUrl || ''
            };
          }
          for (var i = 0; i < items.length; i++) {
            var info = byId[songIdFrom(items[i].href)];
            if (!info) continue;
            if (info.title) items[i].title = info.title;
            if (info.subtitle) items[i].subtitle = info.subtitle;
            if (info.imageUrl) items[i].imageUrl = info.imageUrl;
          }
          post(items, '');
        })
        .catch(function () { post(items, ''); });
    }
    function frameDocument() {
      var frame = document.querySelector('#g_iframe');
      try { if (frame && frame.contentDocument) return frame.contentDocument; } catch (e) {}
      return document;
    }
    function currentPageHref() {
      var href = String(location.href || '');
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentWindow) href += ' ' + String(frame.contentWindow.location.href || '');
      } catch (e) {}
      return href;
    }
    if (currentPageHref().indexOf('/discover/recommend/taste') < 0) {
      EmoCMirror.postMessage(JSON.stringify({
        type: 'snapshot',
        context: 'daily',
        requestId: requestId,
        url: location.href,
        items: [],
        stale: true,
        message: '等待每日推荐页面加载'
      }));
      return;
    }
    function blocked(el) {
      return !!(el && el.closest('#g_player,.m-playbar,.g-btmbar,.listbd,.listlyric,.m-schlist,.m-suggest,.m-playlist'));
    }
    function titleFrom(link) {
      if (!link) return '';
      var bold = link.querySelector('b');
      return clean(link.getAttribute('title')) ||
        clean(bold ? bold.getAttribute('title') : '') ||
        clean(bold ? bold.textContent : '') ||
        clean(link.textContent);
    }
    function songFromRow(row, index) {
      if (!row || blocked(row)) return null;
      var play = row.querySelector('[data-res-action="play"][data-res-id],[data-res-id][data-res-type="18"],.ply[data-res-id]');
      var link = row.querySelector('.tt a[href*="/song?id="],a[href*="/song?id="]');
      var id = play ? String(play.getAttribute('data-res-id') || '') : '';
      if (!id) id = songIdFrom(link ? (link.getAttribute('href') || link.href) : '');
      var title = titleFrom(link);
      if (!id || !title || title.length > 120) return null;
      var cells = Array.prototype.slice.call(row.querySelectorAll('td'));
      var artistCell = cells.length > 3 ? cells[3] : null;
      var albumCell = cells.length > 4 ? cells[4] : null;
      var artists = artistCell ? Array.prototype.slice.call(artistCell.querySelectorAll('a'))
        .map(function (a) { return clean(a.getAttribute('title')) || clean(a.textContent); })
        .filter(Boolean)
        .join(' / ') : '';
      var albumLink = albumCell ? albumCell.querySelector('a') : null;
      var album = albumLink ? (clean(albumLink.getAttribute('title')) || clean(albumLink.textContent)) : clean(albumCell ? albumCell.textContent : '');
      var domId = 'daily_' + id + '_' + index;
      try {
        row.setAttribute('data-emoc-id', domId);
        if (play) play.setAttribute('data-emoc-id', domId + '_play');
      } catch (e) {}
      return {
        domId: domId,
        kind: 'song',
        title: title,
        subtitle: [artists, album].filter(Boolean).join(' · '),
        imageUrl: '',
        href: 'https://music.163.com/#/song?id=' + id
      };
    }
    var root = frameDocument();
    var rows = Array.prototype.slice.call(root.querySelectorAll('table.m-table tbody tr,.m-table tbody tr,tr[id]'));
    var items = [];
    var seen = {};
    for (var i = 0; i < rows.length; i++) {
      var item = songFromRow(rows[i], i);
      if (!item) continue;
      if (seen[item.href]) continue;
      seen[item.href] = true;
      items.push(item);
      if (items.length >= 35) break;
    }
    if (items.length === 0) {
      var anchors = Array.prototype.slice.call(root.querySelectorAll('.m-table a[href*="/song?id="],table a[href*="/song?id="]'));
      for (var a = 0; a < anchors.length; a++) {
        if (blocked(anchors[a])) continue;
        var row = anchors[a].closest('tr');
        var fallback = songFromRow(row, a);
        if (!fallback || seen[fallback.href]) continue;
        seen[fallback.href] = true;
        items.push(fallback);
        if (items.length >= 35) break;
      }
    }
    enrichAndPost(items);
  })();
''';

// ignore: unused_element
const _playSongScript = r'''
  (function () {
    var payload = window.__EMOC_PLAY_SONG__ || {};
    var songId = String(payload.id || '').trim();
    var domId = String(payload.domId || '').trim();
    var href = payload.href || (songId ? ('https://music.163.com/#/song?id=' + songId) : '');
    var songTitle = payload.title || '';
    var songArtist = payload.artist || '';
    var songCover = payload.coverUrl || '';
    if (!songId) return false;

    window.__EMOC_PENDING_SONG_ID__ = songId;
    window.__EMOC_PENDING_TITLE__ = songTitle;
    window.__EMOC_PENDING_ARTIST__ = songArtist;
    window.__EMOC_PENDING_COVER__ = songCover;

    var errorPosted = false;
    function postPlayError(reason) {
      if (errorPosted) return;
      errorPosted = true;
      EmoCMirror.postMessage(JSON.stringify({ type: 'playError', reason: reason }));
    }
    function click(el) {
      if (!el) return false;
      try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch (e) {}
      try {
        var rect = el.getBoundingClientRect();
        var x = rect && rect.width ? rect.left + rect.width / 2 : 0;
        var y = rect && rect.height ? rect.top + rect.height / 2 : 0;
        ['pointerover', 'mouseover', 'pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function (type) {
          var pointer = type.indexOf('pointer') === 0;
          var EventCtor = pointer && typeof PointerEvent !== 'undefined' ? PointerEvent : MouseEvent;
          el.dispatchEvent(new EventCtor(type, {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
            screenX: x,
            screenY: y,
            button: 0,
            buttons: (type === 'mousedown' || type === 'pointerdown') ? 1 : 0
          }));
        });
      } catch (e) {}
      try {
        el.click();
      } catch (e) {
        try { el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window, button: 0 })); } catch (_) {}
      }
      return true;
    }
    function documents() {
      var docs = [document];
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentDocument) docs.push(frame.contentDocument);
      } catch (e) {}
      return docs;
    }
    function tryClickPlay() {
      var escaped = songId.replace(/"/g, '');
      function elementMatchesSong(el) {
        return el && String(el.getAttribute('data-res-id') || '').trim() === songId;
      }
      function playCandidateIn(root) {
        if (!root) return null;
        var nodes = Array.prototype.slice.call(root.querySelectorAll('[data-res-id],.ply,[data-res-action="play"],a[href*="song?id="]'));
        for (var n = 0; n < nodes.length; n++) {
          var node = nodes[n];
          if (node.closest && node.closest('#g_player,.m-playbar,.g-btmbar,.listbd,.listlyric')) continue;
          if (elementMatchesSong(node) && (String(node.getAttribute('data-res-action') || '') === 'play' || String(node.className || '').indexOf('ply') >= 0)) return node;
        }
        for (var a = 0; a < nodes.length; a++) {
          if (nodes[a].closest && nodes[a].closest('#g_player,.m-playbar,.g-btmbar,.listbd,.listlyric')) continue;
          var href = nodes[a].getAttribute('href') || nodes[a].href || '';
          if (href.indexOf('song?id=' + songId) < 0) continue;
          var row = nodes[a].closest('tr,li,.item,.itm,.f-cb,.j-tr') || nodes[a].parentElement;
          if (!row) continue;
          var button = row.querySelector('[data-res-id="' + escaped + '"][data-res-action="play"],[data-res-action="play"],.ply,.u-btni-addply,.u-btni-play,.u-icn-81');
          if (button) return button;
        }
        return null;
      }
      var selectors = [
        'span.ply[data-res-id="' + escaped + '"][data-res-action="play"][data-res-type="18"]',
        'span.ply[data-res-id="' + escaped + '"][data-res-action="play"]',
        'span[data-res-id="' + escaped + '"][data-res-action="play"]',
        'a[data-res-id="' + escaped + '"][data-res-action="play"]',
        'button[data-res-id="' + escaped + '"][data-res-action="play"]',
        '[data-res-id="' + escaped + '"][data-res-action="play"]',
        '[data-res-id="' + escaped + '"].ply',
        'tr[id="' + escaped + '"] [data-res-action="play"]',
        'tr[id="' + escaped + '"] .ply',
        'tr[id="\\$' + escaped + '"] [data-res-action="play"]',
        'tr[id="\\$' + escaped + '"] .ply'
      ];
      var docs = documents();
      for (var d = 0; d < docs.length; d++) {
        if (domId) {
          var owner = docs[d].querySelector('[data-emoc-id="' + domId.replace(/"/g, '') + '"]');
          var ownerButton = playCandidateIn(owner) || (owner ? owner.querySelector('[data-res-id="' + escaped + '"][data-res-action="play"],[data-res-action="play"],.ply') : null);
          if (ownerButton && click(ownerButton)) return true;
        }
        var directCandidate = playCandidateIn(docs[d]);
        if (directCandidate && click(directCandidate)) return true;
        for (var s = 0; s < selectors.length; s++) {
          var direct = docs[d].querySelector(selectors[s]);
          if (direct && click(direct)) return true;
        }
        var links = Array.prototype.slice.call(docs[d].querySelectorAll('a[href*="song?id=' + escaped + '"]'));
        for (var l = 0; l < links.length; l++) {
          var row = links[l].closest('tr,li,.item,.itm,.f-cb') || links[l].parentElement;
          var button = row ? row.querySelector('[data-res-action="play"],.ply,.u-btni-addply,.u-btni-play,.u-icn-81') : null;
          if (button && click(button)) return true;
        }
      }
      return false;
    }
    function officialBarTitle() {
      var bar = document.querySelector('#g_player,.m-playbar,.g-btmbar');
      var link = bar ? bar.querySelector('.words .name a,.words a[href*="/song?id="],a[href*="/song?id="]') : null;
      return link ? (link.textContent || link.getAttribute('title') || '').replace(/\s+/g, ' ').trim() : '';
    }
    function waitForOfficialBar(onTimeout) {
      var count = 0;
      var timer = setInterval(function () {
        count += 1;
        if (officialBarTitle()) {
          clearInterval(timer);
          return;
        }
        if (count > 10) {
          clearInterval(timer);
          if (onTimeout) onTimeout();
        }
      }, 500);
    }
    if (tryClickPlay()) {
      EmoCMirror.postMessage(JSON.stringify({ type: 'playClick', title: songTitle, songId: songId }));
      setTimeout(function () {
        if (!officialBarTitle()) postPlayError('已模拟点击官网播放按钮，但官网播放条未返回歌曲');
      }, 1200);
      return true;
    }
    postPlayError('未找到官网播放链接，请先刷新当前列表');
    return false;
  })();
''';

// ignore: unused_element
const _songUrlScript = r'''
  (function () {
    var payload = window.__EMOC_SONG_URL__ || {};
    var songId = String(payload.id || '').trim();
    function postDirect(data) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({
        type: 'songUrl',
        requestId: payload.requestId || 0,
        songId: songId,
        title: payload.title || '',
        artist: payload.artist || '',
        coverUrl: payload.coverUrl || '',
        directApi: true
      }, data || {})));
    }
    function firstPlayableDirect(data) {
      var list = data && (data.data || data.urls || data.songs || []);
      if (!Array.isArray(list)) list = [list];
      for (var i = 0; i < list.length; i++) {
        var item = list[i] || {};
        var url = item.url || item.playUrl || item.src || '';
        if (!url) continue;
        if (url.indexOf('//') === 0) url = location.protocol + url;
        return {
          url: url,
          br: item.br || item.bitrate || 0,
          level: item.level || item.type || '',
          message: ''
        };
      }
      return null;
    }
    function requestDirect(endpoint) {
      return fetch(endpoint, {
        credentials: 'include',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://music.163.com/'
        }
      }).then(function (response) {
        return response.json();
      }).then(firstPlayableDirect).catch(function () {
        return null;
      });
    }
    if (!songId) {
      postDirect({ message: 'EMPTY_SONG_ID' });
      return;
    }
    var encodedIdsDirect = encodeURIComponent(JSON.stringify([Number(songId)]));
    var requestedQualityDirect = String(payload.quality || 'higher');
    var qualityOrderDirect = {
      standard: ['standard'],
      higher: ['higher', 'standard'],
      exhigh: ['exhigh', 'higher', 'standard'],
      lossless: ['lossless', 'exhigh', 'higher', 'standard']
    }[requestedQualityDirect] || ['higher', 'standard'];
    var endpointsDirect = [];
    for (var qd = 0; qd < qualityOrderDirect.length; qd++) {
      endpointsDirect.push('/api/song/enhance/player/url/v1?ids=' + encodedIdsDirect + '&level=' + qualityOrderDirect[qd] + '&encodeType=mp3&timestamp=' + Date.now());
      endpointsDirect.push('/api/song/enhance/player/url/v1?ids=' + encodedIdsDirect + '&level=' + qualityOrderDirect[qd] + '&encodeType=aac&timestamp=' + Date.now());
    }
    endpointsDirect.push('/api/song/enhance/player/url?ids=' + encodedIdsDirect + '&br=320000&timestamp=' + Date.now());
    endpointsDirect.push('/api/song/enhance/player/url?ids=' + encodedIdsDirect + '&br=128000&timestamp=' + Date.now());
    endpointsDirect.reduce(function (chain, endpoint) {
      return chain.then(function (found) {
        return found || requestDirect(endpoint);
      });
    }, Promise.resolve(null)).then(function (found) {
      if (found && found.url) {
        postDirect(found);
        return;
      }
      postDirect({ message: 'NO_PLAYABLE_URL' });
    }).catch(function (error) {
      postDirect({ message: 'SONG_URL_API_ERROR: ' + error });
    });
    return;
    function post(data) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({
        type: 'songUrl',
        requestId: payload.requestId || 0,
        songId: songId,
        title: payload.title || '',
        artist: payload.artist || '',
        coverUrl: payload.coverUrl || ''
      }, data || {})));
    }
    function clean(value) {
      return String(value || '').replace(/\s+/g, ' ').trim();
    }
    function documents() {
      var docs = [document];
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentDocument) docs.push(frame.contentDocument);
      } catch (e) {}
      return docs;
    }
    function isCurrentUserVip() {
      try {
        if (window.GUser && Number(GUser.vipType || GUser.redVipLevel || 0) > 0) return true;
        var nodes = Array.prototype.slice.call(document.querySelectorAll('.m-tophead,.head,.user,.m-user'));
        return nodes.some(function (node) {
          var value = clean(node.textContent + ' ' + node.className);
          return /黑胶VIP|SVIP|VIP会员|vip[_-]?on|svip/.test(value) && !/开通|续费|尊享/.test(value);
        });
      } catch (e) {
        return false;
      }
    }
    function domShowsVipBlocked() {
      if (!songId) return false;
      var docs = documents();
      var selectors = [
        '[data-res-id="' + songId + '"]',
        'tr[id="' + songId + '"]',
        'tr[id="\\$' + songId + '"]',
        'a[href*="song?id=' + songId + '"]'
      ];
      for (var d = 0; d < docs.length; d++) {
        var doc = docs[d];
        var bodyText = clean(doc.body ? doc.body.textContent : '');
        var pageMatchesSong = false;
        try {
          pageMatchesSong = String(doc.location ? doc.location.href : location.href).indexOf('song?id=' + songId) >= 0 ||
            String(location.href || '').indexOf('song?id=' + songId) >= 0;
        } catch (e) {}
        if (pageMatchesSong && bodyText.indexOf('VIP尊享') >= 0 && (!payload.title || bodyText.indexOf(String(payload.title || '')) >= 0)) {
          return true;
        }
        var vipButtons = Array.prototype.slice.call(doc.querySelectorAll('a,button,span,div'));
        for (var b = 0; b < vipButtons.length; b++) {
          var buttonText = clean(vipButtons[b].textContent || vipButtons[b].getAttribute('title') || vipButtons[b].getAttribute('aria-label') || '');
          if (buttonText.indexOf('VIP尊享') < 0) continue;
          var rowRegion = vipButtons[b].closest('tr,li,.item,.itm,.j-tr,.f-cb');
          var rowHasSong = false;
          try {
            rowHasSong = !!(rowRegion && rowRegion.querySelector('[data-res-id="' + songId + '"],a[href*="song?id=' + songId + '"]'));
          } catch (e) {}
          if (rowHasSong) return true;
          if (!pageMatchesSong) continue;
          var detailRegion = vipButtons[b].closest('.cnt,.m-lycifo,.g-wrap') || vipButtons[b].parentElement;
          var detailText = clean(detailRegion ? detailRegion.textContent : '');
          if (!payload.title || detailText.indexOf(String(payload.title || '')) >= 0) return true;
        }
        for (var s = 0; s < selectors.length; s++) {
          var nodes = Array.prototype.slice.call(doc.querySelectorAll(selectors[s]));
          for (var n = 0; n < nodes.length; n++) {
            var row = nodes[n].closest('tr,li,.item,.itm,.f-cb,.j-tr,.cnt,.m-lycifo') || nodes[n].parentElement;
            var text = clean((row ? row.textContent : '') + ' ' + (row ? row.className : '') + ' ' + nodes[n].className);
            if (/VIP尊享/.test(text)) return true;
          }
        }
      }
      return false;
    }
    function vipBlockedMessage() {
      return 'VIP歌曲，需会员播放';
    }
    function responseLooksVipBlocked(data) {
      var list = data && (data.data || data.urls || data.songs || []);
      if (!Array.isArray(list)) list = [list];
      for (var i = 0; i < list.length; i++) {
        var item = list[i] || {};
        var code = Number(item.code || data.code || 0);
        var fee = Number(item.fee || item.feeType || 0);
        var flag = clean(
          JSON.stringify({
            code: item.code || data.code,
            fee: item.fee || item.feeType,
            level: item.level,
            freeTrialInfo: item.freeTrialInfo,
            message: item.message || item.msg || data.message || data.msg
          })
        );
        if (!item.url && (fee === 1 || fee === 4) && /VIP|vip|会员|付费|尊享/.test(flag)) {
          return true;
        }
        if (!item.url && code === 403 && /VIP|vip|会员|付费|尊享/.test(flag)) {
          return true;
        }
      }
      return false;
    }
    var vipSignal = false;
    function privilegeLooksVipBlocked(data) {
      var songs = data && (data.songs || (data.data && data.data.songs) || []);
      var privileges = data && (data.privileges || (data.data && data.data.privileges) || []);
      var song = Array.isArray(songs) ? (songs[0] || {}) : (songs || {});
      var privilege = Array.isArray(privileges) ? (privileges[0] || {}) : (privileges || {});
      var fee = Number(privilege.fee || song.fee || 0);
      var pl = Number(privilege.pl || privilege.playMaxbr || 0);
      var st = privilege.st == null ? 0 : Number(privilege.st);
      var toast = clean(privilege.toast || privilege.toastContent || privilege.message || '');
      var chargeInfoList = privilege.chargeInfoList || [];
      var hasVipCharge = Array.isArray(chargeInfoList) && chargeInfoList.some(function (item) {
        return Number((item || {}).chargeType || 0) === 1 || Number((item || {}).chargeType || 0) === 4;
      });
      if ((fee === 1 || fee === 4 || hasVipCharge) && (st < 0 || (pl <= 0 && /VIP|会员|付费|尊享/.test(toast)))) {
        return true;
      }
      return false;
    }
    function requestPrivilege() {
      return fetch('/api/song/detail?ids=' + encodeURIComponent('[' + songId + ']') + '&timestamp=' + Date.now(), {
        credentials: 'include',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://music.163.com/'
        }
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (privilegeLooksVipBlocked(data)) vipSignal = true;
        return vipSignal;
      }).catch(function () {
        return false;
      });
    }
    function firstPlayable(data) {
      var list = data.data || data.urls || data.songs || [];
      if (!Array.isArray(list)) list = [list];
      for (var i = 0; i < list.length; i++) {
        var item = list[i] || {};
        var url = item.url || item.playUrl || item.src || '';
        if (url) {
          if (url.indexOf('//') === 0) url = location.protocol + url;
          return {
            url: url,
            br: item.br || item.bitrate || 0,
            level: item.level || item.type || '',
            message: ''
          };
        }
      }
      return null;
    }
    function request(url) {
      return fetch(url, {
        credentials: 'include',
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://music.163.com/'
        }
      }).then(function (response) {
        return response.json();
      }).then(function (data) {
        if (responseLooksVipBlocked(data)) vipSignal = true;
        var playable = firstPlayable(data);
        return playable || null;
      }).catch(function () {
        return null;
      });
    }
    if (!songId) {
      post({ message: '歌曲 ID 为空，无法请求播放地址' });
      return;
    }
    var userIsVip = isCurrentUserVip();
    var encodedIds = encodeURIComponent(JSON.stringify([Number(songId)]));
    var requestedQuality = String(payload.quality || 'higher');
    var qualityOrder = {
      standard: ['standard', 'higher'],
      higher: ['higher', 'standard'],
      exhigh: ['exhigh', 'higher', 'standard'],
      lossless: ['lossless', 'exhigh', 'higher', 'standard']
    }[requestedQuality] || ['higher', 'standard'];
    var endpoints = [];
    for (var q = 0; q < qualityOrder.length; q++) {
      endpoints.push('/api/song/enhance/player/url/v1?ids=' + encodedIds + '&level=' + qualityOrder[q] + '&encodeType=mp3&timestamp=' + Date.now());
    }
    if (requestedQuality === 'standard') {
      endpoints.push('/api/song/enhance/player/url?ids=' + encodedIds + '&br=128000&timestamp=' + Date.now());
    }
    endpoints.push('/api/song/enhance/player/url?ids=' + encodedIds + '&br=320000&timestamp=' + Date.now());
    endpoints.push('/api/song/enhance/player/url/v1?ids=' + encodedIds + '&level=standard&encodeType=aac&timestamp=' + Date.now());
    endpoints.reduce(function (chain, endpoint) {
      return chain.then(function (found) {
        return found || request(endpoint);
      });
    }, Promise.resolve(null)).then(function (found) {
      if (found && found.url) {
        post(found);
        return;
      }
      if (!userIsVip && (vipSignal || domShowsVipBlocked())) {
        post({ vipBlocked: true, message: vipBlockedMessage() });
        return;
      }
      post({ message: '官网接口没有返回可播放地址，可能是版权或地区限制' });
    }).catch(function (error) {
      post({ message: '请求播放地址失败：' + error });
    });
  })();
''';

const _songDetailSnapshotScript = r'''
  (function () {
    var payload = window.__EMOC_SONG_DETAIL__ || {};
    function post(data) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({ type: 'songDetail' }, data)));
    }
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function idFrom(value) {
      var match = String(value || '').match(/[?&]id=(\d+)/);
      return match ? match[1] : '';
    }
    var id = String(payload.id || idFrom(payload.href) || idFrom(location.href) || '').trim();
    if (!id) {
      post({
        title: payload.title || '',
        artist: payload.artist || '',
        coverUrl: payload.coverUrl || '',
        lyric: '',
        translatedLyric: ''
      });
      return;
    }
    // Do not navigate to the song page here. Navigation can reset the current
    // hidden website context and may create a second website audio instance.
    var detailUrl = '/api/song/detail?ids=' + encodeURIComponent('[' + id + ']') + '&timestamp=' + Date.now();
    var lyricUrl = '/api/song/lyric?id=' + encodeURIComponent(id) + '&lv=-1&kv=-1&tv=-1&timestamp=' + Date.now();
    Promise.all([
      fetch(detailUrl, { credentials: 'include' }).then(function (response) { return response.json(); }).catch(function () { return {}; }),
      fetch(lyricUrl, { credentials: 'include' }).then(function (response) { return response.json(); }).catch(function () { return {}; })
    ]).then(function (all) {
      var song = ((all[0].songs || all[0].data || [])[0]) || {};
      var album = song.al || song.album || {};
      var artists = song.ar || song.artists || [];
      var artistText = artists.map(function (item) { return clean(item.name); }).filter(Boolean).join(' / ');
      var lyric = (all[1].lrc && all[1].lrc.lyric) || (all[1].lyricUser && all[1].lyricUser.lyric) || '';
      var translatedLyric = (all[1].tlyric && all[1].tlyric.lyric) || '';
      post({
        songId: id,
        title: clean(song.name) || payload.title || '',
        artist: artistText || payload.artist || '',
        album: clean(album.name),
        coverUrl: album.picUrl || payload.coverUrl || '',
        lyric: lyric,
        translatedLyric: translatedLyric
      });
    }).catch(function (error) {
      post({
        songId: id,
        title: payload.title || '',
        artist: payload.artist || '',
        coverUrl: payload.coverUrl || '',
        lyric: '',
        translatedLyric: '',
        message: String(error)
      });
    });
  })();
''';

const _playerSnapshotScript = r'''
  (function () {
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function seconds(text) {
      var match = String(text || '').match(/(\d+):(\d+)/);
      if (!match) return 0;
      return parseInt(match[1], 10) * 60 + parseInt(match[2], 10);
    }
    function pick(root, selector) { return root ? root.querySelector(selector) : null; }
    function post(payload) {
      EmoCMirror.postMessage(JSON.stringify(Object.assign({ type: 'player' }, payload)));
    }
    function allMedia() {
      var list = Array.prototype.slice.call(document.querySelectorAll('audio,video'));
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentDocument) {
          list = list.concat(Array.prototype.slice.call(frame.contentDocument.querySelectorAll('audio,video')));
        }
      } catch (e) {}
      return list;
    }
    function bestAudio() {
      var saved = window.__EMOC_AUDIO__;
      if (saved && saved.src && !saved.paused) return saved;
      var all = allMedia();
      for (var i = 0; i < all.length; i++) if (all[i].src && !all[i].paused) return all[i];
      for (var j = 0; j < all.length; j++) if (all[j].src) return all[j];
      return null;
    }
    function tuneAudio(media) {
      return media;
    }
    function stopDuplicateAudio(primary) {
      return primary;
    }
    var bar = document.querySelector('#g_player,.m-playbar,.g-btmbar');
    if (!bar) {
      var fallbackAudio = bestAudio();
      tuneAudio(fallbackAudio);
      stopDuplicateAudio(fallbackAudio);
      post({
        visible: false,
        songId: '',
        title: '',
        artist: '',
        source: '',
        coverUrl: '',
        playing: fallbackAudio ? (!fallbackAudio.paused && !fallbackAudio.ended) : false,
        currentSeconds: fallbackAudio ? Math.floor(fallbackAudio.currentTime || 0) : 0,
        durationSeconds: fallbackAudio ? Math.floor(fallbackAudio.duration || 0) : 0,
        volume: fallbackAudio ? Number(fallbackAudio.volume || 0.7) : 0.7,
        mode: window.__EMOC_MODE__ || 'loop'
      });
      return;
    }
    var titleLink = pick(bar, '.words .name a,.words .fc1[href*="/song?id="],.words a[href*="/song?id="],.f-thide.name a,a[href*="/song?id="]');
    var artistLink = pick(bar, '.words .by a,.words .by .fc1,.by a,.artist a');
    var sourceLink = pick(bar, '.words a[href*="/playlist?id="],.src a,.icn-src');
    var cover = pick(bar, '.head img,.cover img,img');
    var playButton = pick(bar, '.btns .ply,.ply,.pas,[data-action="pause"],[data-action="play"]');
    var timeText = clean((pick(bar, '.time') || {}).textContent || '');
    var times = timeText.match(/\d+:\d+/g) || [];
    var audio = bestAudio();
    tuneAudio(audio);
    stopDuplicateAudio(audio);
    var audioCurrent = audio ? Math.floor(audio.currentTime || 0) : 0;
    var audioDuration = audio ? Math.floor(audio.duration || 0) : 0;
    var current = audioCurrent > 0 ? audioCurrent : (times.length > 0 ? seconds(times[0]) : 0);
    var duration = audioDuration > 0 ? audioDuration : (times.length > 1 ? seconds(times[1]) : 0);
    var seekActive = Number(window.__EMOC_SEEKING_UNTIL__ || 0) > Date.now();
    var seekTarget = Number(window.__EMOC_SEEK_TARGET__ || 0);
    if (seekActive && seekTarget > 0 && current < seekTarget - 1) current = seekTarget;
    var modeEl = pick(bar, '.icn-loop,.icn-shuffle,.icn-one,[data-action="mode"]');
    var modeClass = modeEl ? String(modeEl.className || '') : '';
    var modeTitle = clean(modeEl ? (modeEl.title || modeEl.textContent) : '');
    var mode = 'loop';
    if (modeClass.indexOf('shuffle') >= 0 || modeTitle.indexOf('随机') >= 0) {
      mode = 'shuffle';
    } else if (modeClass.indexOf('one') >= 0 || modeTitle.indexOf('单曲') >= 0) {
      mode = 'one';
    } else if (modeClass.indexOf('loop') >= 0 || modeTitle.indexOf('循环') >= 0) {
      mode = 'loop';
    } else {
      mode = window.__EMOC_MODE__ || 'loop';
    }
    window.__EMOC_MODE__ = mode;
    var href = titleLink ? (titleLink.getAttribute('href') || titleLink.href || '') : '';
    var idMatch = href.match(/[?&]id=(\d+)/);
    var title = clean(titleLink ? (titleLink.getAttribute('title') || titleLink.textContent) : '');
    if (!title) {
      var titleBox = pick(bar, '.words .name,.f-thide.name');
      title = clean(titleBox ? titleBox.textContent : '');
    }
    var artist = clean(artistLink ? (artistLink.getAttribute('title') || artistLink.textContent) : '');
    var coverUrl = abs(cover ? (cover.getAttribute('data-src') || cover.getAttribute('src')) : '');
    var playingClass = playButton ? String(playButton.className || '') : '';
    var playingTitle = clean(playButton ? (playButton.title || playButton.getAttribute('aria-label') || '') : '');
    var playingAction = playButton ? String(playButton.getAttribute('data-action') || '') : '';
    var hasButtonState = playingAction === 'play' || playingAction === 'pause' || playingClass.indexOf('pas') >= 0;
    var buttonPlaying = playingAction === 'pause' || playingClass.indexOf('pas') >= 0 || playingTitle.indexOf('暂停') >= 0;
    var audioPlaying = audio ? (!audio.paused && !audio.ended) : false;
    var effectivePlaying = hasButtonState ? buttonPlaying : audioPlaying;
    post({
      visible: !!title || !!cover,
      songId: idMatch ? idMatch[1] : '',
      title: title,
      artist: artist,
      source: clean(sourceLink ? (sourceLink.getAttribute('title') || sourceLink.textContent) : ''),
      coverUrl: coverUrl,
      playing: effectivePlaying,
      currentSeconds: current,
      durationSeconds: duration,
      volume: audio ? Number(audio.volume || 0.7) : 0.7,
      mode: mode
    });
  })();
''';

const _queueSnapshotScript = r'''
  (function () {
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function click(el) {
      if (!el) return false;
      try { el.scrollIntoView({ block: 'nearest', inline: 'center' }); } catch (e) {}
      try {
        var rect = el.getBoundingClientRect();
        var x = rect && rect.width ? rect.left + rect.width / 2 : 0;
        var y = rect && rect.height ? rect.top + rect.height / 2 : 0;
        ['pointerover', 'mouseover', 'pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function (type) {
          var EventCtor = type.indexOf('pointer') === 0 && typeof PointerEvent !== 'undefined' ? PointerEvent : MouseEvent;
          el.dispatchEvent(new EventCtor(type, {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
            screenX: x,
            screenY: y,
            button: 0,
            buttons: (type === 'mousedown' || type === 'pointerdown') ? 1 : 0
          }));
        });
        return true;
      } catch (e) {
        try { el.click(); return true; } catch (_) {}
      }
      return false;
    }
    function post(items, lyric) {
      EmoCMirror.postMessage(JSON.stringify({
        type: 'queue',
        items: items || [],
        lyric: lyric || ''
      }));
    }
    var bar = document.querySelector('#g_player,.m-playbar,.g-btmbar');
    var listButton = bar && bar.querySelector('.listhdc,.list,.icn-list,.add,.oper [class*="list"]');
    click(listButton);
    setTimeout(function () {
      var items = [];
      var seen = {};
      var rows = Array.prototype.slice.call(document.querySelectorAll('.m-playbar .listbd li,.m-playbar .list li,.listbd li'));
      for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var titleEl = row.querySelector('.col-2 a,.col-2,.song a,a[href*="/song?id="]');
        var artistEl = row.querySelector('.col-4 a,.col-4,.by a');
        var timeEl = row.querySelector('.col-5,.time');
        var hrefEl = row.querySelector('a[href*="/song?id="]');
        var title = clean(titleEl ? (titleEl.getAttribute('title') || titleEl.textContent) : '');
        if (!title) continue;
        var href = abs(hrefEl ? (hrefEl.getAttribute('href') || hrefEl.href || '') : '');
        var key = title + '|' + href;
        if (seen[key]) continue;
        seen[key] = true;
        items.push({
          domId: 'queue_' + i,
          kind: 'song',
          title: title,
          subtitle: [clean(artistEl ? (artistEl.getAttribute('title') || artistEl.textContent) : ''), clean(timeEl ? timeEl.textContent : '')].filter(Boolean).join(' · '),
          imageUrl: '',
          href: href
        });
      }
      var lyricLines = Array.prototype.slice.call(document.querySelectorAll('.m-playbar .listlyric p,.listlyric p,.listlyric .j-flag'));
      var lyric = lyricLines.map(function (el) { return clean(el.textContent); }).filter(Boolean).join('\n');
      post(items, lyric);
    }, 450);
  })();
''';

String _playerControlScript(String action, {double? value}) {
  final encodedAction = jsonEncode(action);
  final encodedValue = value == null
      ? 'null'
      : value.clamp(0, 1).toStringAsFixed(3);
  return '''
  (function () {
    var action = $encodedAction;
    var value = $encodedValue;
    function click(el) {
      if (!el) return false;
      try { el.scrollIntoView({ block: 'nearest', inline: 'center' }); } catch (e) {}
      try {
        var rect = el.getBoundingClientRect();
        var x = rect && rect.width ? rect.left + rect.width / 2 : 0;
        var y = rect && rect.height ? rect.top + rect.height / 2 : 0;
        ['pointerover', 'mouseover', 'pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(function (type) {
          var EventCtor = type.indexOf('pointer') === 0 && typeof PointerEvent !== 'undefined' ? PointerEvent : MouseEvent;
          el.dispatchEvent(new EventCtor(type, {
            bubbles: true,
            cancelable: true,
            view: window,
            clientX: x,
            clientY: y,
            screenX: x,
            screenY: y,
            button: 0,
            buttons: (type === 'mousedown' || type === 'pointerdown') ? 1 : 0
          }));
        });
      } catch (e) {
        try { el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window, button: 0 })); } catch (_) {}
      }
      try { el.click(); } catch (_) {}
      return true;
    }
    function pick(selector) {
      var bar = document.querySelector('#g_player,.m-playbar,.g-btmbar') || document;
      return bar.querySelector(selector) || document.querySelector(selector);
    }
    function allMedia() {
      var list = Array.prototype.slice.call(document.querySelectorAll('audio,video'));
      try {
        var frame = document.querySelector('#g_iframe');
        if (frame && frame.contentDocument) {
          list = list.concat(Array.prototype.slice.call(frame.contentDocument.querySelectorAll('audio,video')));
        }
      } catch (e) {}
      return list;
    }
    function bestAudio() {
      var saved = window.__EMOC_AUDIO__;
      if (saved && saved.src && !saved.paused) return saved;
      var all = allMedia();
      for (var a = 0; a < all.length; a++) if (all[a].src && !all[a].paused) return all[a];
      if (saved && saved.src) return saved;
      for (var b = 0; b < all.length; b++) if (all[b].src) return all[b];
      return null;
    }
    function fireMouse(target, type, x, y, buttons) {
      if (!target) return false;
      try {
        target.dispatchEvent(new MouseEvent(type, {
          bubbles: true,
          cancelable: true,
          view: window,
          clientX: x,
          clientY: y,
          screenX: x,
          screenY: y,
          button: 0,
          buttons: buttons
        }));
        return true;
      } catch (e) {
        return false;
      }
    }
    function playButton() {
      var bar = document.querySelector('#g_player,.m-playbar,.g-btmbar');
      return bar ? bar.querySelector('.btns .ply.j-flag,.btns .pas,.btns .ply,.ply.j-flag,.pas,.ply,[data-action="pause"],[data-action="play"]') : null;
    }
    function isWebsitePlaying() {
      var button = playButton();
      if (button) {
        var action = String(button.getAttribute('data-action') || '');
        var cls = String(button.className || '');
        if (action === 'pause' || cls.indexOf('pas') >= 0) return true;
        if (action === 'play') return false;
      }
      var audio = bestAudio();
      return audio ? (!audio.paused && !audio.ended) : false;
    }
    function applyPlaybackTuning() {
      return true;
    }
    function sweepSoon() {
      return true;
    }
    function afterTrackStep() {
      window.__EMOC_AUDIO__ = null;
    }
    function setVolumeOnWebsite(volume) {
      window.__EMOC_DESIRED_VOLUME__ = Math.max(0, Math.min(1, volume));
      var audioNodes = allMedia();
      for (var i = 0; i < audioNodes.length; i++) {
        try { audioNodes[i].volume = window.__EMOC_DESIRED_VOLUME__; } catch (e) {}
      }
      var slider = pick('.m-vol .vbg,.m-vol .barbg,.vbg.j-flag,.vbg');
      if (!slider) {
        var volumeIcon = pick('.icn-vol,.icn-volume,[data-action="volume"]');
        if (volumeIcon) click(volumeIcon);
        slider = pick('.m-vol .vbg,.m-vol .barbg,.vbg.j-flag,.vbg');
      }
      if (slider) {
        var rect = slider.getBoundingClientRect();
        if (rect && rect.height > 0) {
          var x = rect.left + Math.max(2, rect.width / 2);
          var y = rect.bottom - rect.height * window.__EMOC_DESIRED_VOLUME__;
          var knob = pick('.m-vol .btn,.vbg .btn') || slider;
          fireMouse(knob, 'mousedown', x, y, 1);
          fireMouse(document, 'mousemove', x, y, 1);
          fireMouse(slider, 'mousemove', x, y, 1);
          fireMouse(document, 'mouseup', x, y, 0);
          fireMouse(slider, 'click', x, y, 0);
        }
      }
      var curr = pick('.m-vol .curr,.vbg .curr');
      var knobEl = pick('.m-vol .btn,.vbg .btn');
      if (curr) curr.style.height = Math.round(window.__EMOC_DESIRED_VOLUME__ * 100) + '%';
      if (knobEl) knobEl.style.bottom = Math.round(window.__EMOC_DESIRED_VOLUME__ * 100) + '%';
      try { localStorage.setItem('volume', String(window.__EMOC_DESIRED_VOLUME__)); } catch (e) {}
    }
    function detectMode() {
      var el = pick('.icn-loop.j-flag,.icn-shuffle.j-flag,.icn-one.j-flag,.icn-loop,.icn-shuffle,.icn-one,[data-action="mode"]');
      var cls = el ? String(el.className || '') : '';
      var title = el ? String(el.title || el.textContent || '') : '';
      if (cls.indexOf('shuffle') >= 0 || title.indexOf('随机') >= 0) return 'shuffle';
      if (cls.indexOf('one') >= 0 || title.indexOf('单曲') >= 0) return 'one';
      if (cls.indexOf('loop') >= 0 || title.indexOf('循环') >= 0) return 'loop';
      return window.__EMOC_MODE__ || 'loop';
    }
    if (action === 'previous') {
      click(pick('.prv,.btns .prv,[data-action="prev"]'));
      afterTrackStep();
    }
    if (action === 'toggle') {
      var button = playButton();
      click(button);
    }
    if (action === 'next') {
      click(pick('.nxt,.btns .nxt,[data-action="next"]'));
      afterTrackStep();
    }
    if (action === 'mode') {
      if (Number(window.__EMOC_MODE_BUSY_UNTIL__ || 0) > Date.now()) return true;
      window.__EMOC_MODE_BUSY_UNTIL__ = Date.now() + 650;
      var current = detectMode();
      var fallbackNext = current === 'loop' ? 'shuffle' : current === 'shuffle' ? 'one' : 'loop';
      var clickedMode = click(pick('.icn-loop.j-flag,.icn-shuffle.j-flag,.icn-one.j-flag,.icn-loop,.icn-shuffle,.icn-one,[data-action="mode"]'));
      setTimeout(function () {
        window.__EMOC_MODE__ = clickedMode ? detectMode() : fallbackNext;
      }, 180);
    }
    if (action === 'queue') click(pick('.listhdc,.list,.icn-list,[class*="list"]'));
    if (action === 'volume' && value !== null) {
      setVolumeOnWebsite(value);
      setTimeout(function () { setVolumeOnWebsite(value); }, 120);
      setTimeout(function () { setVolumeOnWebsite(value); }, 360);
    }
  })();
  ''';
}

const _snapshotScript = r'''
  (function () {
    var context = window.__EMOC_CONTEXT__ || 'page';
    var requestId = Number(window.__EMOC_SNAPSHOT_REQUEST_ID__ || 0);
    function roots() {
      var list = [document];
      var frame = document.querySelector('#g_iframe');
      try { if (frame && frame.contentDocument) list.push(frame.contentDocument); } catch (e) {}
      return list;
    }
    function clean(value) { return (value || '').replace(/\s+/g, ' ').trim(); }
    function abs(url) {
      if (!url) return '';
      if (url.indexOf('//') === 0) return location.protocol + url;
      if (url.indexOf('/') === 0) return 'https://music.163.com' + url;
      return url;
    }
    function ensureId(el, prefix, index) {
      if (!el.getAttribute('data-emoc-id')) el.setAttribute('data-emoc-id', prefix + '_' + index + '_' + Date.now());
      return el.getAttribute('data-emoc-id');
    }
    function songFromAnchor(anchor, index) {
      var href = abs(anchor.getAttribute('href') || anchor.href || '');
      var block = anchor.closest('tr,li,.item,.itm,.f-cb,.srchsongst .item') || anchor;
      var title = clean(anchor.getAttribute('title')) || clean(anchor.textContent);
      title = title.replace(/^播放\s*/, '').replace(/\s+-\s+MV$/, '');
      if (!title || href.indexOf('/song?id=') < 0) return null;
      var texts = Array.prototype.slice.call(block.querySelectorAll('td,a,span,.text,.s-fc3,.s-fc4'))
        .map(function (el) { return clean(el.textContent || el.getAttribute('title')); })
        .filter(function (v) { return v && v !== title && v.length < 80; });
      var img = block.querySelector('img');
      return {
        domId: ensureId(block, 'song', index),
        kind: 'song',
        title: title,
        subtitle: texts.slice(0, 2).join(' · '),
        imageUrl: abs(img ? (img.getAttribute('data-src') || img.getAttribute('src')) : ''),
        href: href
      };
    }
    function playlistFromAnchor(anchor, index) {
      var href = abs(anchor.getAttribute('href') || anchor.href || '');
      if (href.indexOf('/my/m/music/playlist?id=') < 0 && href.indexOf('/playlist?id=') < 0) return null;
      var block = anchor.closest('li,.item,.f-cb,.j-iflag') || anchor;
      var title = clean(anchor.getAttribute('title')) || clean(anchor.textContent) || clean(block.textContent);
      title = title.replace(/\s+\d+首.*$/, '');
      if (!title || title.length > 80) return null;
      var img = block.querySelector('img');
      var subtitle = clean(block.textContent).replace(title, '').slice(0, 40);
      return {
        domId: ensureId(block, 'playlist', index),
        kind: title.indexOf('我喜欢的音乐') >= 0 ? 'liked' : 'playlist',
        title: title,
        subtitle: subtitle,
        imageUrl: abs(img ? (img.getAttribute('data-src') || img.getAttribute('src')) : ''),
        href: href
      };
    }
    var allRoots = roots();
    var items = [];
    var seen = {};
    for (var r = 0; r < allRoots.length; r++) {
      var root = allRoots[r];
      var anchors;
      if (context === 'library') {
        anchors = Array.prototype.slice.call(root.querySelectorAll('a[href*="/my/m/music/playlist?id="],a[href*="/playlist?id="]'));
      } else {
        anchors = Array.prototype.slice.call(root.querySelectorAll('a[href*="/song?id="]'));
      }
      for (var i = 0; i < anchors.length; i++) {
        var item = context === 'library' ? playlistFromAnchor(anchors[i], i) : songFromAnchor(anchors[i], i);
        if (!item || !item.title) continue;
        var key = item.kind + '|' + item.href + '|' + item.title;
        if (seen[key]) continue;
        seen[key] = true;
        items.push(item);
        if (items.length >= 120) break;
      }
      if (items.length >= 120) break;
    }
    EmoCMirror.postMessage(JSON.stringify({
      type: 'snapshot',
      context: context,
      requestId: requestId,
      url: location.href,
      items: items
    }));
  })();
''';
