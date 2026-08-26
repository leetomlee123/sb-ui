import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';

class ConfigGenerator {
  static const Set<String> _groupTypes = {'selector', 'urltest', 'loadbalance'};
  static const Set<String> _proxyTypes = {
    'ss',
    'shadowsocks',
    'vmess',
    'vless',
    'trojan',
    'hysteria2',
    'hy2',
    'tuic',
    'wireguard',
    'socks',
    'http',
  };

  static Map<String, dynamic> generate({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
    List<Map<String, dynamic>> customRules = const [],
    Map<String, dynamic>? customDns,
    String? configDir,
  }) {
    // 1. Separate individual proxy nodes, local direct outbounds, and group outbounds
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

    // List of real remote proxy node tags (excludes local direct/block outbounds)
    final List<String> proxyNodeTags = rawNodes
        .where((e) => _proxyTypes.contains((e['type'] ?? '').toString().toLowerCase()))
        .map((e) => (e['tag'] ?? '').toString())
        .where((tag) => tag.isNotEmpty)
        .toList();

    // Fallback: if no typed proxy found, use all non-group node tags
    final List<String> allNodeTags = rawNodes
        .map((e) => (e['tag'] ?? '').toString())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final List<String> eligibleNodeTags = proxyNodeTags.isNotEmpty ? proxyNodeTags : allNodeTags;

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
    if (existingAutoGroup == null && eligibleNodeTags.isNotEmpty) {
      finalOutbounds.add({
        'type': 'urltest',
        'tag': 'Auto',
        'outbounds': List<String>.from(eligibleNodeTags),
        'url': 'https://www.gstatic.com/generate_204',
        'interval': '2m',
        'tolerance': 50,
      });
      autoGroupTag = 'Auto';
    } else if (existingAutoGroup != null) {
      // Respect user's explicit group membership; do NOT forcibly inject direct outbounds
      existingAutoGroup['interval'] ??= '2m';
      existingAutoGroup['tolerance'] ??= 50;
    }

    // 3. Add or enhance primary selector group (e.g. "节点选择" or "Proxy")
    String primaryProxyTag = existingProxyGroup != null ? (existingProxyGroup['tag'] ?? 'Proxy').toString() : 'Proxy';
    final preferredNode = settings.selectedProxyNode;

    if (existingProxyGroup == null) {
      final List<String> proxyDestinations = [
        if (existingAutoGroup != null || eligibleNodeTags.isNotEmpty) autoGroupTag,
        ...allNodeTags,
        'direct',
      ];
      final defaultTarget = (preferredNode.isNotEmpty && proxyDestinations.contains(preferredNode))
          ? preferredNode
          : (existingAutoGroup != null ? autoGroupTag : (eligibleNodeTags.isNotEmpty ? autoGroupTag : 'direct'));

      finalOutbounds.add({
        'type': 'selector',
        'tag': 'Proxy',
        'outbounds': proxyDestinations,
        'default': defaultTarget,
      });
      primaryProxyTag = 'Proxy';
    }

    // 4. Append existing user groups
    for (final g in rawGroups) {
      finalOutbounds.add(g);
    }

    // 5. Built-in system outbounds
    String? proxyInterface;
    for (final node in rawNodes) {
      final iface = node['bind_interface']?.toString();
      if (iface != null && iface.isNotEmpty) {
        proxyInterface = iface;
        break;
      }
    }

    finalOutbounds.add({
      'type': 'direct',
      'tag': 'direct',
      'bind_interface': ?proxyInterface,
    });
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
          sanitized = eligibleNodeTags.isNotEmpty ? List<String>.from(eligibleNodeTags) : ['direct'];
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
      final ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      final List<String> routeExcludeAddresses = [];
      for (final ob in finalOutbounds) {
        final type = (ob['type'] ?? '').toString().toLowerCase();
        if (_proxyTypes.contains(type)) {
          final server = (ob['server'] ?? '').toString().trim();
          if (ipv4Regex.hasMatch(server)) {
            final cidr = '$server/32';
            if (!routeExcludeAddresses.contains(cidr)) {
              routeExcludeAddresses.add(cidr);
            }
          }
        }
      }

      final tunStack = (settings.tunStack == 'mixed' || settings.tunStack.isEmpty)
          ? 'system'
          : settings.tunStack;

      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'interface_name': 'singbox-tun',
        'address': [
          '172.19.0.1/30',
        ],
        'auto_route': true,
        'strict_route': false,
        if (routeExcludeAddresses.isNotEmpty) 'route_exclude_address': routeExcludeAddresses,
        'stack': tunStack,
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
    ];

