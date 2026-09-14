import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';
import 'search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final PixivSearchController _controller;
  late final VoidCallback _accountListener;
  late final ValueNotifier<AccountSession?> _accountState;
  final _keyword = TextEditingController();
  final _minLikes = TextEditingController();
  final _minBookmarks = TextEditingController();
  SearchMode _mode = SearchMode.tagPartial;
  bool _includeAi = false;
  bool _includeR18 = false;
  String? _accountId;
  bool _queueing = false;
  String? _queueError;

  @override
  void initState() {
    super.initState();
    _controller = PixivSearchController(
      apiProvider: () => ref.read(appServicesProvider).api,
    );
    _accountListener = _accountChanged;
    _accountState = ref.read(appServicesProvider).accountState;
    _accountState.addListener(_accountListener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _accountChanged());
  }

  @override
  void dispose() {
    _accountState.removeListener(_accountListener);
    _controller.dispose();
    _keyword.dispose();
    _minLikes.dispose();
    _minBookmarks.dispose();
    super.dispose();
  }

  void _accountChanged() {
    if (!mounted) return;
    final account = _accountState.value;
    final nextId = account?.profile.id;
    if (nextId == _accountId) {
      if (nextId == null) _controller.stop();
      return;
    }
    _accountId = nextId;
    _controller.reset();
    _queueError = null;
    if (mounted) setState(() {});
  }

  int? _threshold(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) return -1;
    return parsed == 0 ? null : parsed;
  }

  Future<void> _search() async {
    if (_keyword.text.trim().isEmpty) {
      setState(
        () => _queueError = AppLocalizations.of(context).searchKeywordRequired,
      );
      return;
    }
    final likes = _threshold(_minLikes);
    final bookmarks = _threshold(_minBookmarks);
    if (likes == -1 || bookmarks == -1) {
      setState(
        () => _queueError = AppLocalizations.of(context).invalidPopularity,
      );
      return;
    }
    setState(() => _queueError = null);
    await _controller.search(
      SearchQuery(
        keyword: _keyword.text,
        mode: _mode,
        includeAi: _includeAi,
        includeR18: _includeR18,
      ),
      SearchFilter(minLikeCount: likes, minBookmarkCount: bookmarks),
    );
  }

  Future<void> _enqueueSelected() async {
    final selected = _controller.selectedItems;
    if (selected.isEmpty || _queueing) return;
    final services = ref.read(appServicesProvider);
    setState(() {
      _queueing = true;
      _queueError = null;
    });
    try {
      await services.downloads.enqueue(
        DownloadRequest(
          source: DownloadSource.search,
          rootPath: services.preferenceState.value!.pidRoot,
          accountId: services.accountState.value?.profile.id,
          candidates: selected
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
            content: Text(
              AppLocalizations.of(context).queuedWorks(selected.length),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _queueError = error.toString());
    } finally {
      if (mounted) setState(() => _queueing = false);
    }
  }

  String _count(int? value) => value?.toString() ?? '—';

  String? _displayError(AppLocalizations l10n, String? error) {
    if (error == null) return null;
    if (error == 'Pixiv session has expired') return l10n.sessionExpired;
    return error;
  }

  String _modeLabel(AppLocalizations l10n, SearchMode mode) => switch (mode) {
    SearchMode.tagPartial => l10n.searchTagPartial,
    SearchMode.tagExact => l10n.searchTagExact,
    SearchMode.titleOrDescription => l10n.searchTitleDescription,
  };

  Widget _buildCard(
    BuildContext context,
    AppLocalizations l10n,
    SearchControllerState state,
    SearchItem item,
  ) {
    final services = ref.read(appServicesProvider);
    final selected = state.selectedPids.contains(item.pid);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _controller.toggleSelection(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PixivImage(url: item.thumbnailUrl, client: services.http),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => _controller.toggleSelection(item),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'PID ${item.pid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l10n.likeCountLabel}: ${_count(item.likeCount)} · '
                    '${l10n.bookmarkCountLabel}: ${_count(item.bookmarkCount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final l10n = AppLocalizations.of(context);
    return FeaturePage(
      title: l10n.search,
      child: AccountRequired(
        services: services,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final state = _controller.state;
            final hasItems = state.items.isNotEmpty;
            final error = _queueError ?? _displayError(l10n, state.error);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _keyword,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: l10n.searchKeyword,
                          hintText: l10n.searchKeywordHint,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<SearchMode>(
                        initialValue: _mode,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.searchMode),
                        items: [
                          for (final mode in SearchMode.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(
                                _modeLabel(l10n, mode),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: state.isBusy
                            ? null
                            : (value) {
                                if (value != null)
                                  setState(() => _mode = value);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _minLikes,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.minLikes),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _minBookmarks,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.minBookmarks,
                        ),
                      ),
                    ),
                    FilterChip(
                      selected: _includeAi,
                      label: Text(l10n.includeAiWorks),
                      onSelected: state.isBusy
                          ? null
                          : (value) => setState(() => _includeAi = value),
                    ),
                    FilterChip(
                      selected: _includeR18,
                      label: Text(l10n.includeR18Works),
                      onSelected: state.isBusy
                          ? null
                          : (value) => setState(() => _includeR18 = value),
                    ),
                    FilledButton.icon(
                      onPressed: state.isBusy ? null : _search,
                      icon: const Icon(Icons.search),
                      label: Text(l10n.searchAction),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.isBusy ? _controller.stop : null,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(l10n.stopSearch),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (state.hasQuery)
                      Text(
                        l10n.searchProgress(
                          state.checkedPages,
                          state.scannedWorks,
                        ),
                      ),
                    if (state.serverTotal > 0)
                      Text(l10n.searchServerTotal(state.serverTotal)),
                    Text(l10n.searchResultCount(state.items.length)),
                    Text(l10n.selectedCount(state.selectedPids.length)),
                    OutlinedButton(
                      onPressed: hasItems ? _controller.selectLoaded : null,
                      child: Text(l10n.selectLoaded),
                    ),
                    OutlinedButton(
                      onPressed: state.selectedPids.isEmpty
                          ? null
                          : _controller.clearSelection,
                      child: Text(l10n.clearSelection),
                    ),
                    FilledButton(
                      onPressed: state.selectedPids.isEmpty || _queueing
                          ? null
                          : _enqueueSelected,
                      child: Text(l10n.downloadSelected),
                    ),
                    if (state.canContinue)
                      FilledButton.tonalIcon(
                        onPressed: _controller.loadMore,
                        icon: const Icon(Icons.more_horiz),
                        label: Text(l10n.continueSearch),
                      ),
                    if (state.failedDetails > 0)
                      OutlinedButton.icon(
                        onPressed: state.isBusy
                            ? null
                            : _controller.retryFailedDetails,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          l10n.searchDetailsFailed(state.failedDetails),
                        ),
                      ),
                    if (state.isBusy)
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: hasItems
                      ? GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 280,
                                mainAxisExtent: 350,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) => _buildCard(
                            context,
                            l10n,
                            state,
                            state.items[index],
                          ),
                        )
                      : Center(
                          child: state.isBusy
                              ? const CircularProgressIndicator()
                              : Text(
                                  state.hasQuery
                                      ? l10n.noSearchResults
                                      : l10n.searchHint,
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
