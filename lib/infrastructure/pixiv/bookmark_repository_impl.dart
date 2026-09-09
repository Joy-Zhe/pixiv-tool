import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../database/app_database.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl(this._database, this._api);

  final AppDatabase _database;
  final PixivApi _api;

  @override
  Stream<List<BookmarkItem>> watchCached(BookmarkFilter filter) {
    final query = _database.select(_database.bookmarks)
      ..where(
        (row) =>
            row.accountId.equals(filter.accountId) &
            row.visibility.equals(filter.visibility.name),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.syncedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(_fromRow)
          .where((item) => filter.tag.isEmpty || item.tags.contains(filter.tag))
          .where((item) => filter.type == null || item.type == filter.type)
          .toList(growable: false),
    );
  }

  Future<PageResult<BookmarkItem>> loadPage(
    BookmarkFilter filter,
    int offset,
  ) async {
    final result = await _api.getBookmarks(
      BookmarkQuery(
        accountId: filter.accountId,
        visibility: filter.visibility,
        tag: filter.tag,
        offset: offset,
      ),
    );
    await _upsert(result.items);
    return PageResult(
      // Keep the server page length intact so the caller advances the AJAX
      // offset correctly. Type filtering is applied by watchCached.
      items: result.items,
      total: result.total,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<PageResult<BookmarkItem>> refreshFirstPage(BookmarkFilter filter) =>
      loadPage(filter, 0);

  @override
  Future<BookmarkSyncResult> syncAll(BookmarkFilter filter) async {
    var offset = 0;
    var hasMore = true;
    final receivedPids = <String>{};
    while (hasMore) {
      final result = await _api.getBookmarks(
        BookmarkQuery(
          accountId: filter.accountId,
          visibility: filter.visibility,
          tag: filter.tag,
          offset: offset,
        ),
      );
      await _upsert(result.items);
      receivedPids.addAll(result.items.map((item) => item.pid));
      offset += result.items.length;
      hasMore = result.hasMore && result.items.isNotEmpty;
    }

    var removed = 0;
    if (filter.tag.isEmpty) {
      final stale =
          await (_database.select(_database.bookmarks)..where(
                (row) =>
                    row.accountId.equals(filter.accountId) &
                    row.visibility.equals(filter.visibility.name),
              ))
              .get();
      final stalePids = stale
          .map((row) => row.pid)
          .where((pid) => !receivedPids.contains(pid))
          .toList();
      if (stalePids.isNotEmpty) {
        removed =
            await (_database.delete(_database.bookmarks)..where(
                  (row) =>
                      row.accountId.equals(filter.accountId) &
                      row.visibility.equals(filter.visibility.name) &
                      row.pid.isIn(stalePids),
                ))
                .go();
      }
    }
    return BookmarkSyncResult(received: receivedPids.length, removed: removed);
  }

  Future<List<BookmarkItem>> snapshotAll(BookmarkFilter filter) async {
    await syncAll(filter);
    return watchCached(filter).first;
  }

  Future<void> clearAccount(String accountId) => (_database.delete(
    _database.bookmarks,
  )..where((row) => row.accountId.equals(accountId))).go();

  Future<void> _upsert(List<BookmarkItem> items) async {
    final now = DateTime.now();
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.bookmarks,
        items
            .map(
              (item) => BookmarksCompanion.insert(
                accountId: item.accountId,
                pid: item.pid,
                visibility: item.visibility.name,
                title: item.title,
                authorId: item.authorId,
                authorName: item.authorName,
                pageCount: item.pageCount,
                illustType: item.type.name,
                thumbnailUrl: item.thumbnailUrl,
                tagsJson: Value(jsonEncode(item.tags)),
                syncedAt: now,
              ),
            )
            .toList(),
      );
    });
  }

  static BookmarkItem _fromRow(Bookmark row) => BookmarkItem(
    accountId: row.accountId,
    pid: row.pid,
    visibility: BookmarkVisibility.values.byName(row.visibility),
    title: row.title,
    authorId: row.authorId,
    authorName: row.authorName,
    pageCount: row.pageCount,
    type: IllustType.values.byName(row.illustType),
    thumbnailUrl: row.thumbnailUrl,
    tags: (jsonDecode(row.tagsJson) as List).cast<String>(),
  );
}
