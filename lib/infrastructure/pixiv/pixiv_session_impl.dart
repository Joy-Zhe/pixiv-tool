import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../credentials/secure_credential_store.dart';
import '../network/pixiv_http_client.dart';
import 'pixiv_api_client.dart';

typedef WebLoginCookieProvider = Future<String?> Function();

class PixivSessionImpl implements PixivSession {
  PixivSessionImpl({
    required PixivHttpClient http,
    CredentialStore? credentials,
    WebLoginCookieProvider? webLogin,
  }) : _http = http,
       _credentials = credentials ?? SecureCredentialStore(),
       _webLogin = webLogin;

  final PixivHttpClient _http;
  final CredentialStore _credentials;
  WebLoginCookieProvider? _webLogin;
  AccountSession? _current;

  AccountSession? get current => _current;

  set webLoginProvider(WebLoginCookieProvider provider) => _webLogin = provider;

  @override
  Future<AccountSession> loginWithWebView() async {
    final cookie = await _webLogin?.call();
    if (cookie == null || cookie.trim().isEmpty) {
      throw StateError('Web login was cancelled or returned no Pixiv cookie');
    }
    return loginWithCookie(cookie);
  }

  @override
  Future<AccountSession> loginWithCookie(String rawCookie) async {
    final previous = _http.cookie;
    _http.cookie = rawCookie;
    try {
      final profile = await PixivApiClient(_http).getCurrentAccount();
      final session = AccountSession(
        profile: profile,
        cookie: rawCookie.trim(),
      );
      await _credentials.writeCookie(session.cookie);
      _current = session;
      return session;
    } on Object {
      _http.cookie = previous;
      rethrow;
    }
  }

  @override
  Future<AccountSession?> restore() async {
    if (_current != null) return _current;
    final cookie = await _credentials.readCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      return await loginWithCookie(cookie);
    } on Object {
      await _credentials.clearSession();
      _http.cookie = '';
      return null;
    }
  }

  @override
  Future<void> logout() async {
    _current = null;
    _http.cookie = '';
    await _credentials.clearSession();
  }
}
