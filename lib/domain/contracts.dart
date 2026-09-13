import 'models.dart';

abstract interface class PixivSession {
  Future<AccountSession> loginWithWebView();
  Future<AccountSession> loginWithCookie(String rawCookie);
  Future<AccountSession?> restore();
  Future<void> logout();
}

abstract interface class PixivApi {
  Future<IllustDetail> getIllust(String pid);
  Future<List<IllustPage>> getIllustPages(String pid);
  Future<PageResult<RankingItem>> getRanking(RankingQuery query);
  Future<AccountProfile> getCurrentAccount();
  Future<PageResult<BookmarkItem>> getBookmarks(BookmarkQuery query);
  Future<PageResult<SearchItem>> search(SearchQuery query);
}

abstract interface class BookmarkRepository {
  Stream<List<BookmarkItem>> watchCached(BookmarkFilter filter);
  Future<PageResult<BookmarkItem>> refreshFirstPage(BookmarkFilter filter);
  Future<BookmarkSyncResult> syncAll(BookmarkFilter filter);
}

abstract interface class DownloadQueue {
  Stream<DownloadQueueSnapshot> watch();
  Future<List<String>> enqueue(DownloadRequest request);
  Future<void> pause(String jobId);
  Future<void> resume(String jobId);
  Future<void> cancel(String jobId);
  Future<void> retry(String jobId);
  Future<void> remove(String jobId, {required bool deletePartialFiles});
  Future<void> pauseAll();
  Future<void> resumeAll();
}

abstract interface class PreferencesRepository {
  Future<AppPreferences> load();
  Future<void> save(AppPreferences preferences);
}

abstract interface class CredentialStore {
  Future<String?> readCookie();
  Future<void> writeCookie(String cookie);
  Future<String?> readProxyPassword();
  Future<void> writeProxyPassword(String password);
  Future<void> clearSession();
}
