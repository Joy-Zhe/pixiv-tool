import 'package:flutter_test/flutter_test.dart';
import 'package:pixiv_tool/domain/contracts.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/features/search/search_controller.dart';

void main() {
  test('zero popularity thresholds mean no filter', () {
    const filter = SearchFilter(minLikeCount: 0, minBookmarkCount: 0);
    expect(filter.hasThreshold, isFalse);
    expect(filter.matches(_item('unknown')), isTrue);
  });

  test(
    'applies both popularity thresholds and skips detail lookups when unused',
    () async {
      final api = _SearchApi(
        pages: [
          _page([_item('a'), _item('b'), _item('c')]),
        ],
        details: {
          'a': _detail('a', likes: 10, bookmarks: 5),
          'b': _detail('b', likes: 20, bookmarks: 4),
          'c': _detail('c', likes: 20, bookmarks: 8),
        },
      );
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);

      await controller.search(
        const SearchQuery(keyword: 'blue'),
        const SearchFilter(minLikeCount: 10, minBookmarkCount: 5),
      );
      expect(controller.state.items.map((item) => item.pid), ['a', 'c']);
      expect(api.detailCalls, ['a', 'b', 'c']);

      api.detailCalls.clear();
      await controller.search(
        const SearchQuery(keyword: 'blue'),
        const SearchFilter(),
      );
      expect(controller.state.items.map((item) => item.pid), ['a', 'b', 'c']);
      expect(api.detailCalls, isEmpty);
    },
  );

  test(
    'scans at most five raw pages, then continues from the next page',
    () async {
      final pages = [
        for (var page = 1; page <= 6; page++)
          _page([_item('p$page')], hasMore: true),
      ];
      final api = _SearchApi(
        pages: pages,
        details: {'p6': _detail('p6', likes: 100, bookmarks: 1)},
      );
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);

      await controller.search(
        const SearchQuery(keyword: 'blue'),
        const SearchFilter(minLikeCount: 100),
      );
      expect(controller.state.checkedPages, 5);
      expect(controller.state.nextPage, 6);
      expect(controller.state.items, isEmpty);
      expect(controller.state.canContinue, isTrue);
      expect(api.searchPages, [1, 2, 3, 4, 5]);

      await controller.loadMore();
      expect(controller.state.items.single.pid, 'p6');
      expect(api.searchPages, [1, 2, 3, 4, 5, 6]);
    },
  );

  test('preserves selection across pages and deduplicates PIDs', () async {
    final api = _SearchApi(
      pages: [
        _page([_item('a'), _item('b')], hasMore: true),
        _page([_item('a'), _item('c')], hasMore: false),
      ],
    );
    final controller = PixivSearchController(apiProvider: () => api);
    addTearDown(controller.dispose);

    await controller.search(
      const SearchQuery(keyword: 'blue'),
      const SearchFilter(),
    );
    controller.toggleSelection(controller.state.items.first);
    await controller.loadMore();
    expect(controller.state.items.map((item) => item.pid), ['a', 'b', 'c']);
    expect(controller.selectedItems.map((item) => item.pid), ['a']);

    controller.selectLoaded();
    expect(controller.selectedItems.map((item) => item.pid), ['a', 'b', 'c']);
    controller.clearSelection();
    expect(controller.selectedItems, isEmpty);
  });

  test(
    'retries failed detail lookups without treating unknown as zero',
    () async {
      final api = _SearchApi(
        pages: [
          _page([_item('a')]),
        ],
        details: {'a': _detail('a', likes: 4, bookmarks: 1)},
        failuresBeforeSuccess: {'a': 1},
      );
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);

      await controller.search(
        const SearchQuery(keyword: 'blue'),
        const SearchFilter(minLikeCount: 1),
      );
      expect(controller.state.items, isEmpty);
      expect(controller.state.failedDetails, 1);

      await controller.retryFailedDetails();
      expect(controller.state.items.single.pid, 'a');
      expect(controller.state.items.single.likeCount, 4);
      expect(controller.state.failedDetails, 0);
    },
  );

  test(
    'keeps result order when detail requests complete out of order',
    () async {
      final api = _SearchApi(
        pages: [
          _page([_item('slow'), _item('fast')]),
        ],
        details: {
          'slow': _detail('slow', likes: 2, bookmarks: 1),
          'fast': _detail('fast', likes: 3, bookmarks: 1),
        },
        delays: {'slow': const Duration(milliseconds: 30)},
      );
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);

      await controller.search(
        const SearchQuery(keyword: 'blue'),
        const SearchFilter(minLikeCount: 1),
      );
      expect(controller.state.items.map((item) => item.pid), ['slow', 'fast']);
      expect(api.maxConcurrentDetails, lessThanOrEqualTo(2));
    },
  );
}

SearchItem _item(String pid) => SearchItem(
  pid: pid,
  title: pid,
  authorId: 'author',
  authorName: 'artist',
  pageCount: 1,
  type: IllustType.illust,
  thumbnailUrl: '',
);

IllustDetail _detail(
  String pid, {
  required int likes,
  required int bookmarks,
}) => IllustDetail(
  pid: pid,
  title: pid,
  authorId: 'author',
  authorName: 'artist',
  pageCount: 1,
  type: IllustType.illust,
  thumbnailUrl: '',
  likeCount: likes,
  bookmarkCount: bookmarks,
);

PageResult<SearchItem> _page(List<SearchItem> items, {bool hasMore = false}) =>
    PageResult(items: items, total: items.length, hasMore: hasMore);

class _SearchApi implements PixivApi {
  _SearchApi({
    required this.pages,
    this.details = const {},
    this.failuresBeforeSuccess = const {},
    this.delays = const {},
  });

  final List<PageResult<SearchItem>> pages;
  final Map<String, IllustDetail> details;
  final Map<String, int> failuresBeforeSuccess;
  final Map<String, Duration> delays;
  final searchPages = <int>[];
  final detailCalls = <String>[];
  final _remainingFailures = <String, int>{};
  int _activeDetails = 0;
  int maxConcurrentDetails = 0;

  @override
  Future<PageResult<SearchItem>> search(SearchQuery query) async {
    searchPages.add(query.page);
    return pages[query.page - 1];
  }

  @override
  Future<IllustDetail> getIllust(String pid) async {
    detailCalls.add(pid);
    _activeDetails++;
    if (_activeDetails > maxConcurrentDetails) {
      maxConcurrentDetails = _activeDetails;
    }
    try {
      final delay = delays[pid];
      if (delay != null) await Future<void>.delayed(delay);
      final remaining = _remainingFailures.putIfAbsent(
        pid,
        () => failuresBeforeSuccess[pid] ?? 0,
      );
      if (remaining > 0) {
        _remainingFailures[pid] = remaining - 1;
        throw StateError('temporary failure');
      }
      return details[pid] ?? _detail(pid, likes: 0, bookmarks: 0);
    } finally {
      _activeDetails--;
    }
  }

  @override
  Future<List<IllustPage>> getIllustPages(String pid) =>
      throw UnimplementedError();

  @override
  Future<AccountProfile> getCurrentAccount() => throw UnimplementedError();

  @override
  Future<PageResult<RankingItem>> getRanking(RankingQuery query) =>
      throw UnimplementedError();

  @override
  Future<PageResult<BookmarkItem>> getBookmarks(BookmarkQuery query) =>
      throw UnimplementedError();
}
