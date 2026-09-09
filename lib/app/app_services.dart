import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../infrastructure/credentials/secure_credential_store.dart';
import '../infrastructure/database/app_database.dart';
import '../infrastructure/database/preferences_repository.dart';
import '../infrastructure/downloads/persistent_download_queue.dart';
import '../infrastructure/network/pixiv_http_client.dart';
import '../infrastructure/network/system_proxy_resolver.dart';
import '../infrastructure/pixiv/bookmark_repository_impl.dart';
import '../infrastructure/pixiv/pixiv_api_client.dart';
import '../infrastructure/pixiv/pixiv_session_impl.dart';

class AppServices {
  AppServices._();

  late final AppDatabase database;
  late final SecureCredentialStore credentials;
  late final DriftPreferencesRepository preferences;
  late PixivHttpClient http;
  late PixivApiClient api;
  late PixivSessionImpl session;
  late BookmarkRepositoryImpl bookmarks;
  late PersistentDownloadQueue downloads;

  final preferenceState = ValueNotifier<AppPreferences?>(null);
  final accountState = ValueNotifier<AccountSession?>(null);

  static Future<AppServices> create() async {
    final services = AppServices._();
    services.database = AppDatabase();
    services.credentials = SecureCredentialStore();
    services.preferences = DriftPreferencesRepository(services.database);
    final prefs = await services.preferences.load();
    final password = await services.credentials.readProxyPassword() ?? '';
    final cookie = await services.credentials.readCookie() ?? '';
    final systemProxy = await loadSystemProxySettings();
    services.http = PixivHttpClient(
      proxy: prefs.proxy,
      proxyPassword: password,
      cookie: cookie,
      systemProxy: systemProxy,
    );
    services.api = PixivApiClient(services.http);
    services.session = PixivSessionImpl(
      http: services.http,
      credentials: services.credentials,
    );
    services.bookmarks = BookmarkRepositoryImpl(
      services.database,
      services.api,
    );
    services.downloads = PersistentDownloadQueue(
      database: services.database,
      api: services.api,
      http: services.http,
      concurrency: prefs.concurrentDownloads,
    );
    services.preferenceState.value = prefs;
    await services.downloads.initialize();
    services.accountState.value = await services.session.restore();
    if (services.accountState.value case final account?) {
      await services._storeAccount(account);
    }
    return services;
  }

  Future<AccountSession> loginWithCookie(String cookie) async {
    final result = await session.loginWithCookie(cookie);
    accountState.value = result;
    await _storeAccount(result);
    await downloads.resumeAll();
    return result;
  }

  Future<AccountSession> loginWithWebView() async {
    final result = await session.loginWithWebView();
    accountState.value = result;
    await _storeAccount(result);
    await downloads.resumeAll();
    return result;
  }

  Future<void> logout() async {
    await session.logout();
    accountState.value = null;
  }

  Future<void> savePreferences(
    AppPreferences next, {
    String proxyPassword = '',
  }) async {
    final previous = preferenceState.value!;
    await preferences.save(next);
    if (proxyPassword.isNotEmpty) {
      await credentials.writeProxyPassword(proxyPassword);
    }
    final proxyChanged =
        previous.proxy.mode != next.proxy.mode ||
        previous.proxy.host != next.proxy.host ||
        previous.proxy.port != next.proxy.port ||
        previous.proxy.username != next.proxy.username ||
        proxyPassword.isNotEmpty;
    if (proxyChanged) {
      final effectiveProxyPassword = proxyPassword.isNotEmpty
          ? proxyPassword
          : await credentials.readProxyPassword() ?? '';
      final cookie =
          session.current?.cookie ?? await credentials.readCookie() ?? '';
      final oldHttp = http;
      final systemProxy = await loadSystemProxySettings();
      http = PixivHttpClient(
        proxy: next.proxy,
        proxyPassword: effectiveProxyPassword,
        cookie: cookie,
        systemProxy: systemProxy,
      );
      api = PixivApiClient(http);
      session = PixivSessionImpl(http: http, credentials: credentials);
      bookmarks = BookmarkRepositoryImpl(database, api);
      await downloads.reconfigure(api: api, http: http);
      oldHttp.close();
      if (cookie.isNotEmpty) {
        accountState.value = await session.restore();
      }
    }
    if (previous.concurrentDownloads != next.concurrentDownloads) {
      downloads.setConcurrency(next.concurrentDownloads);
    }
    preferenceState.value = next;
  }

  Future<void> dispose() async {
    await downloads.dispose();
    http.close();
    await database.close();
    preferenceState.dispose();
    accountState.dispose();
  }

  Future<void> _storeAccount(AccountSession account) => database
      .into(database.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion.insert(
          id: account.profile.id,
          name: account.profile.name,
          avatarUrl: Value(account.profile.avatarUrl),
          updatedAt: DateTime.now(),
        ),
      );
}
