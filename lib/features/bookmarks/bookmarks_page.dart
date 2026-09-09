import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  final _scroll = ScrollController();
  final _selected = <String, BookmarkItem>{};
  StreamSubscription<List<BookmarkItem>>? _cacheSubscription;
  List<BookmarkItem> _items = const [];
  BookmarkVisibility _visibility = BookmarkVisibility.public;
  IllustType? _type;
  String _tag = '';
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  String? _accountId;
  int _filterGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    ref.read(appServicesProvider).accountState.addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _accountChanged());
  }

  @override
  void dispose() {
    ref.read(appServicesProvider).accountState.removeListener(_accountChanged);
    _cacheSubscription?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  BookmarkFilter? get _filter {
    final account = ref.read(appServicesProvider).accountState.value;
    if (account == null) return null;
    return BookmarkFilter(
      accountId: account.profile.id,
      visibility: _visibility,
      tag: _tag,
      type: _type,
    );
  }

  void _accountChanged() {
    _filterGeneration++;
    _loading = false;
    _error = null;
    _cacheSubscription?.cancel();
    final filter = _filter;
    if (filter == null) {
      if (mounted) {
        setState(() {
          _accountId = null;
          _selected.clear();
          _items = const [];
        });
      }
      return;
    }
    if (_accountId != filter.accountId) {
      _accountId = filter.accountId;
      _selected.clear();
    }
    _cacheSubscription = ref
        .read(appServicesProvider)
        .bookmarks
        .watchCached(filter)
        .listen((items) {
          if (mounted) setState(() => _items = items);
        });
    _offset = 0;
    _hasMore = true;
    unawaited(_refresh());
  }

  void _changeFilter() => _accountChanged();

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 500) {
      unawaited(_loadMore());
    }
  }

  Future<void> _refresh() async {
    final filter = _filter;
    if (filter == null || _loading) return;
    final generation = _filterGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(appServicesProvider)
          .bookmarks
          .refreshFirstPage(filter);
      if (generation == _filterGeneration) {
        _offset = result.items.length;
        _hasMore = result.hasMore;
      }
    } on Object catch (error) {
      if (mounted && generation == _filterGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _filterGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final filter = _filter;
    if (filter == null || _loading || !_hasMore) return;
    final generation = _filterGeneration;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(appServicesProvider)
          .bookmarks
          .loadPage(filter, _offset);
      if (generation == _filterGeneration) {
        _offset += result.items.length;
        _hasMore = result.hasMore;
      }
    } on Object catch (error) {
      if (mounted && generation == _filterGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _filterGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _syncAll() async {
    final filter = _filter;
    if (filter == null || _loading) return;
    final generation = _filterGeneration;
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(appServicesProvider)
          .bookmarks
          .syncAll(filter);
      if (generation == _filterGeneration) {
        _offset = result.received;
        _hasMore = false;
      }
      if (mounted && generation == _filterGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)
                  .syncSummary(result.received, result.removed),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted && generation == _filterGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _filterGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enqueue(List<BookmarkItem> items, DownloadSource source) async {
    final services = ref.read(appServicesProvider);
    await services.downloads.enqueue(
      DownloadRequest(
        source: source,
        rootPath: services.preferenceState.value!.bookmarkRoot,
        accountId: services.accountState.value?.profile.id,
        candidates: items
            .map(
              (item) => DownloadCandidate(
                pid: item.pid,
                title: item.title,
                authorId: item.authorId,
                authorName: item.authorName,
                type: item.type,
              ),
            )
            .toList(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).queuedWorks(items.length)),
        ),
      );
    }
  }

  Future<void> _downloadSelected() async {
    await _enqueue(_selected.values.toList(), DownloadSource.bookmarkSelection);
  }

  Future<void> _downloadFiltered() async {
    final filter = _filter;
    if (filter == null) return;
    setState(() => _loading = true);
    try {
      final items = await ref
          .read(appServicesProvider)
          .bookmarks
          .snapshotAll(filter);
      await _enqueue(items, DownloadSource.bookmarkBatch);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final l10n = AppLocalizations.of(context);
    final tags = _items.expand((item) => item.tags).toSet().toList()..sort();
    return FeaturePage(
      title: l10n.bookmarks,
      actions: [
        IconButton(
          tooltip: l10n.refresh,
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _syncAll,
          icon: const Icon(Icons.sync),
          label: Text(l10n.syncAll),
        ),
        const SizedBox(width: 12),
      ],
      child: AccountRequired(
        services: services,
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<BookmarkVisibility>(
                  segments: [
                    ButtonSegment(
                      value: BookmarkVisibility.public,
                      label: Text(l10n.publicBookmarks),
                    ),
                    ButtonSegment(
                      value: BookmarkVisibility.private,
                      label: Text(l10n.privateBookmarks),
                    ),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (value) {
                    setState(() => _visibility = value.single);
                    _changeFilter();
                  },
                ),
                DropdownButton<IllustType?>(
                  value: _type,
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.all)),
                    DropdownMenuItem(
                      value: IllustType.illust,
                      child: Text(l10n.illust),
                    ),
                    DropdownMenuItem(
                      value: IllustType.manga,
                      child: Text(l10n.manga),
                    ),
                    DropdownMenuItem(
                      value: IllustType.ugoira,
                      child: Text(l10n.ugoira),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _type = value);
                    _changeFilter();
                  },
                ),
                DropdownButton<String>(
                  value: tags.contains(_tag) ? _tag : '',
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.filterTag)),
                    ...tags.map(
                      (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _tag = value ?? '');
                    _changeFilter();
                  },
                ),
                Text(l10n.selectedCount(_selected.length)),
                OutlinedButton(
                  onPressed: () => setState(
                    () => _selected.addEntries(
                      _items.map((item) => MapEntry(item.pid, item)),
                    ),
                  ),
                  child: Text(l10n.selectLoaded),
                ),
                OutlinedButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(l10n.clearSelection),
                ),
                FilledButton(
                  onPressed: _selected.isEmpty ? null : _downloadSelected,
                  child: Text(l10n.downloadSelected),
                ),
                FilledButton.tonal(
                  onPressed: _loading ? null : _downloadFiltered,
                  child: Text(l10n.downloadFiltered),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? Center(child: Text(l10n.noItems))
                  : GridView.builder(
                      controller: _scroll,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisExtent: 330,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _items.length + (_loading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final item = _items[index];
                        final selected = _selected.containsKey(item.pid);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => setState(
                              () => selected
                                  ? _selected.remove(item.pid)
                                  : _selected[item.pid] = item,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PixivImage(
                                        url: item.thumbnailUrl,
                                        client: services.http,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Checkbox(
                                          value: selected,
                                          onChanged: (_) => setState(
                                            () => selected
                                                ? _selected.remove(item.pid)
                                                : _selected[item.pid] = item,
                                          ),
                                        ),
                                      ),
                                      if (item.type == IllustType.ugoira)
                                        Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: Chip(
                                            label: Text(l10n.ugoiraUnsupported),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${item.authorName} · ${item.pageCount}p',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'PID ${item.pid}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
