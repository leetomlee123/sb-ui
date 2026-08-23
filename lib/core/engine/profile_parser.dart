import 'dart:convert';
import 'package:yaml/yaml.dart';

class ProfileParserResult {
  final List<Map<String, dynamic>> outbounds;
  final int count;
  final String format; // 'sing-box', 'clash', 'uri-list'

  ProfileParserResult({
    required this.outbounds,
    required this.count,
    required this.format,
  });
}

class ProfileParser {
  static ProfileParserResult parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return ProfileParserResult(outbounds: [], count: 0, format: 'empty');
    }

    // 1. Try parsing as JSON (sing-box config or JSON array)
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('outbounds')) {
            final list = (decoded['outbounds'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .where((item) => !['direct', 'block', 'dns'].contains(item['type']))
                .toList();
            return ProfileParserResult(
              outbounds: list,
              count: list.length,
              format: 'sing-box',
            );
          }
        } else if (decoded is List) {
          final list = decoded.whereType<Map<String, dynamic>>().toList();
          return ProfileParserResult(
            outbounds: list,
            count: list.length,
            format: 'sing-box-outbounds',
          );
        }
      } catch (_) {}
    }

    // 2. Try parsing as YAML (Clash / Clash Meta config)
    if (trimmed.contains('proxies:') || trimmed.contains('Proxy:')) {
      try {
        final yamlDoc = loadYaml(trimmed);
        if (yamlDoc is YamlMap) {
          final proxies = yamlDoc['proxies'] ?? yamlDoc['Proxy'];
          if (proxies is YamlList) {
            final List<Map<String, dynamic>> outbounds = [];
            for (final p in proxies) {
              if (p is YamlMap) {
                final converted = _convertClashProxyToSingbox(p);
                if (converted != null) {
                  outbounds.add(converted);
                }
              }
            }
            return ProfileParserResult(
              outbounds: outbounds,
              count: outbounds.length,
              format: 'clash',
            );
          }
        }
      } catch (_) {}
    }

    // 3. Try parsing Base64 or URI list (ss://, vmess://, vless://, etc.)
    String decodedUris = trimmed;
    try {
      // If entire string is base64
      if (!trimmed.contains('\n') && !trimmed.startsWith('vmess://') && !trimmed.startsWith('ss://') && !trimmed.startsWith('vless://')) {
        final normalized = base64.normalize(trimmed);
        decodedUris = utf8.decode(base64.decode(normalized));
      }
    } catch (_) {
      decodedUris = trimmed;
    }

    final lines = decodedUris.split(RegExp(r'[\r\n]+'));
    final List<Map<String, dynamic>> uriOutbounds = [];
    for (final line in lines) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.isEmpty) continue;
      final ob = _parseUri(lineTrimmed);
      if (ob != null) {
        uriOutbounds.add(ob);
      }
    }

    if (uriOutbounds.isNotEmpty) {
      return ProfileParserResult(
        outbounds: uriOutbounds,
        count: uriOutbounds.length,
        format: 'uri-list',
      );
    }

    return ProfileParserResult(outbounds: [], count: 0, format: 'unknown');
  }

  static Map<String, dynamic>? _convertClashProxyToSingbox(YamlMap proxy) {
    final type = (proxy['type'] ?? '').toString().toLowerCase();
    final name = (proxy['name'] ?? 'Proxy').toString();
    final server = (proxy['server'] ?? '').toString();
    final port = int.tryParse((proxy['port'] ?? '').toString()) ?? 443;
    final password = (proxy['password'] ?? proxy['uuid'] ?? '').toString();

    switch (type) {
      case 'ss':
      case 'shadowsocks':
        return {
          'type': 'shadowsocks',
          'tag': name,
          'server': server,
          'server_port': port,
          'method': (proxy['cipher'] ?? 'aes-256-gcm').toString(),
          'password': password,
          if (proxy['plugin'] != null) 'plugin': proxy['plugin'].toString(),
          if (proxy['plugin-opts'] != null)
            'plugin_opts': (proxy['plugin-opts'] as YamlMap).value,
        };

      case 'vmess':
        return {
          'type': 'vmess',
          'tag': name,
          'server': server,
          'server_port': port,
          'uuid': password,
          'security': (proxy['cipher'] ?? 'auto').toString(),
          'alter_id': int.tryParse((proxy['alterId'] ?? '0').toString()) ?? 0,
          'transport': {
            'type': (proxy['network'] ?? 'tcp').toString(),
            if (proxy['ws-opts'] != null) 'path': (proxy['ws-opts']['path'] ?? '/').toString(),
            if (proxy['ws-opts'] != null && proxy['ws-opts']['headers'] != null)
              'headers': (proxy['ws-opts']['headers'] as YamlMap).value,
          },
          'tls': {
            'enabled': proxy['tls'] == true,
            'server_name': (proxy['servername'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
          }
        };

      case 'vless':
        return {
          'type': 'vless',
          'tag': name,
          'server': server,
          'server_port': port,
          'uuid': password,
          'flow': (proxy['flow'] ?? '').toString(),
          'tls': {
            'enabled': proxy['tls'] == true,
            'server_name': (proxy['servername'] ?? server).toString(),
            'reality': proxy['reality-opts'] != null
                ? {
                    'enabled': true,
                    'public_key': (proxy['reality-opts']['public-key'] ?? '').toString(),
                    'short_id': (proxy['reality-opts']['short-id'] ?? '').toString(),
                  }
                : null,
          }
        };

      case 'trojan':
        return {
          'type': 'trojan',
          'tag': name,
          'server': server,
          'server_port': port,
          'password': password,
          'tls': {
            'enabled': true,
            'server_name': (proxy['sni'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
          }
        };

      case 'hysteria2':
      case 'hy2':
        return {
          'type': 'hysteria2',
          'tag': name,
          'server': server,
          'server_port': port,
          'password': password,
          if (proxy['up'] != null) 'up_mbps': int.tryParse(proxy['up'].toString()),
          if (proxy['down'] != null) 'down_mbps': int.tryParse(proxy['down'].toString()),
          'tls': {
            'enabled': true,
            'server_name': (proxy['sni'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
          }
        };

      case 'tuic':
        return {
          'type': 'tuic',
          'tag': name,
          'server': server,
          'server_port': port,
          'uuid': password,
          'password': (proxy['token'] ?? '').toString(),
          'congestion_controller': (proxy['congestion-controller'] ?? 'bbr').toString(),
          'tls': {
            'enabled': true,
            'server_name': (proxy['sni'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
          }
        };

      default:
        return null;
    }
  }

  static Map<String, dynamic>? _parseUri(String uriStr) {
    try {
      final uri = Uri.parse(uriStr);
      final scheme = uri.scheme.toLowerCase();
      final tag = uri.fragment.isNotEmpty ? Uri.decodeComponent(uri.fragment) : '${uri.scheme}-${uri.host}';

      if (scheme == 'trojan') {
        return {
          'type': 'trojan',
          'tag': tag,
          'server': uri.host,
          'server_port': uri.port == 0 ? 443 : uri.port,
          'password': uri.userInfo,
          'tls': {
            'enabled': true,
            'server_name': uri.queryParameters['sni'] ?? uri.host,
            'insecure': uri.queryParameters['allowInsecure'] == '1',
          }
        };
      } else if (scheme == 'hysteria2' || scheme == 'hy2') {
        return {
          'type': 'hysteria2',
          'tag': tag,
          'server': uri.host,
          'server_port': uri.port == 0 ? 443 : uri.port,
          'password': uri.userInfo,
          'tls': {
            'enabled': true,
            'server_name': uri.queryParameters['sni'] ?? uri.host,
            'insecure': uri.queryParameters['insecure'] == '1',
          }
        };
      } else if (scheme == 'vless') {
        return {
          'type': 'vless',
          'tag': tag,
          'server': uri.host,
          'server_port': uri.port == 0 ? 443 : uri.port,
          'uuid': uri.userInfo,
          'flow': uri.queryParameters['flow'] ?? '',
          'tls': {
            'enabled': uri.queryParameters['security'] == 'tls' || uri.queryParameters['security'] == 'reality',
            'server_name': uri.queryParameters['sni'] ?? uri.host,
            if (uri.queryParameters['security'] == 'reality')
              'reality': {
                'enabled': true,
                'public_key': uri.queryParameters['pbk'] ?? '',
                'short_id': uri.queryParameters['sid'] ?? '',
              }
          }
        };
      } else if (scheme == 'vmess') {
        // vmess:// base64 encoded JSON
        final base64Content = uriStr.substring(8);
        final jsonStr = utf8.decode(base64.decode(base64.normalize(base64Content)));
        final Map<String, dynamic> vmessMap = jsonDecode(jsonStr);
        return {
          'type': 'vmess',
          'tag': vmessMap['ps'] ?? 'VMess',
          'server': vmessMap['add'] ?? '',
          'server_port': int.tryParse(vmessMap['port']?.toString() ?? '443') ?? 443,
          'uuid': vmessMap['id'] ?? '',
          'security': 'auto',
          'alter_id': int.tryParse(vmessMap['aid']?.toString() ?? '0') ?? 0,
          'tls': {
            'enabled': vmessMap['tls'] == 'tls',
            'server_name': vmessMap['sni'] ?? vmessMap['host'] ?? vmessMap['add'] ?? '',
          }
        };
      }
    } catch (_) {}
    return null;
  }
}
