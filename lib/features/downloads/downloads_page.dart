import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(appServicesProvider).downloads;
    final l10n = AppLocalizations.of(context);
    return FeaturePage(
      title: l10n.downloads,
      actions: [
        TextButton.icon(
          onPressed: queue.pauseAll,
          icon: const Icon(Icons.pause),
          label: Text(l10n.pauseAll),
        ),
        TextButton.icon(
          onPressed: queue.resumeAll,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.resumeAll),
        ),
        const SizedBox(width: 12),
      ],
      child: StreamBuilder<DownloadQueueSnapshot>(
        stream: queue.watch(),
        builder: (context, snapshot) {
          final value = snapshot.data;
          if (value == null)
            return const Center(child: CircularProgressIndicator());
          if (value.jobs.isEmpty) return Center(child: Text(l10n.noItems));
          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 16,
                  children: [
                    Text('${_bytes(value.bytesPerSecond)}/s'),
                    Text(l10n.tasksCount(value.jobs.length)),
                    Text(
                      l10n.completedCount(
                        _count(value, DownloadStatus.completed),
                      ),
                    ),
                    Text(
                      l10n.failedCount(_count(value, DownloadStatus.failed)),
                    ),
                    Text(
                      l10n.skippedCount(_count(value, DownloadStatus.skipped)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: value.jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _DownloadTile(job: value.jobs[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _bytes(int value) {
    if (value >= 1024 * 1024)
      return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }

  static int _count(DownloadQueueSnapshot value, DownloadStatus status) =>
      value.jobs.where((job) => job.status == status).length;
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.job});

  final DownloadJobView job;

  Future<void> _open(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    }
  }

  Future<void> _remove(BuildContext context, DownloadQueue queue) async {
    final l10n = AppLocalizations.of(context);
    final deletePartial = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeTaskTitle),
        content: Text(l10n.removeTaskBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepPartialFiles),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deletePartialFiles),
          ),
        ],
      ),
    );
    if (deletePartial != null) {
      await queue.remove(job.id, deletePartialFiles: deletePartial);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(appServicesProvider).downloads;
    final l10n = AppLocalizations.of(context);
    final resumable = {
      DownloadStatus.paused,
      DownloadStatus.failed,
      DownloadStatus.cancelled,
      DownloadStatus.waitingForAuth,
    }.contains(job.status);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            job.completedFiles == job.totalFiles && job.totalFiles > 0
                ? '✓'
                : '${job.completedFiles}',
          ),
        ),
        title: Text(job.title.isEmpty ? 'PID ${job.pid}' : job.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.firstFilePath != null &&
                job.status == DownloadStatus.completed)
              IconButton(
                tooltip: l10n.openFile,
                onPressed: () => _open(job.firstFilePath!),
                icon: const Icon(Icons.open_in_new),
              ),
            IconButton(
              tooltip: l10n.openFolder,
              onPressed: () => _open(job.rootPath),
              icon: const Icon(Icons.folder_open),
            ),
            Text(
              'PID ${job.pid} · ${_statusName(l10n, job.status)} · '
              '${job.completedFiles}/${job.totalFiles}',
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: job.progress.clamp(0, 1)),
            if (job.errorMessage.isNotEmpty)
              Text(
                job.errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        trailing: Wrap(
          children: [
            if (job.status == DownloadStatus.downloading ||
                job.status == DownloadStatus.pending)
              IconButton(
                tooltip: l10n.pause,
                onPressed: () => queue.pause(job.id),
                icon: const Icon(Icons.pause),
              ),
            if (resumable)
              IconButton(
                tooltip: l10n.resume,
                onPressed: () => queue.resume(job.id),
                icon: const Icon(Icons.play_arrow),
              ),
            if (job.status == DownloadStatus.downloading ||
                job.status == DownloadStatus.pending)
              IconButton(
                tooltip: l10n.cancel,
                onPressed: () => queue.cancel(job.id),
                icon: const Icon(Icons.stop),
              ),
            IconButton(
              tooltip: l10n.remove,
              onPressed: () => _remove(context, queue),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  String _statusName(AppLocalizations l10n, DownloadStatus status) =>
      switch (status) {
        DownloadStatus.pending => l10n.statusPending,
        DownloadStatus.resolving => l10n.statusResolving,
        DownloadStatus.downloading => l10n.statusDownloading,
        DownloadStatus.paused => l10n.statusPaused,
        DownloadStatus.waitingForAuth => l10n.statusWaitingForAuth,
        DownloadStatus.completed => l10n.statusCompleted,
        DownloadStatus.failed => l10n.statusFailed,
        DownloadStatus.cancelled => l10n.statusCancelled,
        DownloadStatus.skipped => l10n.statusSkipped,
      };
}
