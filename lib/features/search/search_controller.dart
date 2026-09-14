import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../../infrastructure/network/pixiv_http_client.dart';

class SearchControllerState {
  const SearchControllerState({
    this.query,
    this.filter = const SearchFilter(),
    this.items = const [],
    this.selectedPids = const {},
    this.isBusy = false,
    this.hasMore = false,
    this.nextPage = 1,
    this.checkedPages = 0,
    this.scannedWorks = 0,
    this.serverTotal = 0,
    this.failedDetails = 0,
    this.wasStopped = false,
    this.error,
  });

  final SearchQuery? query;
  final SearchFilter filter;
  final List<SearchItem> items;
  final Set<String> selectedPids;
  final bool isBusy;
  final bool hasMore;
  final int nextPage;
  final int checkedPages;
  final int scannedWorks;
  final int serverTotal;
  final int failedDetails;
  final bool wasStopped;
  final String? error;

  bool get canContinue => query != null && hasMore && !isBusy;

  bool get hasQuery => query != null;
}

/// Coordinates bounded Pixiv search scans and the optional detail lookups
/// needed for exact popularity filtering.
class PixivSearchController extends ChangeNotifier {
  PixivSearchController({required PixivApi Function() apiProvider})
    : _apiProvider = apiProvider;

  static const maxPagesPerScan = 5;
  static const maxDetailCacheEntries = 500;
  static const maxDetailConcurrency = 2;

  final PixivApi Function() _apiProvider;
  final _detailCache = <String, IllustDetail>{};
  final _seenPids = <String>{};
  final _rawItems = <String, SearchItem>{};
  final _resultItems = <String, SearchItem>{};
  final _detailFailures = <String, String>{};
  final _detailWaiters = Queue<Completer<void>>();
  int _activeDetailRequests = 0;

  SearchControllerState _state = const SearchControllerState();
  int _generation = 0;
  SearchQuery? _query;
  SearchFilter _filter = const SearchFilter();
  bool _hasMore = false;
  int _nextPage = 1;
  bool _disposed = false;

  SearchControllerState get state => _state;

  List<SearchItem> get _orderedResults =>
      List.unmodifiable([for (final pid in _rawItems.keys) ?_resultItems[pid]]);

  List<SearchItem> get selectedItems => _state.items
      .where((item) => _state.selectedPids.contains(item.pid))
      .toList(growable: false);

  void reset() {
    if (_disposed) return;
    ++_generation;
    _query = null;
    _filter = const SearchFilter();
    _seenPids.clear();
    _rawItems.clear();
    _resultItems.clear();
    _detailFailures.clear();
    _detailCache.clear();
    _hasMore = false;
    _nextPage = 1;
    _state = const SearchControllerState();
    notifyListeners();
  }

  Future<void> search(SearchQuery query, SearchFilter filter) async {
    if (_disposed) return;
    final keyword = query.keyword.trim();
    if (keyword.isEmpty) {
      stop();
      _publish(error: 'Search keyword cannot be empty', clearError: false);
      return;
    }
    if (!_validThreshold(filter.minLikeCount) ||
        !_validThreshold(filter.minBookmarkCount)) {
      stop();
      _publish(error: 'Popularity thresholds must be non-negative integers');
      return;
    }
    final generation = ++_generation;
    _query = query.copyWith(keyword: keyword, page: 1);
    _filter = filter;
    _seenPids.clear();
    _rawItems.clear();
    _resultItems.clear();
    _detailFailures.clear();
    _detailCache.clear();
    _hasMore = true;
    _nextPage = 1;
    _state = SearchControllerState(
      query: _query,
      filter: _filter,
      isBusy: true,
      hasMore: true,
      wasStopped: false,
    );
    notifyListeners();
    await _scan(generation);
  }

  Future<void> loadMore() async {
    if (_state.isBusy || _query == null || !_hasMore || _disposed) return;
    final generation = ++_generation;
    _publish(isBusy: true, clearError: true, wasStopped: false);
    await _scan(generation);
  }

  Future<void> retryFailedDetails() async {
    if (_state.isBusy || _detailFailures.isEmpty || _disposed) return;
    final items = _detailFailures.keys
        .map((pid) => _rawItems[pid])
        .whereType<SearchItem>()
        .toList(growable: false);
    if (items.isEmpty) return;
    final generation = ++_generation;
    _publish(isBusy: true, clearError: true, wasStopped: false);
    final batch = await _resolveItems(items, generation, forceDetails: true);
    if (!_isCurrent(generation) || batch == null) return;
    for (final item in items) {
      final pid = item.pid;
      final resolved = batch.resolvedItems[pid];
      if (resolved != null) {
        _rawItems[pid] = resolved;
        _detailFailures.remove(pid);
        if (_filter.matches(resolved)) _resultItems[pid] = resolved;
      }
      final failure = batch.failures[pid];
      if (failure != null) _detailFailures[pid] = failure;
    }
    _publish(
      isBusy: false,
      items: _orderedResults,
      failedDetails: _detailFailures.length,
      error: batch.authExpired ? 'Pixiv session has expired' : null,
      clearError: !batch.authExpired,
    );
  }

