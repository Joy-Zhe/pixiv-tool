import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixiv_tool/domain/contracts.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/features/search/search_controller.dart';
import 'package:pixiv_tool/infrastructure/network/pixiv_http_client.dart';

void main() {
  test('first page failure can retry the same page', () async {
    var calls = 0;
    final api = _Api((query) async {
      expect(query.page, 1);
      if (++calls == 1) throw StateError('offline');
      return _page(['1']);
    });
    final controller = PixivSearchController(apiProvider: () => api);
    addTearDown(controller.dispose);
    await controller.search(
      const SearchQuery(keyword: 'tag'),
      const SearchFilter(),
    );
    expect(controller.state.error, isNotNull);
    expect(controller.state.canContinue, isTrue);
    await controller.loadMore();
    expect(controller.state.items.single.pid, '1');
    expect(controller.state.error, isNull);
  });

  test(
    'stopping the first page keeps its cursor and discards late data',
    () async {
      final first = Completer<PageResult<SearchItem>>();
      var calls = 0;
      final api = _Api((query) {
        expect(query.page, 1);
        return ++calls == 1 ? first.future : Future.value(_page(['2']));
      });
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);
      final pending = controller.search(
        const SearchQuery(keyword: 'tag'),
        const SearchFilter(),
      );
      controller.stop();
      expect(controller.state.canContinue, isTrue);
      await controller.loadMore();
      first.complete(_page(['1']));
      await pending;
      expect(controller.state.items.single.pid, '2');
      expect(controller.state.checkedPages, 1);
    },
  );

  test('a new query discards old responses and selection', () async {
    final old = Completer<PageResult<SearchItem>>();
    final api = _Api(
      (query) =>
          query.keyword == 'old' ? old.future : Future.value(_page(['2'])),
    );
    final controller = PixivSearchController(apiProvider: () => api);
    addTearDown(controller.dispose);
    final pending = controller.search(
      const SearchQuery(keyword: 'old'),
      const SearchFilter(),
    );
    await controller.search(
      const SearchQuery(keyword: 'new'),
      const SearchFilter(),
    );
    old.complete(_page(['1']));
    await pending;
    expect(controller.state.query!.keyword, 'new');
    expect(controller.state.items.single.pid, '2');
    controller.selectLoaded();
    await controller.search(
      const SearchQuery(keyword: 'new'),
      const SearchFilter(minLikeCount: 0),
    );
    expect(controller.selectedItems, isEmpty);
  });

  test('authentication failure does not commit an incomplete page', () async {
    var expired = true;
    final pages = <int>[];
    final api = _Api(
      (query) async {
        pages.add(query.page);
        return _page(['1', '2', '3']);
      },
      details: (pid) async {
        if (expired) throw const PixivHttpException(401, 'expired');
        return _detail(pid);
      },
    );
    final controller = PixivSearchController(apiProvider: () => api);
    addTearDown(controller.dispose);
    await controller.search(
      const SearchQuery(keyword: 'tag'),
      const SearchFilter(minLikeCount: 1),
    );
    expect(controller.state.nextPage, 1);
    expect(controller.state.checkedPages, 0);
    expect(controller.state.canContinue, isTrue);
    expired = false;
    await controller.loadMore();
    expect(pages, [1, 1]);
    expect(controller.state.items.map((item) => item.pid), ['1', '2', '3']);
  });

  test('detail concurrency stays bounded across replaced searches', () async {
    final gates = <String, Completer<IllustDetail>>{};
    var active = 0;
    var maximum = 0;
    final api = _Api(
      (query) async => _page(query.keyword == 'old' ? ['1', '2'] : ['3', '4']),
      details: (pid) async {
        active++;
        if (active > maximum) maximum = active;
        final gate = gates.putIfAbsent(pid, Completer<IllustDetail>.new);
        try {
          return await gate.future;
        } finally {
          active--;
        }
      },
    );
    final controller = PixivSearchController(apiProvider: () => api);
    addTearDown(controller.dispose);
    final old = controller.search(
      const SearchQuery(keyword: 'old'),
      const SearchFilter(minLikeCount: 1),
    );
    await _until(() => gates.length == 2);
    final current = controller.search(
      const SearchQuery(keyword: 'new'),
      const SearchFilter(minLikeCount: 1),
    );
    await Future<void>.delayed(Duration.zero);
    expect(gates.keys, ['1', '2']);
    gates['1']!.complete(_detail('1'));
    gates['2']!.complete(_detail('2'));
    await _until(() => gates.length == 4);
    gates['4']!.complete(_detail('4'));
    gates['3']!.complete(_detail('3'));
    await Future.wait([old, current]);
    expect(maximum, 2);
    expect(controller.state.items.map((item) => item.pid), ['3', '4']);
  });

  test(
    'zero thresholds do not fetch details or scan past duplicate pages',
    () async {
      final pages = <int>[];
      final api = _Api((query) async {
        pages.add(query.page);
        return _page(['1'], hasMore: true);
      }, details: (_) async => throw StateError('unexpected detail lookup'));
      final controller = PixivSearchController(apiProvider: () => api);
      addTearDown(controller.dispose);
      await controller.search(
        const SearchQuery(keyword: 'tag'),
        const SearchFilter(minLikeCount: 0, minBookmarkCount: 0),
      );
      await controller.loadMore();
      expect(pages, [1, 2]);
      expect(controller.state.items.single.pid, '1');
    },
  );
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected asynchronous operation did not start');
}

PageResult<SearchItem> _page(List<String> pids, {bool hasMore = false}) =>
    PageResult(
      items: [
        for (final pid in pids)
          SearchItem(
            pid: pid,
            title: pid,
            authorId: '7',
            authorName: 'artist',
            pageCount: 1,
            type: IllustType.illust,
            thumbnailUrl: '',
          ),
      ],
      total: pids.length,
      hasMore: hasMore,
    );

IllustDetail _detail(String pid) => IllustDetail(
  pid: pid,
  title: pid,
  authorId: '7',
  authorName: 'artist',
  pageCount: 1,
  type: IllustType.illust,
  thumbnailUrl: '',
  likeCount: 10,
  bookmarkCount: 20,
);

class _Api implements PixivApi {
  _Api(this.onSearch, {Future<IllustDetail> Function(String)? details})
    : onDetails = details ?? ((pid) async => _detail(pid));
  final Future<PageResult<SearchItem>> Function(SearchQuery) onSearch;
  final Future<IllustDetail> Function(String) onDetails;

  @override
  Future<PageResult<SearchItem>> search(SearchQuery query) => onSearch(query);
  @override
  Future<IllustDetail> getIllust(String pid) => onDetails(pid);
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
