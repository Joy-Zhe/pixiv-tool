import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pixiv_tool/domain/contracts.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/infrastructure/database/app_database.dart';
import 'package:pixiv_tool/infrastructure/downloads/persistent_download_queue.dart';
import 'package:pixiv_tool/infrastructure/network/pixiv_http_client.dart';

void main() {
  test('streams a file through the persistent queue', () async {
    final bytes = Uint8List.fromList(
      List.generate(256 * 1024, (index) => index % 251),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = bytes.length
        ..add(bytes);
      await request.response.close();
    });
    final temp = await Directory.systemTemp.createTemp('pixiv-tool-queue-');
    addTearDown(() => temp.delete(recursive: true));
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final http = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
      cookie: 'PHPSESSID=test',
    );
    final api = _DownloadApi(
      'http://${server.address.host}:${server.port}/100_p0.jpg',
    );
    final queue = PersistentDownloadQueue(
      database: database,
      api: api,
      http: http,
    );
    addTearDown(queue.dispose);

    final ids = await queue.enqueue(
      DownloadRequest(
        source: DownloadSource.pid,
        rootPath: temp.path,
        candidates: const [
          DownloadCandidate(
            pid: '100',
            title: 'test',
            authorId: '7',
            authorName: 'artist',
            type: IllustType.illust,
          ),
        ],
      ),
    );
    final snapshot = await queue
        .watch()
        .firstWhere(
          (value) => value.jobs.any(
            (job) =>
                job.id == ids.single && job.status == DownloadStatus.completed,
          ),
        )
        .timeout(const Duration(seconds: 10));
    final job = snapshot.jobs.singleWhere((item) => item.id == ids.single);
    expect(job.completedFiles, 1);
    final file = File(p.join(temp.path, '100', '100_p0.jpg'));
    expect(await file.readAsBytes(), bytes);
    expect(await File('${file.path}.part').exists(), isFalse);
  });

  test('ugoira is recorded as skipped without an HTTP request', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final http = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
    );
    final queue = PersistentDownloadQueue(
      database: database,
      api: _DownloadApi(''),
      http: http,
    );
    addTearDown(queue.dispose);
    final ids = await queue.enqueue(
      const DownloadRequest(
        source: DownloadSource.bookmarkSelection,
        rootPath: '.',
        candidates: [
          DownloadCandidate(
            pid: '200',
            title: 'animation',
            authorId: '7',
            authorName: 'artist',
            type: IllustType.ugoira,
          ),
        ],
      ),
    );
    final value = await queue.watch().first;
    final job = value.jobs.singleWhere((item) => item.id == ids.single);
    expect(job.status, DownloadStatus.skipped);
    expect(job.errorCode, DownloadErrorCode.unsupportedType);
  });

  test('resumes a partial file with Range and preserves content', () async {
    final bytes = Uint8List.fromList(
      List.generate(512 * 1024, (index) => index % 239),
    );
    const partialLength = 96 * 1024;
    String? receivedRange;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      receivedRange = request.headers.value(HttpHeaders.rangeHeader);
      request.response
        ..statusCode = HttpStatus.partialContent
        ..contentLength = bytes.length - partialLength
        ..headers.set(HttpHeaders.etagHeader, '"fixture-v1"')
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $partialLength-${bytes.length - 1}/${bytes.length}',
        )
        ..add(bytes.sublist(partialLength));
      await request.response.close();
    });
    final temp = await Directory.systemTemp.createTemp('pixiv-tool-resume-');
    addTearDown(() => temp.delete(recursive: true));
    final target = File(p.join(temp.path, '300', '300_p0.jpg'));
    final partial = File('${target.path}.part');
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(bytes.sublist(0, partialLength));
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.now();
    await database
        .into(database.downloadJobs)
        .insert(
          DownloadJobsCompanion.insert(
            id: 'resume-job',
            source: DownloadSource.pid.name,
            pid: '300',
            title: 'resume',
            authorId: '7',
            authorName: 'artist',
            rootPath: temp.path,
            status: DownloadStatus.paused.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.downloadFiles)
        .insert(
          DownloadFilesCompanion.insert(
            id: 'resume-file',
            jobId: 'resume-job',
            pageIndex: 0,
            sourceUrl:
                'http://${server.address.host}:${server.port}/300_p0.jpg',
            targetPath: target.path,
            temporaryPath: partial.path,
            downloadedBytes: const Value(partialLength),
            totalBytes: Value(bytes.length),
            etag: const Value('"fixture-v1"'),
            status: DownloadStatus.paused.name,
          ),
        );
    final http = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
      cookie: 'PHPSESSID=test',
    );
    final queue = PersistentDownloadQueue(
      database: database,
      api: _DownloadApi('unused'),
      http: http,
    );
    addTearDown(queue.dispose);

    await queue.initialize();
    await queue.resume('resume-job');
    await queue
        .watch()
        .firstWhere(
          (value) => value.jobs.any(
            (job) =>
                job.id == 'resume-job' &&
                job.status == DownloadStatus.completed,
          ),
        )
        .timeout(const Duration(seconds: 10));

    expect(receivedRange, 'bytes=$partialLength-');
    expect(await target.readAsBytes(), bytes);
  });
}

class _DownloadApi implements PixivApi {
  _DownloadApi(this.url);
  final String url;

  @override
  Future<IllustDetail> getIllust(String pid) async => IllustDetail(
    pid: pid,
    title: 'test',
    authorId: '7',
    authorName: 'artist',
    pageCount: 1,
    type: IllustType.illust,
    thumbnailUrl: '',
  );

  @override
  Future<List<IllustPage>> getIllustPages(String pid) async => [
    IllustPage(index: 0, originalUrl: url),
  ];

  @override
  Future<PageResult<BookmarkItem>> getBookmarks(BookmarkQuery query) =>
      throw UnimplementedError();
  @override
  Future<AccountProfile> getCurrentAccount() => throw UnimplementedError();
  @override
  Future<PageResult<RankingItem>> getRanking(RankingQuery query) =>
      throw UnimplementedError();
}