  void stop() {
    if (!_state.isBusy || _disposed) return;
    ++_generation;
    _publish(isBusy: false, wasStopped: true);
  }

  void toggleSelection(SearchItem item) {
    final selected = {..._state.selectedPids};
    if (!selected.add(item.pid)) selected.remove(item.pid);
    _publish(selectedPids: selected);
  }

  void selectLoaded() {
    _publish(selectedPids: _resultItems.keys.toSet());
  }

  void clearSelection() {
    _publish(selectedPids: const <String>{});
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }

  Future<void> _scan(int generation) async {
    var pagesThisScan = 0;
    var foundMatch = false;
    while (_isCurrent(generation) &&
        pagesThisScan < maxPagesPerScan &&
        _hasMoreOrInitialPage) {
      final page = _nextPage;
      final query = _query!.copyWith(page: page);
      late final PageResult<SearchItem> response;
      try {
        response = await _apiProvider().search(query);
      } on Object catch (error) {
        if (_isCurrent(generation)) {
          _publish(isBusy: false, error: _errorText(error));
        }
        return;
      }
      if (!_isCurrent(generation)) return;
      final processed = await _processPage(response.items, generation);
      if (!_isCurrent(generation) || processed == null) return;
      if (processed.authExpired) {
        _publish(isBusy: false, error: 'Pixiv session has expired');
        return;
      }

      _seenPids.addAll(processed.rawItems.keys);
      _rawItems.addAll(processed.rawItems);
      _resultItems.addAll(processed.matchedItemsByPid);
      _detailFailures.addAll(processed.failures);
      _nextPage = page + 1;
      _hasMore = response.hasMore;
      pagesThisScan++;
      foundMatch = foundMatch || processed.matchedItemsByPid.isNotEmpty;
      _publish(
        items: _orderedResults,
        isBusy: true,
        hasMore: _hasMore,
        nextPage: _nextPage,
        checkedPages: _state.checkedPages + 1,
        scannedWorks: _state.scannedWorks + response.items.length,
        serverTotal: response.total,
        failedDetails: _detailFailures.length,
      );

      if (!_filter.hasThreshold || foundMatch || !response.hasMore) {
        break;
      }
    }
    if (_isCurrent(generation)) {
      _publish(
        isBusy: false,
        hasMore: _hasMore,
        nextPage: _nextPage,
        failedDetails: _detailFailures.length,
      );
    }
  }

  bool get _hasMoreOrInitialPage => _nextPage == 1 || _hasMore;

  Future<_ProcessedPage?> _processPage(
    List<SearchItem> pageItems,
    int generation,
  ) async {
    final unseen = <SearchItem>[];
    final raw = <String, SearchItem>{};
    for (final item in pageItems) {
      if (item.pid.isEmpty || _seenPids.contains(item.pid)) continue;
      if (!raw.containsKey(item.pid)) {
        raw[item.pid] = item;
        unseen.add(item);
      }
    }
    if (!_filter.hasThreshold) {
      final matched = <String, SearchItem>{
        for (final item in unseen) item.pid: item,
      };
      return _ProcessedPage(
        rawItems: raw,
        matchedItemsByPid: matched,
        resolvedItems: matched,
        failures: const {},
        authExpired: false,
      );
    }

    final batch = await _resolveItems(unseen, generation);
    if (!_isCurrent(generation) || batch == null) return null;
    final matched = <String, SearchItem>{};
    for (final item in unseen) {
      final resolved = batch.resolvedItems[item.pid];
      if (resolved != null && _filter.matches(resolved)) {
        matched[item.pid] = resolved;
      }
    }
    return _ProcessedPage(
      rawItems: raw,
      matchedItemsByPid: matched,
      resolvedItems: batch.resolvedItems,
      failures: batch.failures,
      authExpired: batch.authExpired,
    );
  }

  Future<_ResolvedBatch?> _resolveItems(
    List<SearchItem> items,
    int generation, {
    bool forceDetails = false,
  }) async {
    final resolved = <String, SearchItem>{};
    final pending = <SearchItem>[];
    for (final item in items) {
      final cached = forceDetails ? null : _takeCached(item.pid);
      if (cached != null) {
        final merged = _merge(item, cached);
        if (_requiredCountsKnown(merged)) {
          resolved[item.pid] = merged;
          continue;
        }
      }
      if (_requiredCountsKnown(item) && !forceDetails) {
        resolved[item.pid] = item;
      } else {
        pending.add(item);
      }
    }
    final failures = <String, String>{};
    var authExpired = false;
    var cursor = 0;
    Future<void> worker() async {
      while (_isCurrent(generation)) {
        if (authExpired || cursor >= pending.length) return;
        final item = pending[cursor++];
        await _acquireDetailPermit();
        try {
          if (!_isCurrent(generation) || authExpired) return;
          final detail = await _apiProvider().getIllust(item.pid);
          if (!_isCurrent(generation)) return;
          final merged = _merge(item, detail);
          _cacheDetail(detail);
          if (_requiredCountsKnown(merged)) {
            resolved[item.pid] = merged;
          } else {
            failures[item.pid] = 'Popularity count is unavailable';
          }
        } on PixivHttpException catch (error) {
          if (error.errorCode == DownloadErrorCode.authExpired) {
            authExpired = true;
          }
          failures[item.pid] = error.message;
        } on Object catch (error) {
          failures[item.pid] = _errorText(error);
        } finally {
          _releaseDetailPermit();
        }
      }
    }

    final workerCount = pending.length < maxDetailConcurrency
        ? pending.length
        : maxDetailConcurrency;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    if (!_isCurrent(generation)) return null;
    return _ResolvedBatch(
      resolvedItems: resolved,
      failures: failures,
      authExpired: authExpired,
    );
  }

