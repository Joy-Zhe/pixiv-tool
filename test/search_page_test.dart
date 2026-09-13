import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pixiv_tool/app/app_services.dart';
import 'package:pixiv_tool/app/providers.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/features/search/search_page.dart';
import 'package:pixiv_tool/infrastructure/downloads/persistent_download_queue.dart';
import 'package:pixiv_tool/infrastructure/network/pixiv_http_client.dart';
import 'package:pixiv_tool/infrastructure/pixiv/pixiv_api_client.dart';
import 'package:pixiv_tool/l10n/app_localizations.dart';

class _Services extends Mock implements AppServices {}

class _Api extends Mock implements PixivApiClient {}

class _Queue extends Mock implements PersistentDownloadQueue {}

void main() {
  setUpAll(() {
    registerFallbackValue(const SearchQuery(keyword: 'tag'));
    registerFallbackValue(
      const DownloadRequest(
        source: DownloadSource.search,
        rootPath: '/tmp',
        candidates: [],
      ),
    );
  });

  Future<(_Api, _Queue)> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = _Services();
    final api = _Api();
    final queue = _Queue();
    final account = ValueNotifier<AccountSession?>(
      const AccountSession(
        profile: AccountProfile(id: '42', name: 'tester'),
        cookie: 'fixture',
      ),
    );
    final prefs = ValueNotifier<AppPreferences?>(
      const AppPreferences(
        pidRoot: '/tmp/search-test',
        rankingRoot: '/tmp/ranking',
        bookmarkRoot: '/tmp/bookmarks',
      ),
    );
    final http = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
    );
    when(() => services.accountState).thenReturn(account);
    when(() => services.preferenceState).thenReturn(prefs);
    when(() => services.api).thenReturn(api);
    when(() => services.downloads).thenReturn(queue);
    when(() => services.http).thenReturn(http);
    addTearDown(() {
      account.dispose();
      prefs.dispose();
      http.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(services)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (api, queue);
  }

  testWidgets(
    'validates empty keywords and invalid thresholds before requesting',
    (tester) async {
      final (api, _) = await mount(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(find.text('Enter a tag or keyword'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'tag');
      await tester.enterText(find.byType(TextField).at(1), '-1');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(
        find.text('Enter non-negative integers for likes or bookmarks'),
        findsOneWidget,
      );
      verifyNever(() => api.search(any()));
    },
  );

  testWidgets(
    'displays counts and sends selected works to the PID download root',
    (tester) async {
      final (api, queue) = await mount(tester);
      when(() => api.search(any())).thenAnswer(
        (_) async => const PageResult(
          items: [
            SearchItem(
              pid: '100',
              title: 'Found work',
              authorId: '7',
              authorName: 'artist',
              pageCount: 1,
              type: IllustType.illust,
              thumbnailUrl: '',
              likeCount: 12,
              bookmarkCount: 34,
            ),
          ],
          total: 1,
          hasMore: false,
        ),
      );
      when(() => queue.enqueue(any())).thenAnswer((_) async => ['job']);
      await tester.enterText(find.byType(TextField).at(0), 'tag');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.text('Found work'), findsOneWidget);
      expect(find.text('Likes: 12 · Bookmarks: 34'), findsOneWidget);
      await tester.tap(find.text('Select loaded'));
      await tester.pump();
      await tester.tap(find.text('Download selected'));
      await tester.pumpAndSettle();
      final request =
          verify(() => queue.enqueue(captureAny())).captured.single
              as DownloadRequest;
      expect(request.source, DownloadSource.search);
      expect(request.rootPath, '/tmp/search-test');
      expect(request.candidates.single.pid, '100');
      verifyNever(() => api.getIllust(any()));
    },
  );

  testWidgets('can stop a pending first search and continue it', (
    tester,
  ) async {
    final (api, _) = await mount(tester);
    final pending = Completer<PageResult<SearchItem>>();
    when(() => api.search(any())).thenAnswer((_) => pending.future);
    await tester.enterText(find.byType(TextField).at(0), 'tag');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.tap(find.text('Stop search'));
    await tester.pump();
    expect(find.text('Continue searching'), findsOneWidget);
    pending.complete(const PageResult(items: [], total: 0, hasMore: false));
    await tester.pumpAndSettle();
    expect(find.text('Continue searching'), findsOneWidget);
  });
}
