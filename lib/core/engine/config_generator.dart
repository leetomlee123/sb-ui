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

    // 3. Built-in system outbounds
    outbounds.add({'type': 'direct', 'tag': 'direct'});
    outbounds.add({'type': 'block', 'tag': 'block'});
    outbounds.add({'type': 'dns', 'tag': 'dns-out'});

    // 4. Append user nodes
    outbounds.addAll(parsedOutbounds);

    // Inbounds list
    final List<Map<String, dynamic>> inbounds = [
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': settings.allowLan ? '0.0.0.0' : '127.0.0.1',
        'listen_port': settings.mixedPort,
        'sniff': true,
        'sniff_override_destination': true,
      },
    ];

    // TUN Inbound (if enabled)
    if (settings.tunModeEnabled) {
      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': 'singbox-tun',
        'inet4_address': '172.19.0.1/30',
        'auto_route': true,
        'strict_route': true,
        'stack': settings.tunStack,
        'sniff': true,
        'sniff_override_destination': true,
      });
    }

    // Route rules based on routingMode
    final List<Map<String, dynamic>> routeRules = [
      {
        'protocol': 'dns',
        'outbound': 'dns-out',
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
          {
            'tag': 'remote-dns',
            'address': settings.remoteDns,
            'detour': 'Proxy',
          },
          {
            'tag': 'local-dns',
            'address': settings.directDns,
            'detour': 'direct',
          },
          {
            'tag': 'block-dns',
            'address': 'rcode://success',
          }
        ],
        'rules': [
          {
            'outbound': 'any',
            'server': 'local-dns',
          },
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
        'clash_api': {
          'external_controller': '127.0.0.1:${settings.clashApiPort}',
          if (settings.clashApiSecret.isNotEmpty) 'secret': settings.clashApiSecret,
          'store_selected': true,
        }
      }
    };

    return config;
  }

  static String generateJsonString({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
  }) {
    final map = generate(settings: settings, parsedOutbounds: parsedOutbounds);
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
