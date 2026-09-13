import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/infrastructure/network/pixiv_http_client.dart';
import 'package:pixiv_tool/infrastructure/pixiv/pixiv_api_client.dart';

void main() {
  late HttpServer server;
  late PixivApiClient api;
  final requests = <Uri>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final http = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
      cookie: 'PHPSESSID=ok',
    );
    api = PixivApiClient(
      http,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
  });

  tearDown(() => server.close(force: true));

  test('loads current account from authenticated session', () async {
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'userId': '42',
        'userName': 'tester',
        'profileImageUrl': 'avatar',
      },
    });
    final profile = await api.getCurrentAccount();
    expect(profile.id, '42');
    expect(profile.name, 'tester');
  });

  test('parses public bookmarks and pagination', () async {
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'total': 49,
        'works': [
          {
            'id': '1001',
            'title': 'work',
            'userId': '7',
            'userName': 'artist',
            'pageCount': 2,
            'illustType': 1,
            'url': 'thumb',
            'tags': ['tag-a'],
          },
        ],
      },
    });
    final page = await api.getBookmarks(
      const BookmarkQuery(
        accountId: '42',
        visibility: BookmarkVisibility.public,
      ),
    );
    expect(page.items.single.type, IllustType.manga);
    expect(page.items.single.tags, ['tag-a']);
    expect(page.hasMore, isTrue);
    expect(requests.single.queryParameters['rest'], 'show');
    expect(requests.single.queryParameters['limit'], '48');
  });

  test('uses hide for private bookmarks', () async {
    _serveOne(server, requests, {
      'error': false,
      'body': {'total': 0, 'works': []},
    });
    await api.getBookmarks(
      const BookmarkQuery(
        accountId: '42',
        visibility: BookmarkVisibility.private,
      ),
    );
    expect(requests.single.queryParameters['rest'], 'hide');
  });

  test('parses search works and maps all search modes', () async {
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'illustManga': {
          'data': [
            {
              'id': '9001',
              'title': 'tagged work',
              'userId': '8',
              'userName': 'searcher',
              'pageCount': 3,
              'illustType': 0,
              'url': 'thumb',
              'tags': [
                {'tag': 'blue'},
              ],
              'likeCount': 12,
              'bookmarkCount': 34,
            },
          ],
          'total': 100,
          'lastPage': 2,
        },
      },
    });
    final partial = await api.search(
      const SearchQuery(keyword: 'blue sky', mode: SearchMode.tagPartial),
    );
    expect(partial.items.single.pid, '9001');
    expect(partial.items.single.likeCount, 12);
    expect(partial.items.single.bookmarkCount, 34);
    expect(partial.items.single.tags, ['blue']);
    expect(partial.hasMore, isTrue);
    expect(requests.single.queryParameters, {
      'word': 'blue sky',
      'order': 'date_d',
      'mode': 'all',
      'p': '1',
      's_mode': 's_tag',
      'type': 'all',
      'lang': 'en',
    });

    requests.clear();
    final exact = await api.search(
      const SearchQuery(keyword: 'blue', mode: SearchMode.tagExact, page: 2),
    );
    expect(exact.items.single.pid, '9001');
    expect(requests.single.queryParameters['s_mode'], 's_tag_full');
    expect(requests.single.queryParameters['p'], '2');

    requests.clear();
    await api.search(
      const SearchQuery(keyword: 'blue', mode: SearchMode.titleOrDescription),
    );
    expect(requests.single.queryParameters['s_mode'], 's_tc');
  });

  test('uses raw page size and total for search pagination fallback', () async {
    final raw = [
      for (var index = 0; index < 59; index++)
        {
          'id': '${10000 + index}',
          'title': 'work $index',
          'userId': '8',
          'userName': 'searcher',
          'pageCount': 1,
          'illustType': 0,
          'url': 'thumb',
        },
    ];
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'illustManga': {'data': raw, 'total': 100},
      },
    });
    final page = await api.search(const SearchQuery(keyword: 'x'));
    expect(page.items, hasLength(59));
    expect(page.hasMore, isTrue);

    final lastPage = await api.search(const SearchQuery(keyword: 'x', page: 2));
    expect(lastPage.hasMore, isFalse);
  });

  test('preserves non-ASCII and reserved search keywords', () async {
    const keyword = '猫 / + #';
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'illustManga': {'data': [], 'total': 0, 'lastPage': 1},
      },
    });
    await api.search(const SearchQuery(keyword: keyword));
    expect(requests.single.pathSegments.last, keyword);
    expect(requests.single.queryParameters['word'], keyword);
  });

  test('keeps missing detail popularity counts unknown', () async {
    _serveOne(server, requests, {
      'error': false,
      'body': {
        'illustId': '9002',
        'title': 'work',
        'userId': '8',
        'userName': 'searcher',
        'pageCount': 1,
        'illustType': 0,
        'urls': {'regular': 'thumb'},
        'likeCount': 0,
      },
    });
    final detail = await api.getIllust('9002');
    expect(detail.likeCount, 0);
    expect(detail.bookmarkCount, isNull);
  });

  test('rejects a malformed search response', () async {
    _serveOne(server, requests, {'error': false, 'body': {}});
    await expectLater(
      api.search(const SearchQuery(keyword: 'x')),
      throwsA(isA<FormatException>()),
    );
  });
}

void _serveOne(
  HttpServer server,
  List<Uri> requests,
  Map<String, Object?> payload,
) {
  server.listen((request) async {
    requests.add(request.uri);
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
  });
}