  SearchItem _merge(SearchItem item, IllustDetail detail) => item.copyWith(
    title: detail.title.isEmpty ? null : detail.title,
    authorId: detail.authorId.isEmpty ? null : detail.authorId,
    authorName: detail.authorName.isEmpty ? null : detail.authorName,
    pageCount: detail.pageCount > 0 ? detail.pageCount : null,
    type: detail.type,
    thumbnailUrl: detail.thumbnailUrl.isEmpty ? null : detail.thumbnailUrl,
    likeCount: detail.likeCount ?? item.likeCount,
    bookmarkCount: detail.bookmarkCount ?? item.bookmarkCount,
  );

  Future<void> _acquireDetailPermit() {
    if (_activeDetailRequests < maxDetailConcurrency) {
      _activeDetailRequests++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _detailWaiters.add(waiter);
    return waiter.future;
  }

  void _releaseDetailPermit() {
    if (_detailWaiters.isNotEmpty) {
      _detailWaiters.removeFirst().complete();
    } else {
      _activeDetailRequests--;
    }
  }

  bool _requiredCountsKnown(SearchItem item) {
    if (_filter.minLikeCount != null &&
        _filter.minLikeCount! > 0 &&
        item.likeCount == null) {
      return false;
    }
    if (_filter.minBookmarkCount != null &&
        _filter.minBookmarkCount! > 0 &&
        item.bookmarkCount == null) {
      return false;
    }
    return true;
  }

  IllustDetail? _takeCached(String pid) {
    final detail = _detailCache.remove(pid);
    if (detail != null) _detailCache[pid] = detail;
    return detail;
  }

  void _cacheDetail(IllustDetail detail) {
    _detailCache.remove(detail.pid);
    _detailCache[detail.pid] = detail;
    while (_detailCache.length > maxDetailCacheEntries) {
      _detailCache.remove(_detailCache.keys.first);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  static bool _validThreshold(int? value) => value == null || value >= 0;

  static String _errorText(Object error) {
    if (error is PixivHttpException &&
        error.errorCode == DownloadErrorCode.authExpired) {
      return 'Pixiv session has expired';
    }
    if (error is FormatException && error.message.isNotEmpty) {
      return error.message;
    }
    return error.toString();
  }

  void _publish({
    SearchQuery? query,
    SearchFilter? filter,
    List<SearchItem>? items,
    Set<String>? selectedPids,
    bool? isBusy,
    bool? hasMore,
    int? nextPage,
    int? checkedPages,
    int? scannedWorks,
    int? serverTotal,
    int? failedDetails,
    bool? wasStopped,
    String? error,
    bool clearError = false,
  }) {
    if (_disposed) return;
    final old = _state;
    _state = SearchControllerState(
      query: query ?? old.query,
      filter: filter ?? old.filter,
      items: items ?? old.items,
      selectedPids: selectedPids == null
          ? old.selectedPids
          : Set.unmodifiable(selectedPids),
      isBusy: isBusy ?? old.isBusy,
      hasMore: hasMore ?? old.hasMore,
      nextPage: nextPage ?? old.nextPage,
      checkedPages: checkedPages ?? old.checkedPages,
      scannedWorks: scannedWorks ?? old.scannedWorks,
      serverTotal: serverTotal ?? old.serverTotal,
      failedDetails: failedDetails ?? old.failedDetails,
      wasStopped: wasStopped ?? old.wasStopped,
      error: clearError ? null : error ?? old.error,
    );
    notifyListeners();
  }
}

class _ProcessedPage {
  const _ProcessedPage({
    required this.rawItems,
    required this.matchedItemsByPid,
    required this.resolvedItems,
    required this.failures,
    required this.authExpired,
  });

  final Map<String, SearchItem> rawItems;
  final Map<String, SearchItem> matchedItemsByPid;
  final Map<String, SearchItem> resolvedItems;
  final Map<String, String> failures;
  final bool authExpired;
}

class _ResolvedBatch {
  const _ResolvedBatch({
    required this.resolvedItems,
    required this.failures,
    required this.authExpired,
  });

  final Map<String, SearchItem> resolvedItems;
  final Map<String, String> failures;
  final bool authExpired;
}
