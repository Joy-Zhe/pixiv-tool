import '../../domain/contracts.dart';
import '../../domain/models.dart';
import '../network/pixiv_http_client.dart';

class PixivApiClient implements PixivApi {
  PixivApiClient(this._http, {String baseUrl = 'https://www.pixiv.net'})
    : _base = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final PixivHttpClient _http;
  final String _base;

  @override
  Future<AccountProfile> getCurrentAccount() async {
    final json = await _http.getJson(
      Uri.parse('$_base/ajax/user/extra?lang=en'),
    );
    final body = _map(json['body']);
    final cookieId = RegExp(r'(?:^|;\s*)PHPSESSID=(\d+)_')
        .firstMatch(_http.cookie)
        ?.group(1);
    final id = _text(
      body['userId'] ?? body['id'] ?? json['userId'] ?? cookieId,
    );
    if (id.isEmpty) {
      throw const PixivHttpException(
        401,
        'Unable to identify the current Pixiv account',
      );
    }
    var name = _text(body['userName'] ?? body['name']);
    var avatar = _text(
      body['profileImageUrl'] ?? body['imageBig'] ?? body['image'],
    );
    if (name.isEmpty) {
      try {
        final profileJson = await _http.getJson(
          Uri.parse('$_base/ajax/user/$id?full=1&lang=en'),
        );
        final profile = _map(profileJson['body']);
        name = _text(profile['name'] ?? profile['userName']);
        avatar = _text(profile['imageBig'] ?? profile['image'] ?? avatar);
      } on Object {
        // The session is valid even when the optional profile endpoint fails.
      }
    }
    return AccountProfile(
      id: id,
      name: name.isEmpty ? id : name,
      avatarUrl: avatar,
    );
  }

  @override
  Future<IllustDetail> getIllust(String pid) async {
    if (!RegExp(r'^\d+$').hasMatch(pid)) {
      throw const FormatException('PID must contain digits only');
    }
    final json = await _http.getJson(Uri.parse('$_base/ajax/illust/$pid'));
    final body = _map(json['body']);
    final urls = _map(body['urls']);
    return IllustDetail(
      pid: _text(body['illustId'] ?? pid),
      title: _text(body['title']),
      authorId: _text(body['userId']),
      authorName: _text(body['userName']),
      pageCount: _integer(body['pageCount'], fallback: 1),
      type: _type(body['illustType']),
      thumbnailUrl: _text(
        urls['regular'] ?? urls['small'] ?? urls['thumb'] ?? urls['original'],
      ),
    );
  }

  @override
  Future<List<IllustPage>> getIllustPages(String pid) async {
    final json = await _http.getJson(
      Uri.parse('$_base/ajax/illust/$pid/pages'),
    );
    final body = json['body'];
    if (body is! List)
      throw const FormatException('Pixiv pages response is invalid');
    return body.indexed
        .map((entry) {
          final item = _map(entry.$2);
          final urls = _map(item['urls']);
          final original = _text(urls['original']);
          if (original.isEmpty)
            throw const FormatException('Original image URL is missing');
          return IllustPage(index: entry.$1, originalUrl: original);
        })
        .toList(growable: false);
  }

  @override
  Future<PageResult<RankingItem>> getRanking(RankingQuery query) async {
    if (query.startPage < 1 || query.endPage < query.startPage) {
      throw const FormatException('Invalid ranking page range');
    }
    final items = <RankingItem>[];
    for (var page = query.startPage; page <= query.endPage; page++) {
      final mode = '${query.mode.name}${query.r18 ? '_r18' : ''}';
      final params = <String, String>{
        'mode': mode,
        'p': '$page',
        'format': 'json',
      };
      if (query.content != RankingContent.all)
        params['content'] = query.content.name;
      final json = await _http.getJson(
        Uri.parse('$_base/ranking.php').replace(queryParameters: params),
      );
      final contents = json['contents'];
      if (contents is! List) break;
      for (final raw in contents) {
        final item = _map(raw);
        items.add(
          RankingItem(
            pid: _text(item['illust_id']),
            title: _text(item['title']),
            rank: _integer(item['rank']),
            authorId: _text(item['user_id']),
            authorName: _text(item['user_name']),
            thumbnailUrl: _text(item['url']),
            type: _type(item['illust_type']),
          ),
        );
      }
      if (_isFalse(json['next'])) break;
    }
    return PageResult(items: items, total: items.length, hasMore: false);
  }

  @override
  Future<PageResult<BookmarkItem>> getBookmarks(BookmarkQuery query) async {
    final uri =
        Uri.parse('$_base/ajax/user/${query.accountId}/illusts/bookmarks')
            .replace(
              queryParameters: {
                'tag': query.tag,
                'offset': '${query.offset}',
                'limit': '${query.limit}',
                'rest': query.visibility == BookmarkVisibility.public
                    ? 'show'
                    : 'hide',
                'lang': 'en',
              },
            );
    final json = await _http.getJson(uri);
    final body = _map(json['body']);
    final works = body['works'];
    final total = _integer(body['total']);
    final items = <BookmarkItem>[];
    if (works is List) {
      for (final raw in works) {
        final item = _map(raw);
        final pid = _text(item['id'] ?? item['illustId']);
        if (pid.isEmpty) continue;
        items.add(
          BookmarkItem(
            accountId: query.accountId,
            pid: pid,
            visibility: query.visibility,
            title: _text(item['title']),
            authorId: _text(item['userId']),
            authorName: _text(item['userName']),
            pageCount: _integer(item['pageCount'], fallback: 1),
            type: _type(item['illustType']),
            thumbnailUrl: _text(item['url'] ?? item['profileImageUrl']),
            tags: _tags(item['tags']),
          ),
        );
      }
    }
    final effectiveTotal = total == 0 ? items.length : total;
    return PageResult(
      items: items,
      total: effectiveTotal,
      hasMore: query.offset + items.length < effectiveTotal && items.isNotEmpty,
    );
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static String _text(Object? value) => value?.toString() ?? '';

  static int _integer(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;

  static IllustType _type(Object? value) {
    final raw = _text(value).toLowerCase();
    if (raw == '2' || raw == 'ugoira') return IllustType.ugoira;
    if (raw == '1' || raw == 'manga') return IllustType.manga;
    return IllustType.illust;
  }

  static List<String> _tags(Object? value) {
    if (value is! List) return const [];
    return value
        .map((tag) {
          if (tag is Map) return _text(tag['tag'] ?? tag['name']);
          return _text(tag);
        })
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  static bool _isFalse(Object? value) =>
      value == null || value == false || value == 'false';
}
