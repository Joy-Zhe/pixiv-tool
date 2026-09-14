enum BookmarkVisibility { public, private }

enum IllustType { illust, manga, ugoira }

enum DownloadSource { pid, ranking, bookmarkSelection, bookmarkBatch, search }

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

enum SearchMode { tagPartial, tagExact, titleOrDescription }

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
    this.likeCount,
    this.bookmarkCount,
  });

  final String pid;
  final String title;
  final String authorId;
  final String authorName;
  final int pageCount;
  final IllustType type;
  final String thumbnailUrl;
  final int? likeCount;
  final int? bookmarkCount;
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

class SearchQuery {
  const SearchQuery({
    required this.keyword,
    this.mode = SearchMode.tagPartial,
    this.page = 1,
    this.includeAi = false,
    this.includeR18 = false,
  });

  final String keyword;
  final SearchMode mode;
  final int page;
  final bool includeAi;
  final bool includeR18;

  SearchQuery copyWith({
    String? keyword,
    SearchMode? mode,
    int? page,
    bool? includeAi,
    bool? includeR18,
  }) => SearchQuery(
    keyword: keyword ?? this.keyword,
    mode: mode ?? this.mode,
    page: page ?? this.page,
    includeAi: includeAi ?? this.includeAi,
    includeR18: includeR18 ?? this.includeR18,
  );
}

class SearchFilter {
  const SearchFilter({this.minLikeCount, this.minBookmarkCount});

  final int? minLikeCount;
  final int? minBookmarkCount;

  bool get hasThreshold =>
      (minLikeCount ?? 0) > 0 || (minBookmarkCount ?? 0) > 0;

  bool matches(SearchItem item) {
    if (minLikeCount != null &&
        minLikeCount! > 0 &&
        (item.likeCount == null || item.likeCount! < minLikeCount!)) {
      return false;
    }
    if (minBookmarkCount != null &&
        minBookmarkCount! > 0 &&
        (item.bookmarkCount == null ||
            item.bookmarkCount! < minBookmarkCount!)) {
      return false;
    }
    return true;
  }
}

class SearchItem {
  const SearchItem({
    required this.pid,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.pageCount,
    required this.type,
    required this.thumbnailUrl,
    this.tags = const [],
    this.likeCount,
    this.bookmarkCount,
  });

  final String pid;
  final String title;
  final String authorId;
  final String authorName;
  final int pageCount;
  final IllustType type;
  final String thumbnailUrl;
  final List<String> tags;
  final int? likeCount;
  final int? bookmarkCount;

  SearchItem copyWith({
    String? title,
    String? authorId,
    String? authorName,
    int? pageCount,
    IllustType? type,
    String? thumbnailUrl,
    List<String>? tags,
    int? likeCount,
    int? bookmarkCount,
  }) => SearchItem(
    pid: pid,
    title: title ?? this.title,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    pageCount: pageCount ?? this.pageCount,
    type: type ?? this.type,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    tags: tags ?? this.tags,
    likeCount: likeCount ?? this.likeCount,
    bookmarkCount: bookmarkCount ?? this.bookmarkCount,
  );
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
