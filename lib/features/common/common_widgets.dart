import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../app/app_services.dart';
import '../../infrastructure/network/pixiv_http_client.dart';
import '../../l10n/app_localizations.dart';
import '../auth/web_login_dialog.dart';

Future<Uint8List> loadPixivImageBytes(
  PixivHttpClient client,
  String url,
) async {
  if (url.isEmpty) throw StateError('Thumbnail URL is empty');
  final normalized = url.startsWith('//') ? 'https:$url' : url;
  final response = await client.open(
    'GET',
    Uri.parse(normalized),
    requireAuth: false,
    retry: true,
    headers: const {
      HttpHeaders.acceptHeader: 'image/avif,image/webp,image/*,*/*;q=0.8',
    },
  );
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  final result = builder.takeBytes();
  if (result.isEmpty) throw StateError('Thumbnail response is empty');
  return result;
}

class PixivImage extends StatefulWidget {
  const PixivImage({
    required this.url,
    required this.client,
    this.fit = BoxFit.cover,
    this.errorIconSize = 48,
    super.key,
  });

  final String url;
  final PixivHttpClient client;
  final BoxFit fit;
  final double errorIconSize;

  @override
  State<PixivImage> createState() => _PixivImageState();
}

class _PixivImageState extends State<PixivImage> {
  static const _maximumEntries = 128;
  static final LinkedHashMap<String, Future<Uint8List>> _cache =
      LinkedHashMap();

  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _obtain();
  }

  @override
  void didUpdateWidget(covariant PixivImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.client != widget.client) {
      _bytes = _obtain();
    }
  }

  Future<Uint8List> _obtain() {
    final key = '${identityHashCode(widget.client)}:${widget.url}';
    final existing = _cache.remove(key);
    if (existing != null) {
      _cache[key] = existing;
      return existing;
    }
    final future = _download(key);
    _cache[key] = future;
    while (_cache.length > _maximumEntries) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List> _download(String cacheKey) async {
    try {
      return await loadPixivImageBytes(widget.client, widget.url);
    } on Object {
      _cache.remove(cacheKey);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      }
      if (snapshot.hasError) {
        return Tooltip(
          message: snapshot.error.toString(),
          child: Center(
            child: Icon(Icons.broken_image, size: widget.errorIconSize),
          ),
        );
      }
      return const ColoredBox(
        color: Color(0x0AFFFFFF),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    },
  );
}

class FeaturePage extends StatelessWidget {
  const FeaturePage({
    required this.title,
    required this.child,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class AccountRequired extends StatelessWidget {
  const AccountRequired({
    required this.services,
    required this.child,
    super.key,
  });

  final AppServices services;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: services.accountState,
    builder: (context, account, _) {
      if (account != null) return child;
      return Center(
        child: FilledButton.icon(
          onPressed: () => signInWithWebView(context, services),
          icon: const Icon(Icons.login),
          label: Text(AppLocalizations.of(context).signIn),
        ),
      );
    },
  );
}

Future<void> signInWithWebView(
  BuildContext context,
  AppServices services,
) async {
  if (Platform.isWindows) {
    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      if (version == null || version.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).webView2Missing),
            ),
          );
        }
        return;
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).webView2Missing)),
        );
      }
      return;
    }
  }
  if (!context.mounted) return;
  final cookie = await WebLoginDialog.show(context);
  if (cookie == null || !context.mounted) return;
  try {
    await services.loginWithCookie(cookie);
    await services.downloads.resumeAll();
  } on Object catch (error) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signIn),
        content: SelectableText(l10n.operationFailed(error.toString())),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
