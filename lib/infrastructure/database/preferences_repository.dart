import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/contracts.dart';
import '../../domain/models.dart';
import 'app_database.dart';

class DriftPreferencesRepository implements PreferencesRepository {
  DriftPreferencesRepository(this._db);

  final AppDatabase _db;
  static const _key = 'app.preferences.v1';

  @override
  Future<AppPreferences> load() async {
    final row = await (_db.select(
      _db.preferences,
    )..where((r) => r.key.equals(_key))).getSingleOrNull();
    if (row == null) return _defaults();
    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      final defaults = await _defaults();
      return AppPreferences(
        pidRoot: json['pidRoot'] as String? ?? defaults.pidRoot,
        rankingRoot: json['rankingRoot'] as String? ?? defaults.rankingRoot,
        bookmarkRoot: json['bookmarkRoot'] as String? ?? defaults.bookmarkRoot,
        concurrentDownloads:
            (json['concurrentDownloads'] as num?)?.toInt().clamp(1, 8) ?? 4,
        localeCode: json['localeCode'] as String? ?? '',
        themeMode: json['themeMode'] as String? ?? 'system',
        proxy: ProxyConfig(
          mode: ProxyMode.values.firstWhere(
            (v) => v.name == json['proxyMode'],
            orElse: () => ProxyMode.system,
          ),
          host: json['proxyHost'] as String? ?? '',
          port: (json['proxyPort'] as num?)?.toInt() ?? 0,
          username: json['proxyUsername'] as String? ?? '',
        ),
      );
    } on Object {
      return _defaults();
    }
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    final value = jsonEncode({
      'pidRoot': preferences.pidRoot,
      'rankingRoot': preferences.rankingRoot,
      'bookmarkRoot': preferences.bookmarkRoot,
      'concurrentDownloads': preferences.concurrentDownloads,
      'localeCode': preferences.localeCode,
      'themeMode': preferences.themeMode,
      'proxyMode': preferences.proxy.mode.name,
      'proxyHost': preferences.proxy.host,
      'proxyPort': preferences.proxy.port,
      'proxyUsername': preferences.proxy.username,
    });
    await _db
        .into(_db.preferences)
        .insertOnConflictUpdate(
          PreferencesCompanion.insert(key: _key, value: value),
        );
  }

  Future<AppPreferences> _defaults() async {
    final downloads = await getDownloadsDirectory();
    final root =
        downloads?.path ??
        p.join((await getApplicationDocumentsDirectory()).path, 'Downloads');
    return AppPreferences(
      pidRoot: p.join(root, 'PixivTool', 'PID'),
      rankingRoot: p.join(root, 'PixivTool', 'Ranking'),
      bookmarkRoot: p.join(root, 'PixivTool', 'Bookmarks'),
    );
  }
}
