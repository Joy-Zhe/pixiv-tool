import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts.dart';

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

  static const _cookieKey = 'pixiv.session.cookie';
  static const _proxyPasswordKey = 'network.proxy.password';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readCookie() => _storage.read(key: _cookieKey);

  @override
  Future<void> writeCookie(String cookie) =>
      _storage.write(key: _cookieKey, value: cookie);

  @override
  Future<String?> readProxyPassword() => _storage.read(key: _proxyPasswordKey);

  @override
  Future<void> writeProxyPassword(String password) =>
      _storage.write(key: _proxyPasswordKey, value: password);

  @override
  Future<void> clearSession() => _storage.delete(key: _cookieKey);
}
