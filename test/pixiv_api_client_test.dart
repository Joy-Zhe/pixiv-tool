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