    // Inject custom profile rules (e.g. Clash PROCESS-NAME, DOMAIN-SUFFIX, IP-CIDR) with highest priority
    if (customRules.isNotEmpty) {
      final List<Map<String, dynamic>> mergedCustomRules = [];
      for (final rule in customRules) {
        final target = rule['outbound']?.toString();
        final hasCondition = rule.keys.any((k) => k != 'outbound');
        if (target == null || !allExistingTags.contains(target) || !hasCondition) {
          continue;
        }

        final matchKey = rule.keys.firstWhere((k) => k != 'outbound');
        final matchVal = rule[matchKey];

        if (mergedCustomRules.isNotEmpty &&
            mergedCustomRules.last['outbound'] == target &&
            mergedCustomRules.last.containsKey(matchKey)) {
          final prevList = mergedCustomRules.last[matchKey] as List<dynamic>;
          if (matchVal is List) {
            for (final item in matchVal) {
              if (!prevList.contains(item)) {
                prevList.add(item);
              }
            }
          } else if (!prevList.contains(matchVal)) {
            prevList.add(matchVal);
          }
        } else {
          final newRule = <String, dynamic>{};
          if (matchVal is List) {
            newRule[matchKey] = List<dynamic>.from(matchVal);
          } else {
            newRule[matchKey] = [matchVal];
          }
          newRule['outbound'] = target;
          mergedCustomRules.add(newRule);
        }
      }
      routeRules.addAll(mergedCustomRules);
    }

    routeRules.add({
      'ip_is_private': true,
      'outbound': 'direct',
    });

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

    final List<Map<String, dynamic>> dnsServers = [
      buildDnsServer('remote-dns', settings.remoteDns, detour: primaryProxyTag),
      buildDnsServer('local-dns', settings.directDns, detour: 'direct'),
    ];

    final List<Map<String, dynamic>> dnsRules = [];

    // Inject custom DNS policies (e.g. nameserver-policy)
    if (customDns != null) {
      final extraServers = customDns['servers'] as List<dynamic>?;
      if (extraServers != null) {
        String? intranetDetour;
        for (final ob in finalOutbounds) {
          if (ob['type'] == 'direct') {
            final tag = (ob['tag'] ?? '').toString();
            final iface = (ob['bind_interface'] ?? '').toString();
            if (tag.contains('内网') || iface == 'Wi-Fi') {
              intranetDetour = tag;
              break;
            }
          }
        }

        for (final s in extraServers) {
          if (s is Map<String, dynamic>) {
            final copy = Map<String, dynamic>.from(s);
            if (intranetDetour != null && copy['detour'] == null) {
              copy['detour'] = intranetDetour;
            }
            // Normalize legacy 'address' field to 1.12+ 'type' + 'server'
            if (copy['server'] == null && copy['address'] != null) {
              final converted = buildDnsServer(
                (copy['tag'] ?? 'custom-dns').toString(),
                copy['address'].toString(),
                detour: copy['detour']?.toString(),
              );
              dnsServers.add(converted);
            } else {
              dnsServers.add(copy);
            }
          }
        }
      }
      final extraRules = customDns['rules'] as List<dynamic>?;
      if (extraRules != null) {
        for (final r in extraRules) {
          if (r is Map<String, dynamic>) {
            dnsRules.add(r);
          }
        }
      }
    }

