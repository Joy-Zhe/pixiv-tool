import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixiv_tool/domain/models.dart';
import 'package:pixiv_tool/features/common/common_widgets.dart';
import 'package:pixiv_tool/infrastructure/network/pixiv_http_client.dart';

void main() {
  test('loads thumbnail bytes through the configured Pixiv client', () async {
    final expected = Uint8List.fromList([1, 2, 3, 4, 5]);
    String? referer;
    String? cookie;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      referer = request.headers.value(HttpHeaders.refererHeader);
      cookie = request.headers.value(HttpHeaders.cookieHeader);
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = expected.length
        ..add(expected);
      await request.response.close();
    });
    final client = PixivHttpClient(
      proxy: const ProxyConfig(mode: ProxyMode.direct),
      cookie: 'PHPSESSID=fixture',
    );
    addTearDown(client.close);

    final result = await loadPixivImageBytes(
      client,
      'http://${server.address.host}:${server.port}/thumb.jpg',
    );

    expect(result, expected);
    expect(referer, 'https://www.pixiv.net/');
    expect(cookie, 'PHPSESSID=fixture');
  });
}
