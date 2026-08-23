import 'dart:convert';
import '../models/app_settings.dart';

class ConfigGenerator {
  static const Set<String> _groupTypes = {'selector', 'urltest', 'loadbalance'};

  static Map<String, dynamic> generate({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
  }) {
    // 1. Separate individual proxy nodes from existing group outbounds
    final List<Map<String, dynamic>> rawNodes = [];
    final List<Map<String, dynamic>> rawGroups = [];

    for (final ob in parsedOutbounds) {
      final type = (ob['type'] ?? '').toString().toLowerCase();
      if (_groupTypes.contains(type)) {
        rawGroups.add(Map<String, dynamic>.from(ob));
      } else {
        rawNodes.add(Map<String, dynamic>.from(ob));
      }
    }

    // List of individual proxy node tags
    final List<String> nodeTags = rawNodes
        .map((e) => (e['tag'] ?? '').toString())
        .where((tag) => tag.isNotEmpty)
        .toList();

    // 2. Set of all valid destination tags (built-in + user nodes)
    final Set<String> validDestTags = {'direct', 'block', ...nodeTags};

    final List<Map<String, dynamic>> finalOutbounds = [];

    // Check if user already defined a "Proxy" or "Auto" group
    final bool hasCustomProxyGroup = rawGroups.any(
      (g) => (g['tag'] ?? '').toString().toLowerCase() == 'proxy',
    );
    final bool hasCustomAutoGroup = rawGroups.any(
      (g) => (g['tag'] ?? '').toString().toLowerCase() == 'auto',
    );

    // 3. Add default "Proxy" selector if not already defined
    if (!hasCustomProxyGroup) {
      final List<String> proxyDestinations = [
        if (nodeTags.isNotEmpty) 'Auto',
        ...nodeTags,
        'direct',
      ];
      finalOutbounds.add({
        'type': 'selector',
        'tag': 'Proxy',
        'outbounds': proxyDestinations,
        'default': nodeTags.isNotEmpty ? nodeTags.first : 'direct',
      });
      validDestTags.add('Proxy');
    }

    // 4. Add default "Auto" URL-Test if not already defined and nodes exist
    if (!hasCustomAutoGroup && nodeTags.isNotEmpty) {
      finalOutbounds.add({
        'type': 'urltest',
        'tag': 'Auto',
        'outbounds': List<String>.from(nodeTags),
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '10m',
        'tolerance': 50,
      });
      validDestTags.add('Auto');
    }

    // 5. Sanitize and append existing user groups
    for (final group in rawGroups) {
      final groupTag = (group['tag'] ?? '').toString();
      validDestTags.add(groupTag);
    }

    for (final group in rawGroups) {
      final rawList = group['outbounds'];
      List<String> sanitizedList = [];

      if (rawList is List) {
        sanitizedList = rawList
            .map((e) => e.toString())
            .where((tag) => validDestTags.contains(tag) && tag != group['tag'])
            .toList();
      }

      // If all referenced nodes were missing or empty, fallback to available nodes or direct
      if (sanitizedList.isEmpty) {
        sanitizedList = nodeTags.isNotEmpty ? List<String>.from(nodeTags) : ['direct'];
      }

      group['outbounds'] = sanitizedList;
      finalOutbounds.add(group);
    }

    // 6. Built-in system outbounds
    finalOutbounds.add({'type': 'direct', 'tag': 'direct'});
    finalOutbounds.add({'type': 'block', 'tag': 'block'});

    // 7. Append all individual proxy nodes
    finalOutbounds.addAll(rawNodes);

    // 8. Inbounds list
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

    // 9. Route rules based on routingMode
    final String primaryOutboundTag = hasCustomProxyGroup ? rawGroups.firstWhere((g) => (g['tag'] ?? '').toString().toLowerCase() == 'proxy')['tag'] : 'Proxy';

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
        'outbound': primaryOutboundTag,
      });
    } else if (settings.routingMode == RoutingMode.direct) {
      routeRules.add({
        'outbound': 'direct',
      });
    } else {
      // Rule mode: bypass CN sites/IPs, route rest to primaryOutboundTag
      routeRules.addAll([
        {
          'clash_mode': 'Direct',
          'outbound': 'direct',
        },
        {
          'clash_mode': 'Global',
          'outbound': primaryOutboundTag,
        },
        {
          'rule_set': ['geoip-cn', 'geosite-cn'],
          'outbound': 'direct',
        },
        {
          'outbound': primaryOutboundTag,
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
          _buildDnsServer('remote-dns', settings.remoteDns, detour: primaryOutboundTag),
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
      'outbounds': finalOutbounds,
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
        'final': primaryOutboundTag,
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
