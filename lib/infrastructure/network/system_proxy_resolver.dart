import 'dart:io';

class SystemProxySettings {
  const SystemProxySettings({this.http, this.https});

  final String? http;
  final String? https;

  String findProxy(Uri uri) {
    final endpoint = uri.scheme == 'https' ? https ?? http : http ?? https;
    return endpoint == null || endpoint.isEmpty ? 'DIRECT' : 'PROXY $endpoint';
  }
}

Future<SystemProxySettings> loadSystemProxySettings() async {
  if (Platform.isWindows) return _loadWindowsProxy();
  if (Platform.isMacOS) return _loadMacOsProxy();
  return const SystemProxySettings();
}

Future<SystemProxySettings> _loadWindowsProxy() async {
  const key =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  try {
    final result = await Process.run('reg.exe', ['query', key]);
    if (result.exitCode != 0) return const SystemProxySettings();
    final output = result.stdout.toString();
    final enabled = RegExp(
      r'ProxyEnable\s+REG_DWORD\s+0x1',
      caseSensitive: false,
    ).hasMatch(output);
    if (!enabled) return const SystemProxySettings();
    final match = RegExp(
      r'ProxyServer\s+REG_SZ\s+([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(output);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return const SystemProxySettings();
    return _parseProxyServer(raw);
  } on Object {
    return const SystemProxySettings();
  }
}

SystemProxySettings _parseProxyServer(String raw) {
  if (!raw.contains('=')) {
    return SystemProxySettings(http: raw, https: raw);
  }
  final values = <String, String>{};
  for (final section in raw.split(';')) {
    final separator = section.indexOf('=');
    if (separator <= 0) continue;
    values[section.substring(0, separator).trim().toLowerCase()] = section
        .substring(separator + 1)
        .trim();
  }
  return SystemProxySettings(
    http: values['http'] ?? values['https'],
    https: values['https'] ?? values['http'],
  );
}

Future<SystemProxySettings> _loadMacOsProxy() async {
  try {
    final result = await Process.run('scutil', ['--proxy']);
    if (result.exitCode != 0) return const SystemProxySettings();
    final output = result.stdout.toString();
    String? value(String key) => RegExp(
      '^\\s*$key\\s*:\\s*(.+?)\\s*\$',
      multiLine: true,
    ).firstMatch(output)?.group(1);
    String? endpoint(String prefix) {
      if (value('${prefix}Enable') != '1') return null;
      final host = value('${prefix}Proxy');
      final port = value('${prefix}Port');
      return host == null || port == null ? null : '$host:$port';
    }

    return SystemProxySettings(
      http: endpoint('HTTP'),
      https: endpoint('HTTPS'),
    );
  } on Object {
    return const SystemProxySettings();
  }
}
