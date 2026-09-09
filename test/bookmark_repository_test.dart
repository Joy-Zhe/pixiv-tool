import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixiv_tool/domain/contracts.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/infrastructure/database/app_database.dart';
import 'package:pixiv_tool/infrastructure/pixiv/bookmark_repository_impl.dart';

void main() {
  test('full sync replaces stale cache only after success', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = _BookmarkApi();
    final repository = BookmarkRepositoryImpl(database, api);
    const filter = BookmarkFilter(
      accountId: 'account',
      visibility: BookmarkVisibility.public,
    );

    api.items = [_item('old')];
    await repository.syncAll(filter);
    expect(
      (await repository.watchCached(filter).first).map((item) => item.pid),
      ['old'],
    );

    api.items = [_item('new')];
    final result = await repository.syncAll(filter);
    expect(result.removed, 1);
    expect(
      (await repository.watchCached(filter).first).map((item) => item.pid),
      ['new'],
    );
  });

  test('cache is isolated by account', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = _BookmarkApi()..items = [_item('one')];
    final repository = BookmarkRepositoryImpl(database, api);
    await repository.syncAll(
      const BookmarkFilter(
        accountId: 'account',
        visibility: BookmarkVisibility.public,
      ),
    );
    final other = await repository
        .watchCached(
          const BookmarkFilter(
            accountId: 'other',
            visibility: BookmarkVisibility.public,
          ),
        )
        .first;
    expect(other, isEmpty);
  });

  test('failed full sync does not delete cached bookmarks', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final api = _BookmarkApi()..items = [_item('retained')];
    final repository = BookmarkRepositoryImpl(database, api);
    const filter = BookmarkFilter(
      accountId: 'account',
      visibility: BookmarkVisibility.public,
    );
    await repository.syncAll(filter);
    api.throwOnRequest = true;

    await expectLater(repository.syncAll(filter), throwsStateError);

    final cached = await repository.watchCached(filter).first;
    expect(cached.map((item) => item.pid), ['retained']);
  });
}

BookmarkItem _item(String pid) => BookmarkItem(
  accountId: 'account',
  pid: pid,
  visibility: BookmarkVisibility.public,
  title: pid,
  authorId: '7',
  authorName: 'artist',
  pageCount: 1,
  type: IllustType.illust,
  thumbnailUrl: '',
);

class _BookmarkApi implements PixivApi {
  List<BookmarkItem> items = [];
  bool throwOnRequest = false;

  @override
  Future<PageResult<BookmarkItem>> getBookmarks(BookmarkQuery query) async {
    if (throwOnRequest) throw StateError('fixture sync failure');
    final mapped = items
        .map(
          (item) => BookmarkItem(
            accountId: query.accountId,
            pid: item.pid,
            visibility: query.visibility,
            title: item.title,
            authorId: item.authorId,
            authorName: item.authorName,
            pageCount: item.pageCount,
            type: item.type,
            thumbnailUrl: item.thumbnailUrl,
          ),
        )
        .toList();
    return PageResult(items: mapped, total: mapped.length, hasMore: false);
  }

  @override
  Future<AccountProfile> getCurrentAccount() => throw UnimplementedError();
  @override
  Future<IllustDetail> getIllust(String pid) => throw UnimplementedError();
  @override
  Future<List<IllustPage>> getIllustPages(String pid) =>
      throw UnimplementedError();
  @override
  Future<PageResult<RankingItem>> getRanking(RankingQuery query) =>
      throw UnimplementedError();
}
