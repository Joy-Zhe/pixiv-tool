import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/bookmarks/bookmarks_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/pid/pid_page.dart';
import '../features/ranking/ranking_page.dart';
import '../features/settings/settings_page.dart';
import '../l10n/app_localizations.dart';
import 'app_shell.dart';
import 'providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class PixivToolApp extends ConsumerStatefulWidget {
  const PixivToolApp({super.key});

  @override
  ConsumerState<PixivToolApp> createState() => _PixivToolAppState();
}

class _PixivToolAppState extends ConsumerState<PixivToolApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/pid',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: '/pid', builder: (_, _) => const PidPage()),
            GoRoute(path: '/ranking', builder: (_, _) => const RankingPage()),
            GoRoute(
              path: '/bookmarks',
              builder: (_, _) => const BookmarksPage(),
            ),
            GoRoute(
              path: '/downloads',
              builder: (_, _) => const DownloadsPage(),
            ),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(appServicesProvider);
    return ValueListenableBuilder(
      valueListenable: services.preferenceState,
      builder: (context, preferences, _) {
        final themeMode = switch (preferences?.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        final locale = switch (preferences?.localeCode) {
          'zh' => const Locale('zh'),
          'en' => const Locale('en'),
          _ => null,
        };
        final languageCode =
            locale?.languageCode ??
            Platform.localeName.split(RegExp('[-_]')).first;
        final fontFamily = languageCode == 'zh'
            ? Platform.isWindows
                  ? 'Microsoft YaHei UI'
                  : Platform.isMacOS
                  ? 'PingFang SC'
                  : null
            : null;
        return MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff0096fa),
            ),
            useMaterial3: true,
            fontFamily: fontFamily,
            cardTheme: const CardThemeData(margin: EdgeInsets.zero),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff0096fa),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: fontFamily,
            cardTheme: const CardThemeData(margin: EdgeInsets.zero),
          ),
        );
      },
    );
  }
}
