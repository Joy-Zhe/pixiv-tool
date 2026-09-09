import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/models.dart';
import 'system_proxy_resolver.dart';

class PixivHttpException implements Exception {
  const PixivHttpException(
    this.statusCode,
    this.message, {
    this.uri,
    this.retryAfter,
  });

  final int statusCode;
  final String message;
  final Uri? uri;
  final Duration? retryAfter;

  DownloadErrorCode get errorCode => switch (statusCode) {
    401 => DownloadErrorCode.authExpired,
    403 => DownloadErrorCode.forbidden,
    404 => DownloadErrorCode.notFound,
    429 => DownloadErrorCode.rateLimited,
    _ => DownloadErrorCode.network,
  };

  @override
  String toString() => 'PixivHttpException($statusCode): $message';
}

class PixivHttpClient {
  PixivHttpClient({
    required ProxyConfig proxy,
    String proxyPassword = '',
    String cookie = '',
    HttpClient? client,
    this.systemProxy = const SystemProxySettings(),
  }) : _proxy = proxy,
       _proxyPassword = proxyPassword,
       _cookie = cookie,
       _client = client ?? HttpClient() {
    _configureProxy();
    _client.connectionTimeout = const Duration(seconds: 20);
    _client.idleTimeout = const Duration(seconds: 30);
    _client.maxConnectionsPerHost = 8;
  }

  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

  final ProxyConfig _proxy;
  final SystemProxySettings systemProxy;
  final String _proxyPassword;
  final HttpClient _client;
  final Random _random = Random();
  String _cookie;

  HttpClient get rawClient => _client;
  String get cookie => _cookie;

  set cookie(String value) => _cookie = value.trim();

  void _configureProxy() {
    _client.findProxy = switch (_proxy.mode) {
      ProxyMode.direct => (_) => 'DIRECT',
      ProxyMode.manual => (_) => 'PROXY ${_proxy.host}:${_proxy.port}',
      ProxyMode.system =>
        (uri) => _hasEnvironmentProxy
            ? HttpClient.findProxyFromEnvironment(uri)
            : systemProxy.findProxy(uri),
    };
    if (_proxy.mode == ProxyMode.manual && _proxy.username.isNotEmpty) {
      _client.authenticateProxy = (host, port, scheme, realm) async {
        _client.addProxyCredentials(
          host,
          port,
          realm ?? '',
          HttpClientBasicCredentials(_proxy.username, _proxyPassword),
        );
        return true;
      };
    }
  }

  bool get _hasEnvironmentProxy => const [
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'http_proxy',
    'https_proxy',
    'all_proxy',
  ].any((key) => Platform.environment[key]?.isNotEmpty ?? false);

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    bool requireAuth = true,
  }) async {
    final response = await open(
      'GET',
      uri,
      requireAuth: requireAuth,
      retry: true,
    );
    try {
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw PixivHttpException(
          response.statusCode,
          'Expected a JSON object',
          uri: uri,
        );
      }
      if (decoded['error'] == true) {
        throw PixivHttpException(
          response.statusCode,
          decoded['message']?.toString() ?? 'Pixiv rejected the request',
          uri: uri,
        );
      }
      return decoded;
    } on FormatException catch (error) {
      throw PixivHttpException(
        response.statusCode,
        'Invalid JSON: $error',
        uri: uri,
      );
    }
  }

  Future<HttpClientResponse> open(
    String method,
    Uri uri, {
    bool requireAuth = true,
    bool retry = false,
    Map<String, String> headers = const {},
  }) async {
    if (requireAuth && _cookie.isEmpty) {
      throw PixivHttpException(
        401,
        'Pixiv session is not configured',
        uri: uri,
      );
    }
    Object? lastError;
    final attempts = retry ? 5 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final request = await _client.openUrl(method, uri);
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        request.headers.set(
          HttpHeaders.refererHeader,
          'https://www.pixiv.net/',
        );
        request.headers.set('Origin', 'https://www.pixiv.net');
        request.headers.set(
          HttpHeaders.acceptLanguageHeader,
          'zh-CN,zh;q=0.9,en;q=0.8',
        );
        if (_cookie.isNotEmpty)
          request.headers.set(HttpHeaders.cookieHeader, _cookie);
        headers.forEach(request.headers.set);
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode >= 200 && response.statusCode < 300)
          return response;
        if (!_isRetryable(response.statusCode) || attempt == attempts - 1) {
          await response.drain<void>();
          throw PixivHttpException(
            response.statusCode,
            response.reasonPhrase,
            uri: uri,
            retryAfter: _retryAfter(
              response.headers.value(HttpHeaders.retryAfterHeader),
            ),
          );
        }
        final delay = _retryDelay(
          attempt,
          response.headers.value(HttpHeaders.retryAfterHeader),
        );
        await response.drain<void>();
        await Future<void>.delayed(delay);
      } on PixivHttpException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
        if (attempt == attempts - 1) break;
        await Future<void>.delayed(_retryDelay(attempt, null));
      }
    }
    throw PixivHttpException(0, 'Network request failed: $lastError', uri: uri);
  }

  bool _isRetryable(int code) => code == 408 || code == 429 || code >= 500;

  Duration _retryDelay(int attempt, String? retryAfter) {
    final serverDelay = _retryAfter(retryAfter);
    if (serverDelay != null) return serverDelay;
    final base = 1 << attempt.clamp(0, 3);
    return Duration(milliseconds: base * 1000 + _random.nextInt(350));
  }

  Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null ? null : Duration(seconds: seconds.clamp(1, 60));
  }

  void close() => _client.close(force: false);
}
