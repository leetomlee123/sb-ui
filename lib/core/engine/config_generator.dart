import 'dart:convert';
import '../models/app_settings.dart';

class ConfigGenerator {
  static Map<String, dynamic> generate({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
  }) {
    final List<String> nodeTags = parsedOutbounds
        .map((e) => (e['tag'] ?? '').toString())
        .where((tag) => tag.isNotEmpty)
        .toList();

    // Strategy groups
    final List<Map<String, dynamic>> outbounds = [];

    // 1. "Proxy" selector group
    final List<String> proxyGroupOutbounds = ['Auto', ...nodeTags, 'direct'];
    outbounds.add({
      'type': 'selector',
      'tag': 'Proxy',
      'outbounds': proxyGroupOutbounds.isEmpty ? ['direct'] : proxyGroupOutbounds,
      'default': nodeTags.isNotEmpty ? nodeTags.first : 'direct',
    });

    // 2. "Auto" URL-Test group
    if (nodeTags.isNotEmpty) {
      outbounds.add({
        'type': 'urltest',
        'tag': 'Auto',
        'outbounds': nodeTags,
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '10m',
        'tolerance': 50,
      });
    }

    // 3. Built-in system outbounds (Note: dns outbound deprecated in 1.11+ and removed in 1.13+)
    outbounds.add({'type': 'direct', 'tag': 'direct'});
    outbounds.add({'type': 'block', 'tag': 'block'});

    // 4. Append user nodes
    outbounds.addAll(parsedOutbounds);

    // Inbounds list
    final List<Map<String, dynamic>> inbounds = [
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': settings.allowLan ? '0.0.0.0' : '127.0.0.1',
        'listen_port': settings.mixedPort,
      },
    ];

    // TUN Inbound (if enabled)
    if (settings.tunModeEnabled) {
      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': 'singbox-tun',
        'address': ['172.19.0.1/30'],
        'auto_route': true,
        'strict_route': true,
        'stack': settings.tunStack,
      });
    }

    // Route rules based on routingMode
    final List<Map<String, dynamic>> routeRules = [
      {
        'action': 'sniff',
      },
      {
        'protocol': 'dns',
        'action': 'hijack-dns',
      },
      {
        'ip_is_private': true,
        'outbound': 'direct',
      },
    ];

    if (settings.routingMode == RoutingMode.global) {
      routeRules.add({
        'outbound': 'Proxy',
      });
    } else if (settings.routingMode == RoutingMode.direct) {
      routeRules.add({
        'outbound': 'direct',
      });
    } else {
      // Rule mode: bypass CN sites/IPs, route rest to Proxy
      routeRules.addAll([
        {
          'clash_mode': 'Direct',
          'outbound': 'direct',
        },
        {
          'clash_mode': 'Global',
          'outbound': 'Proxy',
        },
        {
          'rule_set': ['geoip-cn', 'geosite-cn'],
          'outbound': 'direct',
        },
        {
          'outbound': 'Proxy',
        }
      ]);
    }

    final config = {
      'log': {
        'level': settings.logLevel,
        'timestamp': true,
      },
      'dns': {
        'servers': [
          _buildDnsServer('remote-dns', settings.remoteDns, detour: 'Proxy'),
          _buildDnsServer('local-dns', settings.directDns, detour: 'direct'),
        ],
        'rules': [
          {
            'rule_set': 'geosite-cn',
            'server': 'local-dns',
          },
          {
            'clash_mode': 'Direct',
            'server': 'local-dns',
          },
          {
            'clash_mode': 'Global',
            'server': 'remote-dns',
          }
        ],
        'final': 'remote-dns',
        'strategy': 'prefer_ipv4',
      },
      'inbounds': inbounds,
      'outbounds': outbounds,
      'route': {
        'default_domain_resolver': 'local-dns',
        'rules': routeRules,
        'rule_set': [
          {
            'type': 'remote',
            'tag': 'geoip-cn',
            'format': 'binary',
            'url': 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
            'download_detour': 'direct',
          },
          {
            'type': 'remote',
            'tag': 'geosite-cn',
            'format': 'binary',
            'url': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
            'download_detour': 'direct',
          }
        ],
        'final': 'Proxy',
        'auto_detect_interface': true,
      },
      'experimental': {
        'cache_file': {
          'enabled': true,
        },
        'clash_api': {
          'external_controller': '127.0.0.1:${settings.clashApiPort}',
          if (settings.clashApiSecret.isNotEmpty) 'secret': settings.clashApiSecret,
        }
      }
    };

    return config;
  }

  static Map<String, dynamic> _buildDnsServer(String tag, String address, {String? detour}) {
    final trimmed = address.trim();
    if (trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'https',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 443) 'server_port': uri.port,
        if (uri.path.isNotEmpty && uri.path != '/') 'path': uri.path,
        'detour': ?detour,
      };
    } else if (trimmed.startsWith('tls://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'tls',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 853) 'server_port': uri.port,
        'detour': ?detour,
      };
    } else if (trimmed.startsWith('tcp://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'tcp',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 53) 'server_port': uri.port,
        'detour': ?detour,
      };
    } else {
      return {
        'tag': tag,
        'type': 'udp',
        'server': trimmed.replaceAll('udp://', ''),
        'detour': ?detour,
      };
    }
  }

  static String generateJsonString({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
  }) {
    final map = generate(settings: settings, parsedOutbounds: parsedOutbounds);
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
