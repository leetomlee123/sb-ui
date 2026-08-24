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
  static const int _maxCacheEntries = 50;
  static final Map<int, ProfileParserResult> _parseCache = {};

  /// Clears the in-memory parse cache (e.g. for testing or memory pressure).
  static void clearCache() {
    _parseCache.clear();
  }

  static ProfileParserResult parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return ProfileParserResult(outbounds: [], count: 0, format: 'empty');
    }

    final cacheKey = Object.hash(trimmed.length, trimmed.hashCode);
    final cached = _parseCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final result = _doParse(trimmed);
    if (_parseCache.length >= _maxCacheEntries) {
      _parseCache.remove(_parseCache.keys.first);
    }
    _parseCache[cacheKey] = result;
    return result;
  }

  static ProfileParserResult _doParse(String trimmed) {
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
    if (trimmed.contains('proxies:') || trimmed.contains('Proxy:') || trimmed.contains('proxy-groups:')) {
      try {
        final yamlDoc = loadYaml(trimmed);
        if (yamlDoc is YamlMap) {
          final proxies = yamlDoc['proxies'] ?? yamlDoc['Proxy'];
          final List<Map<String, dynamic>> outbounds = [];

          if (proxies is YamlList) {
            for (final p in proxies) {
              if (p is YamlMap) {
                final converted = _convertClashProxyToSingbox(p);
                if (converted != null) {
                  outbounds.add(converted);
                }
              }
            }
          }

          // Also convert proxy-groups if present
          final groups = yamlDoc['proxy-groups'] ?? yamlDoc['Proxy Group'];
          if (groups is YamlList) {
            for (final g in groups) {
              if (g is YamlMap) {
                final groupOutbound = _convertClashGroupToSingbox(g);
                if (groupOutbound != null) {
                  outbounds.add(groupOutbound);
                }
              }
            }
          }

          if (outbounds.isNotEmpty) {
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
      if (!trimmed.contains('\n') &&
          !trimmed.startsWith('vmess://') &&
          !trimmed.startsWith('ss://') &&
          !trimmed.startsWith('vless://') &&
          !trimmed.startsWith('trojan://') &&
          !trimmed.startsWith('hy2://') &&
          !trimmed.startsWith('hysteria2://')) {
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

  static Map<String, dynamic>? _convertClashGroupToSingbox(YamlMap group) {
    final name = (group['name'] ?? '').toString();
    final type = (group['type'] ?? 'select').toString().toLowerCase();
    final proxiesList = group['proxies'];
    if (name.isEmpty || proxiesList is! YamlList) return null;

    final List<String> outbounds = proxiesList.map((e) => e.toString()).toList();

    if (type == 'url-test' || type == 'urltest') {
      return {
        'type': 'urltest',
        'tag': name,
        'outbounds': outbounds,
        'url': (group['url'] ?? 'https://www.gstatic.com/generate_204').toString(),
        'interval': '${group['interval'] ?? 300}s',
        'tolerance': int.tryParse(group['tolerance']?.toString() ?? '50') ?? 50,
      };
    } else if (type == 'load-balance' || type == 'loadbalance') {
      return {
        'type': 'urltest',
        'tag': name,
        'outbounds': outbounds,
      };
    } else {
      return {
        'type': 'selector',
        'tag': name,
        'outbounds': outbounds,
      };
    }
  }

  static Map<String, dynamic>? _convertClashProxyToSingbox(YamlMap proxy) {
    final type = (proxy['type'] ?? '').toString().toLowerCase();
    final name = (proxy['name'] ?? 'Proxy').toString();
    final server = (proxy['server'] ?? '').toString();
    final port = int.tryParse((proxy['port'] ?? '').toString()) ?? 443;
    final password = (proxy['password'] ?? proxy['uuid'] ?? '').toString();

    // Parse transport if present
    Map<String, dynamic>? transport;
    final network = (proxy['network'] ?? '').toString().toLowerCase();
    if (network == 'ws' || proxy['ws-opts'] != null) {
      transport = {
        'type': 'ws',
        if (proxy['ws-opts'] != null && proxy['ws-opts']['path'] != null)
          'path': proxy['ws-opts']['path'].toString(),
        if (proxy['ws-opts'] != null && proxy['ws-opts']['headers'] != null)
          'headers': (proxy['ws-opts']['headers'] as YamlMap).value,
      };
    } else if (network == 'grpc' || proxy['grpc-opts'] != null) {
      transport = {
        'type': 'grpc',
        if (proxy['grpc-opts'] != null && proxy['grpc-opts']['grpc-service-name'] != null)
          'service_name': proxy['grpc-opts']['grpc-service-name'].toString(),
      };
    } else if (network == 'http' || proxy['http-opts'] != null) {
      transport = {
        'type': 'http',
        if (proxy['http-opts'] != null && proxy['http-opts']['path'] != null)
          'path': proxy['http-opts']['path'].toString(),
        if (proxy['http-opts'] != null && proxy['http-opts']['headers'] != null)
          'headers': (proxy['http-opts']['headers'] as YamlMap).value,
      };
    }

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
          'transport': ?transport,
          'tls': {
            'enabled': proxy['tls'] == true,
            'server_name': (proxy['servername'] ?? proxy['sni'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
            if (proxy['client-fingerprint'] != null)
              'utls': {
                'enabled': true,
                'fingerprint': proxy['client-fingerprint'].toString(),
              },
          }
        };

      case 'vless':
        return {
          'type': 'vless',
          'tag': name,
          'server': server,
          'server_port': port,
          'uuid': password,
          if (proxy['flow'] != null && proxy['flow'].toString().isNotEmpty)
            'flow': proxy['flow'].toString(),
          'transport': ?transport,
          'tls': {
            'enabled': proxy['tls'] == true || proxy['reality-opts'] != null,
            'server_name': (proxy['servername'] ?? proxy['sni'] ?? server).toString(),
            'insecure': proxy['skip-cert-verify'] == true,
            if (proxy['reality-opts'] != null)
              'reality': {
                'enabled': true,
                'public_key': (proxy['reality-opts']['public-key'] ?? proxy['reality-opts']['publicKey'] ?? '').toString(),
                'short_id': (proxy['reality-opts']['short-id'] ?? proxy['reality-opts']['shortId'] ?? '').toString(),
              },
            if (proxy['client-fingerprint'] != null)
              'utls': {
                'enabled': true,
                'fingerprint': proxy['client-fingerprint'].toString(),
              },
          }
        };

      case 'trojan':
        return {
          'type': 'trojan',
          'tag': name,
          'server': server,
          'server_port': port,
          'password': password,
          'transport': ?transport,
          'tls': {
            'enabled': true,
            'server_name': (proxy['sni'] ?? proxy['servername'] ?? server).toString(),
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
          'password': (proxy['password'] ?? proxy['auth'] ?? '').toString(),
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
          'password': (proxy['token'] ?? proxy['password'] ?? '').toString(),
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
        Map<String, dynamic>? transport;
        final netType = uri.queryParameters['type'] ?? 'tcp';
        if (netType == 'ws') {
          transport = {
            'type': 'ws',
            'path': uri.queryParameters['path'] ?? '/',
            if (uri.queryParameters['host'] != null)
              'headers': {'Host': uri.queryParameters['host']!},
          };
        } else if (netType == 'grpc') {
          transport = {
            'type': 'grpc',
            if (uri.queryParameters['serviceName'] != null)
              'service_name': uri.queryParameters['serviceName']!,
          };
        }

        return {
          'type': 'trojan',
          'tag': tag,
          'server': uri.host,
          'server_port': uri.port == 0 ? 443 : uri.port,
          'password': uri.userInfo,
          'transport': ?transport,
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
        Map<String, dynamic>? transport;
        final netType = uri.queryParameters['type'] ?? uri.queryParameters['net'] ?? 'tcp';
        if (netType == 'ws') {
          transport = {
            'type': 'ws',
            'path': uri.queryParameters['path'] ?? '/',
            if (uri.queryParameters['host'] != null)
              'headers': {'Host': uri.queryParameters['host']!},
          };
        } else if (netType == 'grpc') {
          transport = {
            'type': 'grpc',
            if (uri.queryParameters['serviceName'] != null)
              'service_name': uri.queryParameters['serviceName']!,
          };
        }

        return {
          'type': 'vless',
          'tag': tag,
          'server': uri.host,
          'server_port': uri.port == 0 ? 443 : uri.port,
          'uuid': uri.userInfo,
          if (uri.queryParameters['flow'] != null && uri.queryParameters['flow']!.isNotEmpty)
            'flow': uri.queryParameters['flow']!,
          'transport': ?transport,
          'tls': {
            'enabled': uri.queryParameters['security'] == 'tls' || uri.queryParameters['security'] == 'reality',
            'server_name': uri.queryParameters['sni'] ?? uri.queryParameters['host'] ?? uri.host,
            'insecure': uri.queryParameters['allowInsecure'] == '1',
            if (uri.queryParameters['security'] == 'reality')
              'reality': {
                'enabled': true,
                'public_key': uri.queryParameters['pbk'] ?? '',
                'short_id': uri.queryParameters['sid'] ?? '',
              },
            if (uri.queryParameters['fp'] != null)
              'utls': {
                'enabled': true,
                'fingerprint': uri.queryParameters['fp']!,
              },
          }
        };
      } else if (scheme == 'vmess') {
        // vmess:// base64 encoded JSON
        final base64Content = uriStr.substring(8);
        final jsonStr = utf8.decode(base64.decode(base64.normalize(base64Content)));
        final Map<String, dynamic> vmessMap = jsonDecode(jsonStr);

        Map<String, dynamic>? transport;
        final netType = (vmessMap['net'] ?? 'tcp').toString().toLowerCase();
        if (netType == 'ws') {
          transport = {
            'type': 'ws',
            'path': (vmessMap['path'] ?? '/').toString(),
            if (vmessMap['host'] != null)
              'headers': {'Host': vmessMap['host'].toString()},
          };
        } else if (netType == 'grpc') {
          transport = {
            'type': 'grpc',
            if (vmessMap['path'] != null)
              'service_name': vmessMap['path'].toString(),
          };
        }

        return {
          'type': 'vmess',
          'tag': vmessMap['ps'] ?? 'VMess',
          'server': vmessMap['add'] ?? '',
          'server_port': int.tryParse(vmessMap['port']?.toString() ?? '443') ?? 443,
          'uuid': vmessMap['id'] ?? '',
          'security': (vmessMap['scy'] ?? 'auto').toString(),
          'alter_id': int.tryParse(vmessMap['aid']?.toString() ?? '0') ?? 0,
          'transport': ?transport,
          'tls': {
            'enabled': vmessMap['tls'] == 'tls',
            'server_name': (vmessMap['sni'] ?? vmessMap['host'] ?? vmessMap['add'] ?? '').toString(),
          }
        };
      } else if (scheme == 'ss') {
        // ss://base64(method:password)@server:port#tag or ss://base64(method:password@server:port)#tag
        final rawNoScheme = uriStr.substring(5);
        final parts = rawNoScheme.split('#');
        final cleanPart = parts[0];
        final nodeTag = parts.length > 1 ? Uri.decodeComponent(parts[1]) : 'Shadowsocks';

        if (cleanPart.contains('@')) {
          final atParts = cleanPart.split('@');
          final userDecoded = utf8.decode(base64.decode(base64.normalize(atParts[0])));
          final colonIdx = userDecoded.indexOf(':');
          final method = colonIdx != -1 ? userDecoded.substring(0, colonIdx) : 'aes-256-gcm';
          final password = colonIdx != -1 ? userDecoded.substring(colonIdx + 1) : userDecoded;

          final hostPort = atParts[1].split(':');
          return {
            'type': 'shadowsocks',
            'tag': nodeTag,
            'server': hostPort[0],
            'server_port': int.tryParse(hostPort.length > 1 ? hostPort[1] : '8388') ?? 8388,
            'method': method,
            'password': password,
          };
        }
      }
    } catch (_) {}
    return null;
  }
}
