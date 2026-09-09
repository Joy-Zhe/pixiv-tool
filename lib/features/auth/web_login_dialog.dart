import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../l10n/app_localizations.dart';

class WebLoginDialog extends StatefulWidget {
  const WebLoginDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const WebLoginDialog(),
  );

  @override
  State<WebLoginDialog> createState() => _WebLoginDialogState();
}

class _WebLoginDialogState extends State<WebLoginDialog> {
  bool _checking = false;

  Future<void> _capture() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final values = <String, String>{};
      for (final url in [
        'https://www.pixiv.net/',
        'https://accounts.pixiv.net/',
      ]) {
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri(url),
        );
        for (final cookie in cookies) {
          if (cookie.name.isNotEmpty && cookie.value.isNotEmpty) {
            values[cookie.name] = cookie.value;
          }
        }
      }
      final header = values.entries
          .map((cookie) => '${cookie.key}=${cookie.value}')
          .join('; ');
      if (!mounted) return;
      if (header.contains('PHPSESSID=')) {
        Navigator.of(context).pop(header);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionCookieMissing),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 720,
        child: Column(
          children: [
            AppBar(
              title: Text(l10n.webLoginTitle),
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: _checking ? null : _capture,
                  child: Text(l10n.useSession),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://accounts.pixiv.net/login'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  sharedCookiesEnabled: true,
                ),
                onLoadStop: (_, url) {
                  if (url?.host == 'www.pixiv.net') _capture();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
