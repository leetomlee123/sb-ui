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

    final List<Map<String, dynamic>> finalOutbounds = [];

    // Check if user already defined a primary Selector group or Auto group
    Map<String, dynamic>? existingProxyGroup;
    Map<String, dynamic>? existingAutoGroup;

    const proxyGroupKeywords = ['proxy', 'proxies', '节点选择', '节点', 'select', 'default', 'main', '国外流量', '漏网之鱼'];
    const autoGroupKeywords = ['auto', 'urltest', 'url-test', 'auto-select', '自动选择', '自动优选', '自动', 'fallback', 'fastest'];

    for (final g in rawGroups) {
      final tag = (g['tag'] ?? '').toString();
      final tagLower = tag.toLowerCase();
      final type = (g['type'] ?? '').toString().toLowerCase();

      if (existingProxyGroup == null && (proxyGroupKeywords.any((k) => tagLower.contains(k) || tag.contains(k)) || type == 'selector')) {
        existingProxyGroup = g;
      }
      if (existingAutoGroup == null && (autoGroupKeywords.any((k) => tagLower.contains(k) || tag.contains(k)) || type == 'urltest')) {
        existingAutoGroup = g;
      }
    }

    // 2. Add or enhance "Auto" URL-Test if proxy nodes exist
    String autoGroupTag = existingAutoGroup != null ? (existingAutoGroup['tag'] ?? 'Auto').toString() : 'Auto';
    if (existingAutoGroup == null && nodeTags.isNotEmpty) {
      finalOutbounds.add({
        'type': 'urltest',
        'tag': 'Auto',
        'outbounds': List<String>.from(nodeTags),
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '2m',
        'tolerance': 50,
      });
      autoGroupTag = 'Auto';
    } else if (existingAutoGroup != null && nodeTags.isNotEmpty) {
      final existingOutbounds = (existingAutoGroup['outbounds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final mergedOutbounds = <String>{...existingOutbounds, ...nodeTags}.toList();
      existingAutoGroup['outbounds'] = mergedOutbounds;
      existingAutoGroup['interval'] = '2m';
      existingAutoGroup['tolerance'] = 50;
    }

    // 3. Add or enhance primary selector group (e.g. "节点选择" or "Proxy")
    String primaryProxyTag = existingProxyGroup != null ? (existingProxyGroup['tag'] ?? 'Proxy').toString() : 'Proxy';
    final preferredNode = settings.selectedProxyNode;

    if (existingProxyGroup == null) {
      final List<String> proxyDestinations = [
        if (nodeTags.isNotEmpty) autoGroupTag,
        ...nodeTags,
        'direct',
      ];
      final defaultTarget = (preferredNode.isNotEmpty && proxyDestinations.contains(preferredNode))
          ? preferredNode
          : (nodeTags.isNotEmpty ? autoGroupTag : 'direct');

      finalOutbounds.add({
        'type': 'selector',
        'tag': 'Proxy',
        'outbounds': proxyDestinations,
        'default': defaultTarget,
      });
      primaryProxyTag = 'Proxy';
    } else {
      final existingOutbounds = (existingProxyGroup['outbounds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      if (nodeTags.isNotEmpty && !existingOutbounds.contains(autoGroupTag)) {
        existingOutbounds.insert(0, autoGroupTag);
      }
      existingProxyGroup['outbounds'] = existingOutbounds;
      if (preferredNode.isNotEmpty && existingOutbounds.contains(preferredNode)) {
        existingProxyGroup['default'] = preferredNode;
      } else if (nodeTags.isNotEmpty && existingProxyGroup['default'] == null) {
        existingProxyGroup['default'] = autoGroupTag;
      }
    }

    // 4. Append existing user groups
    for (final g in rawGroups) {
      finalOutbounds.add(g);
    }

    // 5. Built-in system outbounds
    finalOutbounds.add({'type': 'direct', 'tag': 'direct'});
    finalOutbounds.add({'type': 'block', 'tag': 'block'});

    // 6. Append all individual proxy nodes
    finalOutbounds.addAll(rawNodes);

    // 7. CRITICAL SANITIZATION PASS:
    // Ensure every destination tag referenced in any group actually exists in finalOutbounds
    final Set<String> allExistingTags = {
      'direct',
      'block',
      ...finalOutbounds.map((o) => (o['tag'] ?? '').toString()).where((t) => t.isNotEmpty),
    };

    for (final ob in finalOutbounds) {
      final type = (ob['type'] ?? '').toString().toLowerCase();
      if (_groupTypes.contains(type)) {
        final rawList = ob['outbounds'];
        final thisTag = (ob['tag'] ?? '').toString();
        List<String> sanitized = [];

        if (rawList is List) {
          sanitized = rawList
              .map((e) => e.toString())
              .where((t) => allExistingTags.contains(t) && t != thisTag)
              .toList();
        }

        // If list became empty, fallback to available node tags or direct
        if (sanitized.isEmpty) {
          sanitized = nodeTags.isNotEmpty ? List<String>.from(nodeTags) : ['direct'];
        }

        ob['outbounds'] = sanitized;

        // Ensure default field is also valid if specified
        if (ob['default'] != null && !allExistingTags.contains(ob['default'].toString())) {
          ob.remove('default');
        }
      }
    }

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
        'outbound': primaryProxyTag,
      });
    } else if (settings.routingMode == RoutingMode.direct) {
      routeRules.add({
        'outbound': 'direct',
      });
    } else {
      // Rule mode: bypass CN sites/IPs, route rest to primaryProxyTag
      routeRules.addAll([
        {
          'clash_mode': 'Direct',
          'outbound': 'direct',
        },
        {
          'clash_mode': 'Global',
          'outbound': primaryProxyTag,
        },
        {
          'rule_set': ['geoip-cn', 'geosite-cn'],
          'outbound': 'direct',
        },
        {
          'outbound': primaryProxyTag,
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
          _buildDnsServer('remote-dns', settings.remoteDns, detour: primaryProxyTag),
          _buildDnsServer('local-dns', settings.directDns),
        ],
        'rules': [
          {
            'domain_suffix': [
              '.cn',
              'jsdelivr.net',
              'jsdelivr.com',
              'aliyun.com',
              'alicdn.com',
              '189.cn',
              'qq.com',
              'baidu.com',
            ],
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
      'outbounds': finalOutbounds,
      'route': {
        'default_domain_resolver': 'local-dns',
        'rules': routeRules,
        'rule_set': [
          {
            'type': 'local',
            'tag': 'geoip-cn',
            'format': 'binary',
            'path': 'geoip-cn.srs',
          },
          {
            'type': 'local',
            'tag': 'geosite-cn',
            'format': 'binary',
            'path': 'geosite-cn.srs',
          }
        ],
        'final': primaryProxyTag,
        'auto_detect_interface': true,
      },
      'experimental': {
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
    final effectiveDetour = (detour != null && detour.isNotEmpty && detour != 'direct') ? detour : null;
    if (trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'https',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 443) 'server_port': uri.port,
        if (uri.path.isNotEmpty && uri.path != '/') 'path': uri.path,
        'detour': ?effectiveDetour,
      };
    } else if (trimmed.startsWith('tls://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'tls',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 853) 'server_port': uri.port,
        'detour': ?effectiveDetour,
      };
    } else if (trimmed.startsWith('tcp://')) {
      final uri = Uri.parse(trimmed);
      return {
        'tag': tag,
        'type': 'tcp',
        'server': uri.host,
        if (uri.port != 0 && uri.port != 53) 'server_port': uri.port,
        'detour': ?effectiveDetour,
      };
    } else {
      return {
        'tag': tag,
        'type': 'udp',
        'server': trimmed.replaceAll('udp://', ''),
        'detour': ?effectiveDetour,
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
