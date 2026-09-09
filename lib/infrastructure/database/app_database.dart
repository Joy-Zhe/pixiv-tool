import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Bookmarks extends Table {
  TextColumn get accountId => text()();
  TextColumn get pid => text()();
  TextColumn get visibility => text()();
  TextColumn get title => text()();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  IntColumn get pageCount => integer()();
  TextColumn get illustType => text()();
  TextColumn get thumbnailUrl => text()();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, pid, visibility};
}

class DownloadJobs extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable()();
  TextColumn get source => text()();
  TextColumn get pid => text()();
  TextColumn get title => text()();
  TextColumn get authorId => text()();
  TextColumn get authorName => text()();
  TextColumn get rootPath => text()();
  TextColumn get pathPrefix => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadFiles extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text().references(DownloadJobs, #id)();
  IntColumn get pageIndex => integer()();
  TextColumn get sourceUrl => text()();
  TextColumn get targetPath => text()();
  TextColumn get temporaryPath => text()();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get etag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Accounts, Bookmarks, DownloadJobs, DownloadFiles, Preferences],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  Future<void> recoverInterruptedJobs() async {
    await (update(
      downloadJobs,
    )..where((row) => row.status.isIn(['resolving', 'downloading']))).write(
      DownloadJobsCompanion(
        status: const Value('paused'),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (update(downloadFiles)
          ..where((row) => row.status.equals('downloading')))
        .write(const DownloadFilesCompanion(status: Value('paused')));
  }

  Stream<List<DownloadJob>> watchJobs() => (select(
    downloadJobs,
  )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();

  static LazyDatabase _openConnection() => LazyDatabase(() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'PixivTool'));
    await directory.create(recursive: true);
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'pixiv_tool.sqlite')),
    );
  });
}
