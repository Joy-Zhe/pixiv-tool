enum BookmarkVisibility { public, private }

enum IllustType { illust, manga, ugoira }

enum DownloadSource { pid, ranking, bookmarkSelection, bookmarkBatch }

enum DownloadStatus {
  pending,
  resolving,
  downloading,
  paused,
  waitingForAuth,
  completed,
  failed,
  cancelled,
  skipped,
}

enum ProxyMode { system, manual, direct }

enum DownloadErrorCode {
  authExpired,
  forbidden,
  notFound,
  rateLimited,
  network,
  disk,
  invalidResponse,
  unsupportedType,
}

enum RankingMode { daily, weekly, monthly }

enum RankingContent { all, illust, manga }

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String avatarUrl;
}

class AccountSession {
  const AccountSession({required this.profile, required this.cookie});

  final AccountProfile profile;
  final String cookie;
}

class IllustPage {
  const IllustPage({required this.index, required this.originalUrl});

  final int index;
  final String originalUrl;
}

class IllustDetail {
  const IllustDetail({
    required this.pid,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.pageCount,
    required this.type,
    required this.thumbnailUrl,
  });

  final String pid;
  final String title;
  final String authorId;
  final String authorName;
  final int pageCount;
  final IllustType type;
  final String thumbnailUrl;
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<T> items;
  final int total;
  final bool hasMore;
}

class RankingQuery {
  const RankingQuery({
    this.mode = RankingMode.daily,
    this.content = RankingContent.all,
    this.r18 = false,
    this.startPage = 1,
    this.endPage = 1,
  });

  final RankingMode mode;
  final RankingContent content;
  final bool r18;
  final int startPage;
  final int endPage;
}

class RankingItem {
  const RankingItem({
    required this.pid,
    required this.title,
    required this.rank,
    required this.authorId,
    required this.authorName,
    required this.thumbnailUrl,
    required this.type,
  });

  final String pid;
  final String title;
  final int rank;
  final String authorId;
  final String authorName;
  final String thumbnailUrl;
  final IllustType type;
}

class BookmarkItem {
  const BookmarkItem({
    required this.accountId,
    required this.pid,
    required this.visibility,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.pageCount,
    required this.type,
    required this.thumbnailUrl,
    this.tags = const [],
  });

  final String accountId;
  final String pid;
  final BookmarkVisibility visibility;
  final String title;
  final String authorId;
  final String authorName;
  final int pageCount;
  final IllustType type;
  final String thumbnailUrl;
  final List<String> tags;
}

class BookmarkQuery {
  const BookmarkQuery({
    required this.accountId,
    required this.visibility,
    this.tag = '',
    this.offset = 0,
    this.limit = 48,
  });

  final String accountId;
  final BookmarkVisibility visibility;
  final String tag;
  final int offset;
  final int limit;
}

class BookmarkFilter {
  const BookmarkFilter({
    required this.accountId,
    required this.visibility,
    this.tag = '',
    this.type,
  });

  final String accountId;
  final BookmarkVisibility visibility;
  final String tag;
  final IllustType? type;
}

class BookmarkSyncResult {
  const BookmarkSyncResult({required this.received, required this.removed});

  final int received;
  final int removed;
}

class DownloadCandidate {
  const DownloadCandidate({
    required this.pid,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.type,
  });

  final String pid;
  final String title;
  final String authorId;
  final String authorName;
  final IllustType type;
}

class DownloadRequest {
  const DownloadRequest({
    required this.source,
    required this.rootPath,
    required this.candidates,
    this.pathPrefix = '',
    this.accountId,
  });

  final DownloadSource source;
  final String rootPath;
  final List<DownloadCandidate> candidates;
  final String pathPrefix;
  final String? accountId;
}

class DownloadJobView {
  const DownloadJobView({
    required this.id,
    required this.pid,
    required this.title,
    required this.status,
    required this.completedBytes,
    required this.totalBytes,
    required this.completedFiles,
    required this.totalFiles,
    required this.rootPath,
    this.firstFilePath,
    this.errorCode,
    this.errorMessage = '',
  });

  final String id;
  final String pid;
  final String title;
  final DownloadStatus status;
  final int completedBytes;
  final int totalBytes;
  final int completedFiles;
  final int totalFiles;
  final String rootPath;
  final String? firstFilePath;
  final DownloadErrorCode? errorCode;
  final String errorMessage;

  double get progress => totalBytes > 0
      ? completedBytes / totalBytes
      : totalFiles == 0
      ? 0
      : completedFiles / totalFiles;
}

class DownloadQueueSnapshot {
  const DownloadQueueSnapshot({
    required this.jobs,
    required this.bytesPerSecond,
  });

  final List<DownloadJobView> jobs;
  final int bytesPerSecond;
}

class ProxyConfig {
  const ProxyConfig({
    this.mode = ProxyMode.system,
    this.host = '',
    this.port = 0,
    this.username = '',
  });

  final ProxyMode mode;
  final String host;
  final int port;
  final String username;
}

class AppPreferences {
  const AppPreferences({
    required this.pidRoot,
    required this.rankingRoot,
    required this.bookmarkRoot,
    this.concurrentDownloads = 4,
    this.localeCode = '',
    this.themeMode = 'system',
    this.proxy = const ProxyConfig(),
  });

  final String pidRoot;
  final String rankingRoot;
  final String bookmarkRoot;
  final int concurrentDownloads;
  final String localeCode;
  final String themeMode;
  final ProxyConfig proxy;
}
