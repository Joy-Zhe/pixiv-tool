import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/common_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _pidRoot;
  late final TextEditingController _rankingRoot;
  late final TextEditingController _bookmarkRoot;
  final _cookie = TextEditingController();
  final _proxyHost = TextEditingController();
  final _proxyPort = TextEditingController();
  final _proxyUser = TextEditingController();
  final _proxyPassword = TextEditingController();
  int _concurrency = 4;
  String _locale = '';
  String _theme = 'system';
  ProxyMode _proxyMode = ProxyMode.system;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appServicesProvider).preferenceState.value!;
    _pidRoot = TextEditingController(text: prefs.pidRoot);
    _rankingRoot = TextEditingController(text: prefs.rankingRoot);
    _bookmarkRoot = TextEditingController(text: prefs.bookmarkRoot);
    _proxyHost.text = prefs.proxy.host;
    _proxyPort.text = prefs.proxy.port == 0 ? '' : '${prefs.proxy.port}';
    _proxyUser.text = prefs.proxy.username;
    _concurrency = prefs.concurrentDownloads;
    _locale = prefs.localeCode;
    _theme = prefs.themeMode;
    _proxyMode = prefs.proxy.mode;
  }

  @override
  void dispose() {
    for (final controller in [
      _pidRoot,
      _rankingRoot,
      _bookmarkRoot,
      _cookie,
      _proxyHost,
      _proxyPort,
      _proxyUser,
      _proxyPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(TextEditingController controller) async {
    final path = await getDirectoryPath(initialDirectory: controller.text);
    if (path != null) setState(() => controller.text = path);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final port = int.tryParse(_proxyPort.text) ?? 0;
    if ([
      _pidRoot,
      _rankingRoot,
      _bookmarkRoot,
    ].any((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.downloadFoldersRequired)));
      return;
    }
    if (_proxyMode == ProxyMode.manual &&
        (_proxyHost.text.trim().isEmpty || port < 1 || port > 65535)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.validProxyRequired)));
      return;
    }
    setState(() => _saving = true);
    final services = ref.read(appServicesProvider);
    try {
      await services.savePreferences(
        AppPreferences(
          pidRoot: _pidRoot.text.trim(),
          rankingRoot: _rankingRoot.text.trim(),
          bookmarkRoot: _bookmarkRoot.text.trim(),
          concurrentDownloads: _concurrency,
          localeCode: _locale,
          themeMode: _theme,
          proxy: ProxyConfig(
            mode: _proxyMode,
            host: _proxyHost.text.trim(),
            port: port,
            username: _proxyUser.text.trim(),
          ),
        ),
        proxyPassword: _proxyPassword.text,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
        );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manualLogin() async {
    if (_cookie.text.trim().isEmpty) return;
    try {
      await ref.read(appServicesProvider).loginWithCookie(_cookie.text);
      _cookie.clear();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _logout() async {
    final services = ref.read(appServicesProvider);
    await services.logout();
    await CookieManager.instance().deleteAllCookies();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    final l10n = AppLocalizations.of(context);
    return FeaturePage(
      title: l10n.settings,
      child: ListView(
        children: [
          Text(l10n.account, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: services.accountState,
            builder: (context, session, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: session == null
                    ? Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                signInWithWebView(context, services),
                            icon: const Icon(Icons.login),
                            label: Text(l10n.signIn),
                          ),
                          SizedBox(
                            width: 460,
                            child: TextField(
                              controller: _cookie,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: l10n.manualCookie,
                                hintText: l10n.cookieHint,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _manualLogin,
                            child: Text(l10n.save),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              session.profile.name.isEmpty
                                  ? '?'
                                  : session.profile.name.substring(0, 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${session.profile.name}\n${session.profile.id}',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: Text(l10n.logout),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => services.bookmarks.clearAccount(
                              session.profile.id,
                            ),
                            child: Text(l10n.clearBookmarkCache),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.downloadSection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _PathField(
            label: l10n.pidFolder,
            controller: _pidRoot,
            onPick: () => _pick(_pidRoot),
          ),
          _PathField(
            label: l10n.rankingFolder,
            controller: _rankingRoot,
            onPick: () => _pick(_rankingRoot),
          ),
          _PathField(
            label: l10n.bookmarkFolder,
            controller: _bookmarkRoot,
            onPick: () => _pick(_bookmarkRoot),
          ),
          Row(
            children: [
              Expanded(child: Text('${l10n.concurrency}: $_concurrency')),
              Expanded(
                flex: 3,
                child: Slider(
                  value: _concurrency.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: '$_concurrency',
                  onChanged: (value) =>
                      setState(() => _concurrency = value.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.proxy, style: Theme.of(context).textTheme.titleLarge),
          DropdownButtonFormField<ProxyMode>(
            initialValue: _proxyMode,
            items: ProxyMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(switch (mode) {
                      ProxyMode.system => l10n.system,
                      ProxyMode.manual => l10n.manual,
                      ProxyMode.direct => l10n.direct,
                    }),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _proxyMode = value!),
          ),
          if (_proxyMode == ProxyMode.manual) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proxyHost,
                    decoration: InputDecoration(labelText: l10n.proxyHost),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _proxyPort,
                    decoration: InputDecoration(labelText: l10n.proxyPort),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proxyUser,
                    decoration: InputDecoration(labelText: l10n.proxyUsername),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _proxyPassword,
                    obscureText: true,
                    decoration: InputDecoration(labelText: l10n.proxyPassword),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _locale,
                  decoration: InputDecoration(labelText: l10n.language),
                  items: [
                    DropdownMenuItem(value: '', child: Text(l10n.system)),
                    DropdownMenuItem(
                      value: 'zh',
                      child: Text(l10n.simplifiedChinese),
                    ),
                    DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                  ],
                  onChanged: (value) => setState(() => _locale = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _theme,
                  decoration: InputDecoration(labelText: l10n.theme),
                  items: [
                    DropdownMenuItem(value: 'system', child: Text(l10n.system)),
                    DropdownMenuItem(value: 'light', child: Text(l10n.light)),
                    DropdownMenuItem(value: 'dark', child: Text(l10n.dark)),
                  ],
                  onChanged: (value) => setState(() => _theme = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.label,
    required this.controller,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open),
        ),
      ),
    ),
  );
}