    dnsRules.addAll([
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
    ]);

    final String geoipPath = (configDir != null && configDir.isNotEmpty)
        ? p.join(configDir, 'geoip-cn.srs').replaceAll(r'\', '/')
        : 'geoip-cn.srs';
    final String geositePath = (configDir != null && configDir.isNotEmpty)
        ? p.join(configDir, 'geosite-cn.srs').replaceAll(r'\', '/')
        : 'geosite-cn.srs';

    final String? logPath = (configDir != null && configDir.isNotEmpty)
        ? p.join(configDir, 'sing-box.log').replaceAll(r'\', '/')
        : null;

    final config = {
      'log': {
        'level': settings.logLevel,
        'timestamp': true,
        'output': ?logPath,
      },
      'dns': {
        'servers': dnsServers,
        'rules': dnsRules,
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
            'path': geoipPath,
          },
          {
            'type': 'local',
            'tag': 'geosite-cn',
            'format': 'binary',
            'path': geositePath,
          }
        ],
        'final': primaryProxyTag,
        'default_interface': ?proxyInterface,
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

  /// Builds a sing-box 1.12+ compliant DNS server object (type + server).
  static Map<String, dynamic> buildDnsServer(String tag, String address, {String? detour}) {
    final trimmed = address.trim();
    final effectiveDetour = (detour != null && detour.isNotEmpty) ? detour : null;

    if (trimmed.isEmpty || trimmed == 'local') {
      return {
        'tag': tag,
        'type': 'local',
        'detour': ?effectiveDetour,
      };
    }

    // 1. https:// (DoH)
    if (trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final host = uri.host;
        final port = uri.hasPort ? uri.port : 443;
        final path = uri.path.isNotEmpty ? uri.path : '/dns-query';
        return {
          'tag': tag,
          'type': 'https',
          'server': host,
          if (port != 443) 'server_port': port,
          'path': path,
          'detour': ?effectiveDetour,
        };
      }
    }

    // 2. tls:// (DoT)
    if (trimmed.startsWith('tls://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final host = uri.host;
        final port = uri.hasPort ? uri.port : 853;
        return {
          'tag': tag,
          'type': 'tls',
          'server': host,
          if (port != 853) 'server_port': port,
          'detour': ?effectiveDetour,
        };
      }
    }

    // 3. quic:// or h3://
    if (trimmed.startsWith('quic://') || trimmed.startsWith('h3://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final isH3 = trimmed.startsWith('h3://');
        final host = uri.host;
        final port = uri.hasPort ? uri.port : (isH3 ? 443 : 853);
        return {
          'tag': tag,
          'type': isH3 ? 'h3' : 'quic',
          'server': host,
          'server_port': port,
          if (isH3 && uri.path.isNotEmpty) 'path': uri.path,
          'detour': ?effectiveDetour,
        };
      }
    }

    // 4. tcp://
    if (trimmed.startsWith('tcp://')) {
      final stripped = trimmed.substring(6);
      final parts = stripped.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) : 53;
      return {
        'tag': tag,
        'type': 'tcp',
        'server': host,
        if (port != null && port != 53) 'server_port': port,
        'detour': ?effectiveDetour,
      };
    }

    // 5. Standard IP or host (UDP)
    String host = trimmed;
    int? port;
    if (trimmed.startsWith('udp://')) {
      host = trimmed.substring(6);
    }
    if (host.contains(':') && !host.contains(']')) {
      final parts = host.split(':');
      host = parts[0];
      port = int.tryParse(parts[1]);
    }
    return {
      'tag': tag,
      'type': 'udp',
      'server': host,
      if (port != null && port != 53) 'server_port': port,
      'detour': ?effectiveDetour,
    };
  }

  static String generateJsonString({
    required AppSettings settings,
    required List<Map<String, dynamic>> parsedOutbounds,
    String? configDir,
  }) {
    final map = generate(
      settings: settings,
      parsedOutbounds: parsedOutbounds,
      configDir: configDir,
    );
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
