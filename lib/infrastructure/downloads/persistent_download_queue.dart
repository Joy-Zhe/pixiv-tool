import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../database/app_database.dart';
import '../network/pixiv_http_client.dart';

class PersistentDownloadQueue implements DownloadQueue {
  PersistentDownloadQueue({
    required AppDatabase database,
    required PixivApi api,
    required PixivHttpClient http,
    int concurrency = 4,
  }) : _database = database,
       _api = api,
       _http = http,
       _concurrency = concurrency.clamp(1, 8) {
    _filePermits = _PermitPool(_concurrency);
  }

  final AppDatabase _database;
  PixivApi _api;
  PixivHttpClient _http;
  int _concurrency;
  final _uuid = const Uuid();
  final _random = Random();
  final _metadataPermits = _PermitPool(2);
  late final _PermitPool _filePermits;
  final _updates = StreamController<DownloadQueueSnapshot>.broadcast();
  final _active = <String>{};
  final _controls = <String, _JobControl>{};
  Timer? _progressTimer;
  int _bytesSinceTick = 0;
  int _lastBytesPerSecond = 0;
  bool _started = false;

  Future<void> reconfigure({
    required PixivApi api,
    required PixivHttpClient http,
    int? concurrency,
  }) async {
    await pauseAll();
    _api = api;
    _http = http;
    if (concurrency != null) _concurrency = concurrency.clamp(1, 8);
  }

