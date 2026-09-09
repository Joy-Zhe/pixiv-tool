import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';

class PidPage extends ConsumerStatefulWidget {
  const PidPage({super.key});

  @override
  ConsumerState<PidPage> createState() => _PidPageState();
}

class _PidPageState extends ConsumerState<PidPage> {
  final _controller = TextEditingController();
  IllustDetail? _preview;
  bool _busy = false;
  String? _error;

  bool get _valid => RegExp(r'^\d+$').hasMatch(_controller.text.trim());

  Future<void> _loadPreview() async {
    if (!_valid) {
      setState(() => _error = AppLocalizations.of(context).invalidPid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(appServicesProvider)
          .api
          .getIllust(_controller.text.trim());
      if (mounted) setState(() => _preview = detail);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    if (!_valid) return _loadPreview();
    final services = ref.read(appServicesProvider);
    try {
      final detail = _preview?.pid == _controller.text.trim()
          ? _preview!
          : await services.api.getIllust(_controller.text.trim());
      final preferences = services.preferenceState.value!;
      await services.downloads.enqueue(
        DownloadRequest(
          source: DownloadSource.pid,
          rootPath: preferences.pidRoot,
          accountId: services.accountState.value?.profile.id,
          candidates: [
            DownloadCandidate(
              pid: detail.pid,
              title: detail.title,
              authorId: detail.authorId,
              authorName: detail.authorName,
              type: detail.type,
            ),
          ],
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).addedToQueue)),
        );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final l10n = AppLocalizations.of(context);
    return FeaturePage(
      title: l10n.pid,
      child: AccountRequired(
        services: services,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.pid,
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _loadPreview(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _loadPreview,
                      icon: const Icon(Icons.visibility),
                      label: Text(l10n.preview),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _download,
                      icon: const Icon(Icons.download),
                      label: Text(l10n.download),
                    ),
                    if (_busy) ...[
                      const SizedBox(width: 16),
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (_preview case final detail?)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: PixivImage(
                            url: detail.thumbnailUrl,
                            client: services.http,
                            fit: BoxFit.cover,
                            errorIconSize: 64,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  detail.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${detail.authorName} · ${l10n.pagesCount(detail.pageCount)}',
                                ),
                                Text(
                                  'PID ${detail.pid} · ${switch (detail.type) {
                                    IllustType.illust => l10n.illust,
                                    IllustType.manga => l10n.manga,
                                    IllustType.ugoira => l10n.ugoira,
                                  }}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
