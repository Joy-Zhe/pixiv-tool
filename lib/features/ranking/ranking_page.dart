import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  RankingMode _mode = RankingMode.daily;
  RankingContent _content = RankingContent.all;
  bool _r18 = false;
  final _previewPage = TextEditingController(text: '1');
  final _start = TextEditingController(text: '1');
  final _end = TextEditingController(text: '1');
  final _selected = <String, RankingItem>{};
  List<RankingItem> _items = const [];
  int _loadedPage = 1;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _previewPage.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  RankingQuery _query(int start, int end) => RankingQuery(
    mode: _mode,
    content: _content,
    r18: _r18,
    startPage: start,
    endPage: end,
  );

  void _filterChanged(VoidCallback update) {
    setState(() {
      update();
      _items = const [];
      _error = null;
    });
  }

  Future<void> _loadPreview([int? requestedPage]) async {
    final page = requestedPage ?? int.tryParse(_previewPage.text);
    if (page == null || page < 1) {
      setState(() => _error = AppLocalizations.of(context).invalidPageRange);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(appServicesProvider)
          .api
          .getRanking(_query(page, page));
      if (mounted) {
        setState(() {
          _items = result.items;
          _loadedPage = page;
          _previewPage.text = '$page';
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enqueueItems(List<RankingItem> items) async {
    final services = ref.read(appServicesProvider);
    final prefix = '${_mode.name}${_r18 ? '_r18' : ''}/${_content.name}';
    await services.downloads.enqueue(
      DownloadRequest(
        source: DownloadSource.ranking,
        rootPath: services.preferenceState.value!.rankingRoot,
        accountId: services.accountState.value?.profile.id,
        pathPrefix: prefix,
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
            .toList(growable: false),
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
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _enqueueItems(_selected.values.toList(growable: false));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadRange() async {
    final start = int.tryParse(_start.text);
    final end = int.tryParse(_end.text);
    if (start == null || end == null || start < 1 || end < start) {
      setState(() => _error = AppLocalizations.of(context).invalidPageRange);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(appServicesProvider)
          .api
          .getRanking(_query(start, end));
      await _enqueueItems(result.items);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(RankingItem item) {
    setState(() {
      if (_selected.containsKey(item.pid)) {
        _selected.remove(item.pid);
      } else {
        _selected[item.pid] = item;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final l10n = AppLocalizations.of(context);
    return FeaturePage(
      title: l10n.ranking,
      child: AccountRequired(
        services: services,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<RankingMode>(
                  segments: [
                    ButtonSegment(
                      value: RankingMode.daily,
                      label: Text(l10n.daily),
                    ),
                    ButtonSegment(
                      value: RankingMode.weekly,
                      label: Text(l10n.weekly),
                    ),
                    ButtonSegment(
                      value: RankingMode.monthly,
                      label: Text(l10n.monthly),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => _filterChanged(() => _mode = value.single),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<RankingContent>(
                    initialValue: _content,
                    decoration: InputDecoration(labelText: l10n.content),
                    items: [
                      DropdownMenuItem(
                        value: RankingContent.all,
                        child: Text(l10n.all),
                      ),
                      DropdownMenuItem(
                        value: RankingContent.illust,
                        child: Text(l10n.illust),
                      ),
                      DropdownMenuItem(
                        value: RankingContent.manga,
                        child: Text(l10n.manga),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => _filterChanged(() => _content = value!),
                  ),
                ),
                FilterChip(
                  selected: _r18,
                  label: Text(l10n.r18),
                  onSelected: _busy
                      ? null
                      : (value) => _filterChanged(() => _r18 = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _previewPage,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.previewPage),
                    onSubmitted: (_) => _loadPreview(),
                  ),
                ),
                IconButton.outlined(
                  tooltip: l10n.previousPage,
                  onPressed: _busy || _loadedPage <= 1
                      ? null
                      : () => _loadPreview(_loadedPage - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _loadPreview,
                  icon: const Icon(Icons.preview),
                  label: Text(l10n.preview),
                ),
                IconButton.outlined(
                  tooltip: l10n.nextPage,
                  onPressed: _busy ? null : () => _loadPreview(_loadedPage + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 6),
                Text(l10n.selectedCount(_selected.length)),
                OutlinedButton(
                  onPressed: _items.isEmpty
                      ? null
                      : () => setState(
                          () => _selected.addEntries(
                            _items.map((item) => MapEntry(item.pid, item)),
                          ),
                        ),
                  child: Text(l10n.selectLoaded),
                ),
                OutlinedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  child: Text(l10n.clearSelection),
                ),
                FilledButton(
                  onPressed: _selected.isEmpty || _busy
                      ? null
                      : _downloadSelected,
                  child: Text(l10n.downloadSelected),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.startPage),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _end,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.endPage),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _downloadRange,
                  icon: const Icon(Icons.download_for_offline),
                  label: Text(l10n.downloadPageRange),
                ),
                if (_busy)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? Center(child: Text(l10n.noItems))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisExtent: 330,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = _selected.containsKey(item.pid);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _toggle(item),
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
                                      ),
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Chip(
                                          label: Text(
                                            l10n.rankNumber(item.rank),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Checkbox(
                                          value: selected,
                                          onChanged: (_) => _toggle(item),
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
                                        item.authorName,
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