  void setConcurrency(int value) {
    _concurrency = value.clamp(1, 8);
    _filePermits.limit = _concurrency;
    unawaited(_pump());
  }

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    await _database.recoverInterruptedJobs();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) async {
      _lastBytesPerSecond = _bytesSinceTick * 5;
      _bytesSinceTick = 0;
      await _emit();
    });
    await _emit();
    unawaited(_pump());
  }

  @override
  Stream<DownloadQueueSnapshot> watch() async* {
    await initialize();
    yield await _snapshot();
    yield* _updates.stream;
  }

  @override
  Future<List<String>> enqueue(DownloadRequest request) async {
    await initialize();
    final ids = <String>[];
    final now = DateTime.now();
    for (final candidate in request.candidates) {
      final id = _uuid.v4();
      ids.add(id);
      final unsupported = candidate.type == IllustType.ugoira;
      await _database
          .into(_database.downloadJobs)
          .insert(
            DownloadJobsCompanion.insert(
              id: id,
              accountId: Value(request.accountId),
              source: request.source.name,
              pid: candidate.pid,
              title: candidate.title,
              authorId: candidate.authorId,
              authorName: candidate.authorName,
              rootPath: request.rootPath,
              pathPrefix: Value(request.pathPrefix),
              status: unsupported
                  ? DownloadStatus.skipped.name
                  : DownloadStatus.pending.name,
              errorCode: unsupported
                  ? Value(DownloadErrorCode.unsupportedType.name)
                  : const Value.absent(),
              errorMessage: unsupported
                  ? const Value(
                      'Ugoira download is not supported in this release',
                    )
                  : const Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await _emit();
    unawaited(_pump());
    return ids;
  }

  @override
  Future<void> pause(String jobId) async {
    _controls.putIfAbsent(jobId, _JobControl.new).paused = true;
    await _setJobStatus(jobId, DownloadStatus.paused);
  }

  @override
  Future<void> resume(String jobId) async {
    final control = _controls.putIfAbsent(jobId, _JobControl.new);
    control
      ..paused = false
      ..cancelled = false;
    await (_database.update(_database.downloadFiles)..where(
          (row) =>
              row.jobId.equals(jobId) &
              row.status.isNotIn([DownloadStatus.completed.name]),
        ))
        .write(
          DownloadFilesCompanion(
            status: Value(DownloadStatus.pending.name),
            retryCount: const Value(0),
            errorCode: const Value(null),
            errorMessage: const Value(''),
          ),
        );
    await _setJobStatus(jobId, DownloadStatus.pending, clearError: true);
    unawaited(_pump());
  }

  @override
  Future<void> cancel(String jobId) async {
    _controls.putIfAbsent(jobId, _JobControl.new).cancelled = true;
    await _setJobStatus(jobId, DownloadStatus.cancelled);
  }

  @override
  Future<void> retry(String jobId) => resume(jobId);

  @override
  Future<void> pauseAll() async {
    final jobs =
        await (_database.select(_database.downloadJobs)..where(
              (row) => row.status.isIn(['pending', 'resolving', 'downloading']),
            ))
            .get();
    for (final job in jobs) {
      await pause(job.id);
    }
  }

  @override
  Future<void> resumeAll() async {
    final jobs = await (_database.select(
      _database.downloadJobs,
    )..where((row) => row.status.isIn(['paused', 'waitingForAuth']))).get();
    for (final job in jobs) {
      await resume(job.id);
    }
  }

  @override
  Future<void> remove(String jobId, {required bool deletePartialFiles}) async {
    _controls.putIfAbsent(jobId, _JobControl.new).cancelled = true;
    for (var attempt = 0; attempt < 600 && _active.contains(jobId); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (_active.contains(jobId)) {
      throw StateError('The download is still stopping; try removing it again');
    }
    final files = await (_database.select(
      _database.downloadFiles,
    )..where((row) => row.jobId.equals(jobId))).get();
    if (deletePartialFiles) {
      for (final file in files) {
        final partial = File(file.temporaryPath);
        if (await partial.exists()) await partial.delete();
      }
    }
    await (_database.delete(
      _database.downloadFiles,
    )..where((row) => row.jobId.equals(jobId))).go();
    await (_database.delete(
      _database.downloadJobs,
    )..where((row) => row.id.equals(jobId))).go();
    await _emit();
  }

  Future<void> _pump() async {
    if (!_started) return;
    while (_active.length < _concurrency) {
      final candidates =
          await (_database.select(_database.downloadJobs)
                ..where((row) => row.status.equals(DownloadStatus.pending.name))
                ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
                ..limit(1))
              .get();
      if (candidates.isEmpty) return;
      final job = candidates.single;
      if (_active.contains(job.id)) return;
      _active.add(job.id);
      await (_database.update(
        _database.downloadJobs,
      )..where((row) => row.id.equals(job.id))).write(
        DownloadJobsCompanion(
          status: Value(DownloadStatus.resolving.name),
          updatedAt: Value(DateTime.now()),
        ),
      );
      unawaited(
        _runJob(job).whenComplete(() {
          _active.remove(job.id);
          unawaited(_pump());
        }),
      );
    }
  }

  Future<void> _runJob(DownloadJob job) async {
    final control = _controls.putIfAbsent(job.id, _JobControl.new);
    try {
      _checkControl(control);
      late final IllustDetail detail;
      late final List<IllustPage> pages;
      await _metadataPermits.acquire();
      try {
        detail = await _api.getIllust(job.pid);
        pages = await _api.getIllustPages(job.pid);
      } finally {
        _metadataPermits.release();
      }
      if (detail.type == IllustType.ugoira) {
        await _failJob(
          job.id,
          DownloadStatus.skipped,
          DownloadErrorCode.unsupportedType,
          'Ugoira download is not supported in this release',
        );
        return;
      }
      await _ensureFileRows(job, detail, pages);
      await _setJobStatus(job.id, DownloadStatus.downloading);
      final files =
          await (_database.select(_database.downloadFiles)
                ..where((row) => row.jobId.equals(job.id))
                ..orderBy([(row) => OrderingTerm.asc(row.pageIndex)]))
              .get();
      await Future.wait(
        files.map((file) async {
          _checkControl(control);
          if (await _isComplete(file)) return;
          await _filePermits.acquire();
          try {
            _checkControl(control);
            await _downloadFile(file, control);
          } finally {
            _filePermits.release();
          }
        }),
      );
      await _setJobStatus(job.id, DownloadStatus.completed, clearError: true);
    } on _PausedException {
      await _setJobStatus(job.id, DownloadStatus.paused);
    } on _CancelledException {
      await _setJobStatus(job.id, DownloadStatus.cancelled);
    } on PixivHttpException catch (error) {
      final status = error.errorCode == DownloadErrorCode.authExpired
          ? DownloadStatus.waitingForAuth
          : DownloadStatus.failed;
      await _failJob(job.id, status, error.errorCode, error.message);
    } on FileSystemException catch (error) {
      await _failJob(
        job.id,
        DownloadStatus.failed,
        DownloadErrorCode.disk,
        error.message,
      );
    } on Object catch (error) {
      await _failJob(
        job.id,
        DownloadStatus.failed,
        DownloadErrorCode.invalidResponse,
        error.toString(),
      );
    }
  }

  Future<void> _ensureFileRows(
    DownloadJob job,
    IllustDetail detail,
    List<IllustPage> pages,
  ) async {
    final existing = await (_database.select(
      _database.downloadFiles,
    )..where((row) => row.jobId.equals(job.id))).get();
    if (existing.isNotEmpty) return;
    final author =
        '${_safe(detail.authorName.isEmpty ? job.authorName : detail.authorName)}_'
        '${_safe(detail.authorId.isEmpty ? job.authorId : detail.authorId)}';
    for (final page in pages) {
      final uri = Uri.parse(page.originalUrl);
      final filename = _safe(p.basename(uri.path));
      final segments = <String>[job.rootPath];
      if (job.pathPrefix.isNotEmpty) segments.addAll(p.split(job.pathPrefix));
      if (job.source.startsWith('bookmark')) segments.add(author);
      segments.add(job.pid);
      final directory = p.joinAll(segments);
      final target = p.join(directory, filename);
      await _database
          .into(_database.downloadFiles)
          .insert(
            DownloadFilesCompanion.insert(
              id: _uuid.v4(),
              jobId: job.id,
              pageIndex: page.index,
              sourceUrl: page.originalUrl,
              targetPath: target,
              temporaryPath: '$target.part',
              status: DownloadStatus.pending.name,
            ),
          );
    }
  }

  Future<void> _downloadFile(DownloadFile row, _JobControl control) async {
    final partial = File(row.temporaryPath);
    final target = File(row.targetPath);
    await partial.parent.create(recursive: true);
    var downloaded = await partial.exists() ? await partial.length() : 0;
    if (row.totalBytes > 0 && downloaded == row.totalBytes) {
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      await _completeFile(row.id, downloaded);
      return;
    }
    if (row.totalBytes > 0 && downloaded > row.totalBytes) {
      await partial.delete();
      downloaded = 0;
    }
    final headers = <String, String>{
      HttpHeaders.acceptHeader:
          'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
    if (downloaded > 0) {
      headers[HttpHeaders.rangeHeader] = 'bytes=$downloaded-';
      final validator = row.etag ?? row.lastModified;
      if (validator != null && validator.isNotEmpty)
        headers[HttpHeaders.ifRangeHeader] = validator;
    }

    HttpClientResponse? response;
    Object? lastError;
    for (var attempt = row.retryCount; attempt <= 4; attempt++) {
      _checkControl(control);
      try {
        response = await _http.open(
          'GET',
          Uri.parse(row.sourceUrl),
          headers: headers,
        );
        break;
      } on PixivHttpException catch (error) {
        lastError = error;
        if (!_retryable(error.statusCode) || attempt == 4) rethrow;
        await _setFileRetry(row.id, attempt + 1, error);
        final delay =
            error.retryAfter ??
            Duration(
              milliseconds:
                  (1 << attempt.clamp(0, 3)) * 1000 + _random.nextInt(350),
            );
        await Future<void>.delayed(delay);
      } on Object catch (error) {
        lastError = error;
        if (attempt == 4) rethrow;
        await Future<void>.delayed(
          Duration(
            milliseconds:
                (1 << attempt.clamp(0, 3)) * 1000 + _random.nextInt(350),
          ),
        );
      }
    }
    if (response == null)
      throw StateError('Download did not start: $lastError');

    if (downloaded > 0 && response.statusCode != HttpStatus.partialContent) {
      downloaded = 0;
      if (await partial.exists()) await partial.delete();
    }
    final responseLength = response.contentLength < 0
        ? 0
        : response.contentLength;
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    final rangeTotal = contentRange == null
        ? null
        : int.tryParse(
            RegExp(r'/(\d+)$').firstMatch(contentRange)?.group(1) ?? '',
          );
    final total = response.statusCode == HttpStatus.partialContent
        ? rangeTotal ?? (responseLength > 0 ? downloaded + responseLength : 0)
        : responseLength;
    if (await target.exists() && total > 0 && await target.length() == total) {
      await response.drain<void>();
      await _completeFile(row.id, total);
      return;
    }

    await (_database.update(
      _database.downloadFiles,
    )..where((file) => file.id.equals(row.id))).write(
      DownloadFilesCompanion(
        status: Value(DownloadStatus.downloading.name),
        downloadedBytes: Value(downloaded),
        totalBytes: Value(total),
        etag: Value(response.headers.value(HttpHeaders.etagHeader)),
        lastModified: Value(
          response.headers.value(HttpHeaders.lastModifiedHeader),
        ),
      ),
    );

    final sink = partial.openWrite(
      mode: downloaded > 0 ? FileMode.append : FileMode.write,
    );
    var lastPersisted = DateTime.now();
    try {
      await for (final chunk in response) {
        _checkControl(control);
        sink.add(chunk);
        downloaded += chunk.length;
        _bytesSinceTick += chunk.length;
        if (DateTime.now().difference(lastPersisted) >=
            const Duration(milliseconds: 200)) {
          await (_database.update(
            _database.downloadFiles,
          )..where((file) => file.id.equals(row.id))).write(
            DownloadFilesCompanion(downloadedBytes: Value(downloaded)),
          );
          lastPersisted = DateTime.now();
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (total > 0 && downloaded != total) {
      throw PixivHttpException(
        0,
        'Incomplete file: received $downloaded of $total bytes',
      );
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    await _completeFile(row.id, downloaded);
  }

  Future<bool> _isComplete(DownloadFile file) async {
    if (file.status != DownloadStatus.completed.name) return false;
    final target = File(file.targetPath);
    return target.existsSync() &&
        (file.totalBytes == 0 || target.lengthSync() == file.totalBytes);
  }

  Future<void> _completeFile(String id, int bytes) =>
      (_database.update(
        _database.downloadFiles,
      )..where((row) => row.id.equals(id))).write(
        DownloadFilesCompanion(
          status: Value(DownloadStatus.completed.name),
          downloadedBytes: Value(bytes),
          totalBytes: Value(bytes),
          errorCode: const Value(null),
          errorMessage: const Value(''),
        ),
      );

  Future<void> _setFileRetry(String id, int retry, PixivHttpException error) =>
      (_database.update(
        _database.downloadFiles,
      )..where((row) => row.id.equals(id))).write(
        DownloadFilesCompanion(
          retryCount: Value(retry),
          errorCode: Value(error.errorCode.name),
          errorMessage: Value(error.message),
        ),
      );

  Future<void> _setJobStatus(
    String id,
    DownloadStatus status, {
    bool clearError = false,
  }) async {
    await (_database.update(
      _database.downloadJobs,
    )..where((row) => row.id.equals(id))).write(
      DownloadJobsCompanion(
        status: Value(status.name),
        errorCode: clearError ? const Value(null) : const Value.absent(),
        errorMessage: clearError ? const Value('') : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _emit();
  }

  Future<void> _failJob(
    String id,
    DownloadStatus status,
    DownloadErrorCode code,
    String message,
  ) async {
    await (_database.update(
      _database.downloadJobs,
    )..where((row) => row.id.equals(id))).write(
      DownloadJobsCompanion(
        status: Value(status.name),
        errorCode: Value(code.name),
        errorMessage: Value(message),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _emit();
  }

  void _checkControl(_JobControl control) {
    if (control.cancelled) throw const _CancelledException();
    if (control.paused) throw const _PausedException();
  }

  bool _retryable(int status) =>
      status == 0 || status == 408 || status == 429 || status >= 500;

  Future<DownloadQueueSnapshot> _snapshot() async {
    final jobs = await (_database.select(
      _database.downloadJobs,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
    final files = await _database.select(_database.downloadFiles).get();
    final views = jobs
        .map((job) {
          final own = files.where((file) => file.jobId == job.id).toList();
          return DownloadJobView(
            id: job.id,
            pid: job.pid,
            title: job.title,
            status: DownloadStatus.values.byName(job.status),
            completedBytes: own.fold(
              0,
              (sum, file) => sum + file.downloadedBytes,
            ),
            totalBytes: own.fold(0, (sum, file) => sum + file.totalBytes),
            completedFiles: own
                .where((file) => file.status == DownloadStatus.completed.name)
                .length,
            totalFiles: own.length,
            rootPath: job.rootPath,
            firstFilePath: own.isEmpty ? null : own.first.targetPath,
            errorCode: job.errorCode == null
                ? null
                : DownloadErrorCode.values.byName(job.errorCode!),
            errorMessage: job.errorMessage,
          );
        })
        .toList(growable: false);
    return DownloadQueueSnapshot(
      jobs: views,
      bytesPerSecond: _lastBytesPerSecond,
    );
  }

  Future<void> _emit() async {
    if (_updates.isClosed) return;
    _updates.add(await _snapshot());
  }

  static String _safe(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    final noTrailingDots = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
    if (noTrailingDots.isEmpty) return 'unknown';
    return noTrailingDots.length > 100
        ? noTrailingDots.substring(0, 100)
        : noTrailingDots;
  }

  Future<void> dispose() async {
    _progressTimer?.cancel();
    await _updates.close();
  }
}

class _JobControl {
  bool paused = false;
  bool cancelled = false;
}

class _PausedException implements Exception {
  const _PausedException();
}

class _CancelledException implements Exception {
  const _CancelledException();
}

class _PermitPool {
  _PermitPool(this._limit);

  int _limit;
  int _inUse = 0;
  final Queue<Completer<void>> _waiting = Queue();

  set limit(int value) {
    _limit = value;
    _wake();
  }

  Future<void> acquire() {
    if (_inUse < _limit) {
      _inUse++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  void release() {
    if (_inUse > 0) _inUse--;
    _wake();
  }

  void _wake() {
    while (_waiting.isNotEmpty && _inUse < _limit) {
      _inUse++;
      _waiting.removeFirst().complete();
    }
  }
}
