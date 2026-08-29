import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singular/core/engine/default_config_template.dart';
import 'package:singular/core/engine/profile_parser.dart';
import 'package:singular/core/engine/config_generator.dart';
import 'package:singular/core/models/app_settings.dart';
import 'package:singular/core/models/profile.dart';
import 'package:singular/core/models/proxy_node.dart';
import 'package:singular/core/providers/profiles_provider.dart';
import 'package:singular/core/providers/proxies_provider.dart';
import 'package:singular/core/providers/storage_provider.dart';
import 'package:singular/core/services/storage_service.dart';
import 'package:singular/core/utils/proxy_flag_helper.dart';
import 'package:singular/features/profiles/widgets/config_editor_dialog.dart';
import 'package:singular/features/profiles/widgets/visual_config_editor.dart';
import 'package:singular/features/shell/main_shell_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ProfileParser and ConfigGenerator test', () {
    const rawClash = '''
proxies:
  - name: "HK-Node-01"
    type: ss
    server: 1.2.3.4
    port: 8388
    cipher: aes-256-gcm
    password: mypassword
  - name: "US-Node-02"
    type: trojan
    server: 5.6.7.8
    port: 443
    password: trojanpassword
    sni: us.example.com
  - name: "vless-cdn"
    type: vless
    server: 9.10.11.12
    port: 443
    uuid: 00000000-0000-0000-0000-000000000000
    network: ws
    ws-opts:
      path: /ws
      headers:
        Host: cdn.example.com
    tls: true
    servername: cdn.example.com

proxy-groups:
  - name: auto
    type: url-test
    proxies:
      - vless-cdn
      - non-existent-node
''';

    final result = ProfileParser.parse(rawClash);
    expect(result.count, 4); // 3 proxies + 1 group

    const settings = AppSettings(
      mixedPort: 7890,
      clashApiPort: 9090,
      systemProxyEnabled: true,
      tunModeEnabled: false,
    );

    final generated = ConfigGenerator.generate(
      settings: settings,
      parsedOutbounds: result.outbounds,
    );

    expect(generated['inbounds'], isNotEmpty);
    expect(generated['outbounds'], isNotEmpty);
    expect(generated['route'], isNotNull);
    expect(
      generated['experimental']['clash_api']['external_controller'],
      '127.0.0.1:9090',
    );

    final outboundsList = generated['outbounds'] as List;
    final allTags = outboundsList.map((o) => o['tag'].toString()).toSet();

    // Verify auto group sanitized non-existent-node
    final autoGroup = outboundsList.firstWhere((o) => o['tag'] == 'auto');
    expect(autoGroup['outbounds'], contains('vless-cdn'));
    expect(autoGroup['outbounds'], isNot(contains('non-existent-node')));

    // Verify Proxy group dependencies ALL exist in allTags
    final proxyGroup = outboundsList.firstWhere((o) => o['tag'] == 'Proxy');
    for (final dest in proxyGroup['outbounds'] as List) {
      expect(
        allTags.contains(dest) || ['direct', 'block'].contains(dest),
        isTrue,
        reason: 'Dependency $dest must exist in outbounds',
      );
    }

    // Verify preferred selectedProxyNode is set as default in Proxy group
    const customNodeSettings = AppSettings(selectedProxyNode: 'HK-Node-01');
    final customGenerated = ConfigGenerator.generate(
      settings: customNodeSettings,
      parsedOutbounds: result.outbounds,
    );
    final customProxyGroup = (customGenerated['outbounds'] as List).firstWhere(
      (o) => o['tag'] == 'Proxy',
    );
    expect(customProxyGroup['default'], 'HK-Node-01');
  });

  test('AppSettings serialization and defaults', () {
    const defaultSettings = AppSettings();
    expect(defaultSettings.closeToTray, isTrue);
    expect(defaultSettings.hasAskedCloseToTray, isFalse);
    expect(defaultSettings.mixedPort, 7890);
    expect(defaultSettings.clashApiPort, 9090);
    expect(defaultSettings.autoUpdateRuleset, isTrue);
    expect(defaultSettings.tunStack, 'mixed');
    expect(defaultSettings.fakeIpEnabled, isFalse);
    expect(defaultSettings.fakeIpRange, '198.18.0.0/15');
    expect(defaultSettings.dnsHijack, isTrue);
    expect(defaultSettings.dnsStrategy, 'prefer_ipv4');
    expect(defaultSettings.separateInboundPorts, isFalse);
    expect(defaultSettings.httpPort, 7890);
    expect(defaultSettings.socksPort, 7891);
    expect(defaultSettings.blockAds, isFalse);
    expect(defaultSettings.aiServicesRoute, 'proxy');
    expect(defaultSettings.streamMediaRoute, 'proxy');
    expect(defaultSettings.tunGso, isFalse);
    expect(defaultSettings.tunIpv6, isFalse);
    expect(defaultSettings.tunMtu, 9000);
    expect(defaultSettings.tunStrictRoute, isTrue);
    expect(defaultSettings.sniffingEnabled, isTrue);
    expect(defaultSettings.sniffingOverrideDestination, isTrue);
    expect(defaultSettings.tcpFastOpen, isFalse);
    expect(defaultSettings.multiplex, 'none');

    final json = defaultSettings.toJson();
    final restored = AppSettings.fromJson(json);
    expect(restored.closeToTray, isTrue);
    expect(restored.hasAskedCloseToTray, isFalse);
    expect(restored.autoUpdateRuleset, isTrue);
    expect(restored.tunStack, 'mixed');
    expect(restored.fakeIpEnabled, isFalse);
    expect(restored.fakeIpRange, '198.18.0.0/15');
    expect(restored.dnsHijack, isTrue);
    expect(restored.dnsStrategy, 'prefer_ipv4');
    expect(restored.separateInboundPorts, isFalse);
    expect(restored.httpPort, 7890);
    expect(restored.socksPort, 7891);
    expect(restored.blockAds, isFalse);
    expect(restored.aiServicesRoute, 'proxy');
    expect(restored.streamMediaRoute, 'proxy');
    expect(restored.tunGso, isFalse);
    expect(restored.tunIpv6, isFalse);
    expect(restored.tunMtu, 9000);
    expect(restored.tunStrictRoute, isTrue);
    expect(restored.sniffingEnabled, isTrue);
    expect(restored.sniffingOverrideDestination, isTrue);
    expect(restored.tcpFastOpen, isFalse);
    expect(restored.multiplex, 'none');

    final updated = defaultSettings.copyWith(
      hasAskedCloseToTray: true,
      closeToTray: false,
      autoUpdateRuleset: false,
      fakeIpEnabled: true,
      separateInboundPorts: true,
      httpPort: 1080,
      socksPort: 1081,
      blockAds: true,
      aiServicesRoute: 'direct',
      tunGso: true,
      tunIpv6: true,
      tunMtu: 1500,
      tcpFastOpen: true,
      multiplex: 'yamux',
    );
    expect(updated.hasAskedCloseToTray, isTrue);
    expect(updated.closeToTray, isFalse);
    expect(updated.autoUpdateRuleset, isFalse);
    expect(updated.fakeIpEnabled, isTrue);
    expect(updated.separateInboundPorts, isTrue);
    expect(updated.httpPort, 1080);
    expect(updated.socksPort, 1081);
    expect(updated.blockAds, isTrue);
    expect(updated.aiServicesRoute, 'direct');
    expect(updated.tunGso, isTrue);
    expect(updated.tunIpv6, isTrue);
    expect(updated.tunMtu, 1500);
    expect(updated.tcpFastOpen, isTrue);
    expect(updated.multiplex, 'yamux');
  });

  test('ConfigGenerator advanced visual configurations (Fake-IP, inbounds, rules, TUN GSO, Multiplex)', () {
    const advancedSettings = AppSettings(
      fakeIpEnabled: true,
      fakeIpRange: '198.18.0.0/15',
      dnsHijack: true,
      dnsStrategy: 'prefer_ipv4',
      separateInboundPorts: true,
      httpPort: 8080,
      socksPort: 10808,
      blockAds: true,
      aiServicesRoute: 'proxy',
      streamMediaRoute: 'direct',
      tunModeEnabled: true,
      tunGso: true,
      tunIpv6: true,
      tunMtu: 1500,
      tunStrictRoute: true,
      sniffingEnabled: true,
      sniffingOverrideDestination: true,
      tcpFastOpen: true,
      multiplex: 'yamux',
    );

    final node = {
      'type': 'vless',
      'tag': 'US-Test-Node',
      'server': '1.2.3.4',
      'server_port': 443,
      'uuid': '00000000-0000-0000-0000-000000000000',
    };

    final config = ConfigGenerator.generate(
      settings: advancedSettings,
      parsedOutbounds: [node],
    );

    // 1. Inbounds: Separate HTTP and SOCKS
    final inbounds = config['inbounds'] as List;
    final httpIn = inbounds.firstWhere((i) => i['tag'] == 'http-in');
    expect(httpIn['type'], 'http');
    expect(httpIn['listen_port'], 8080);

    final socksIn = inbounds.firstWhere((i) => i['tag'] == 'socks-in');
    expect(socksIn['type'], 'socks');
    expect(socksIn['listen_port'], 10808);

    // 2. TUN: GSO, IPv6, MTU
    final tunIn = inbounds.firstWhere((i) => i['tag'] == 'tun-in');
    expect(tunIn['gso'], isTrue);
    expect(tunIn['address'], contains('fdfe:dcba:9876::1/126'));
    expect(tunIn['mtu'], 1500);

    // 3. DNS: Fake-IP
    final dns = config['dns'] as Map<String, dynamic>;
    expect(dns['final'], 'fakeip-dns');
    expect(dns['strategy'], 'prefer_ipv4');
    expect(dns['fakeip']['enabled'], isTrue);
    expect(dns['fakeip']['inet4_range'], '198.18.0.0/15');

    // 4. Route Rules: Sniff, Hijack DNS, AdBlock, AI, Streaming
    final rules = config['route']['rules'] as List;
    expect(rules.any((r) => r['action'] == 'sniff'), isTrue);
    expect(rules.any((r) => r['protocol'] == 'dns' && r['action'] == 'hijack-dns'), isTrue);
    expect(rules.any((r) => r['action'] == 'reject'), isTrue); // AdBlock
    expect(rules.any((r) => r['outbound'] == 'Proxy'), isTrue); // AI
    expect(rules.any((r) => r['outbound'] == 'direct'), isTrue); // Streaming direct

    // 5. Outbounds: TFO & Multiplex (yamux)
    final outbounds = config['outbounds'] as List;
    final testNode = outbounds.firstWhere((o) => o['tag'] == 'US-Test-Node');
    expect(testNode['tcp_fast_open'], isTrue);
    expect(testNode['multiplex']['enabled'], isTrue);
    expect(testNode['multiplex']['protocol'], 'yamux');
  });

  test('ConfigGenerator Reality and Hysteria 2 structure', () {
    final realityOutbound = {
      'type': 'vless',
      'tag': 'VLESS Reality HK',
      'server': '1.2.3.4',
      'server_port': 443,
      'uuid': '00000000-0000-0000-0000-000000000000',
      'tls': {
        'enabled': true,
        'server_name': 'hk.gateway.com',
        'utls': {'enabled': true, 'fingerprint': 'chrome'},
        'reality': {
          'enabled': true,
          'public_key': 'abc123publicKey==',
          'short_id': '1234abcd',
        },
      },
    };

    final hy2Outbound = {
      'type': 'hysteria2',
      'tag': 'Hy2 JP Node',
      'server': '5.6.7.8',
      'server_port': 8443,
      'password': 'hy2password',
      'up_mbps': 100,
      'down_mbps': 500,
      'obfs': {'type': 'salamander', 'password': 'obfspassword'},
    };

    final generated = ConfigGenerator.generate(
      settings: const AppSettings(),
      parsedOutbounds: [realityOutbound, hy2Outbound],
    );

    final outbounds = generated['outbounds'] as List;
    final reality = outbounds.firstWhere((o) => o['tag'] == 'VLESS Reality HK');
    expect(reality['tls']['reality']['enabled'], isTrue);
    expect(reality['tls']['reality']['public_key'], 'abc123publicKey==');

    final hy2 = outbounds.firstWhere((o) => o['tag'] == 'Hy2 JP Node');
    expect(hy2['type'], 'hysteria2');
    expect(hy2['up_mbps'], 100);
    expect(hy2['obfs']['type'], 'salamander');
  });

  test('ProfileParser in-memory LRU caching', () {
    ProfileParser.clearCache();
    const testContent =
        'proxies:\n  - name: test-ss\n    type: ss\n    server: 1.1.1.1\n    port: 8388\n    cipher: aes-128-gcm\n    password: pwd';

    final result1 = ProfileParser.parse(testContent);
    final result2 = ProfileParser.parse(testContent);
    expect(
      identical(result1, result2),
      isTrue,
      reason: 'Repeated parse should return identical cached instance',
    );

    ProfileParser.clearCache();
    final result3 = ProfileParser.parse(testContent);
    expect(
      identical(result1, result3),
      isFalse,
      reason: 'clearCache should flush the cached instance',
    );
    expect(result3.count, result1.count);
  });

  test('ProfileParser removeNodesFromContent removes dead nodes from JSON and Clash YAML', () {
    const jsonConfig = '''{
      "outbounds": [
        {"type": "hysteria2", "tag": "Node-OK", "server": "1.1.1.1"},
        {"type": "hysteria2", "tag": "Node-Dead", "server": "2.2.2.2"},
        {"type": "selector", "tag": "Proxy", "outbounds": ["Node-OK", "Node-Dead"]}
      ]
    }''';

    final cleanedJson = ProfileParser.removeNodesFromContent(jsonConfig, {'Node-Dead'});
    final parsedJson = ProfileParser.parse(cleanedJson);
    final tags = parsedJson.outbounds.map((o) => o['tag']).toList();
    expect(tags.contains('Node-OK'), isTrue);
    expect(tags.contains('Node-Dead'), isFalse);

    const yamlConfig = '''
proxies:
  - name: YAML-OK
    type: ss
    server: 1.1.1.1
    port: 8388
    cipher: aes-128-gcm
    password: pwd
  - name: YAML-Dead
    type: ss
    server: 2.2.2.2
    port: 8388
    cipher: aes-128-gcm
    password: pwd
proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - YAML-OK
      - YAML-Dead
''';

    final cleanedYaml = ProfileParser.removeNodesFromContent(yamlConfig, {'YAML-Dead'});
    final parsedYaml = ProfileParser.parse(cleanedYaml);
    final yamlTags = parsedYaml.outbounds.map((o) => o['tag']).toList();
    expect(yamlTags.contains('YAML-OK'), isTrue);
    expect(yamlTags.contains('YAML-Dead'), isFalse);
  });

  test('ProxiesNotifier stopTesting clears testing flags and removeUnavailableNodes preserves active delays', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    final notifier = container.read(proxiesProvider.notifier);

    // Seed state with 3 nodes (one working, one timeout, one in testing)
    notifier.state = notifier.state.copyWith(
      nodes: {
        'Node-Fast': ProxyNode(name: 'Node-Fast', type: OutboundType.vless, delay: 45),
        'Node-Dead': ProxyNode(name: 'Node-Dead', type: OutboundType.vless, delay: -1),
        'Node-Testing': ProxyNode(name: 'Node-Testing', type: OutboundType.vless, isTesting: true),
      },
      groups: {
        'Proxy': ProxyGroup(
          name: 'Proxy',
          type: OutboundType.selector,
          current: 'Node-Fast',
          all: ['Node-Fast', 'Node-Dead', 'Node-Testing'],
        ),
      },
      isTestingAll: true,
    );

    expect(container.read(proxiesProvider).isTestingAll, isTrue);
    expect(container.read(proxiesProvider).nodes['Node-Testing']!.isTesting, isTrue);

    // 1. Test stopTesting()
    notifier.stopTesting();
    expect(container.read(proxiesProvider).isTestingAll, isFalse);
    expect(container.read(proxiesProvider).nodes['Node-Testing']!.isTesting, isFalse);
    expect(container.read(proxiesProvider).nodes['Node-Fast']!.delay, 45);

    // 2. Test removeUnavailableNodes()
    final deletedCount = await notifier.removeUnavailableNodes();
    expect(deletedCount, 1);
    expect(container.read(proxiesProvider).nodes.containsKey('Node-Dead'), isFalse);
    expect(container.read(proxiesProvider).nodes.containsKey('Node-Fast'), isTrue);
    expect(container.read(proxiesProvider).nodes['Node-Fast']!.delay, 45); // Preserved delay!
  });

  test('Clash Dual-NIC interface binding, process rules, and DNS policy test', () {
    const yamlContent = '''
dns:
  enable: true
  ipv6: false
  nameserver:
    - 202.96.209.133
    - 114.114.114.114
  nameserver-policy:
    "cpic.com.cn": 202.96.209.133
    "*.cpic.com.cn": 202.96.209.133

proxies:
  - name: hy2-fast
    type: hysteria2
    server: 158.180.92.85
    port: 3366
    password: lix@2wsx
    tls: true
    servername: a.189.cn
    skip-cert-verify: true
    interface-name: Wi-Fi 2

  - name: 内网直连
    type: direct
    interface-name: Wi-Fi

  - name: 热点直连
    type: direct
    interface-name: Wi-Fi 2

proxy-groups:
  - name: auto
    type: url-test
    proxies:
      - hy2-fast
    url: https://www.gstatic.com/generate_204
    interval: 300

rules:
  - PROCESS-NAME,uSmartView.exe,内网直连
  - DOMAIN-KEYWORD,uSmart,内网直连
  - DOMAIN-SUFFIX,cpic.com.cn,内网直连
  - IP-CIDR,10.0.0.0/8,内网直连
  - MATCH,auto
''';

    final parseResult = ProfileParser.parse(yamlContent);
    expect(parseResult.outbounds.length, 4); // hy2-fast, 内网直连, 热点直连, auto group
    expect(
      parseResult.customRules.length,
      4,
    ); // 4 conditional rules (MATCH is skipped as fallback)
    expect(parseResult.customDns, isNotNull);

    // Verify outbounds
    final hy2 = parseResult.outbounds.firstWhere((o) => o['tag'] == 'hy2-fast');
    expect(hy2['type'], 'hysteria2');
    expect(hy2['bind_interface'], 'Wi-Fi 2');

    final intranet = parseResult.outbounds.firstWhere(
      (o) => o['tag'] == '内网直连',
    );
    expect(intranet['type'], 'direct');
    expect(intranet['bind_interface'], 'Wi-Fi');

    // Generate config with TUN enabled
    final config = ConfigGenerator.generate(
      settings: const AppSettings(tunModeEnabled: true),
      parsedOutbounds: parseResult.outbounds,
      customRules: parseResult.customRules,
      customDns: parseResult.customDns,
    );

    // Verify TUN strict_route and address is modern array
    final inbounds = config['inbounds'] as List;
    final tunInbound = inbounds.firstWhere((i) => i['type'] == 'tun');
    expect(tunInbound['strict_route'], isTrue);
    expect(tunInbound['address'], contains('172.19.0.1/30'));
    expect(tunInbound.containsKey('inet4_address'), isFalse);
    expect(tunInbound.containsKey('sniff'), isFalse);

    final routeRules = config['route']['rules'] as List;

    // Verify auto-bypass exception route for proxy server IP in TUN route_exclude_address
    expect(tunInbound['route_exclude_address'], contains('158.180.92.85/32'));
    final proxyBypassInRouteRules = routeRules.where(
      (r) =>
          r['ip_cidr'] != null &&
          (r['ip_cidr'] as List).contains('158.180.92.85/32'),
    );
    expect(
      proxyBypassInRouteRules,
      isEmpty,
      reason: 'Proxy server IP must be excluded at OS route level via route_exclude_address, not forced via route.rules',
    );

    final processRule = routeRules.firstWhere((r) => r['process_name'] != null);
    expect(processRule['process_name'], contains('uSmartView.exe'));
    expect(processRule['outbound'], '内网直连');

    final domainRule = routeRules.firstWhere(
      (r) =>
          r['domain_suffix'] != null &&
          (r['domain_suffix'] as List).contains('cpic.com.cn'),
    );
    expect(domainRule['outbound'], '内网直连');

    // Verify NO unconditional rule in routeRules
    final unconditionalRules = routeRules
        .where((r) => r['outbound'] != null && (r as Map).keys.length == 1)
        .toList();
    expect(
      unconditionalRules.length,
      1,
      reason: 'Only the single final catch-all at the bottom of route.rules is allowed',
    );

    final dns = config['dns'] as Map<String, dynamic>;
    final dnsServers = dns['servers'] as List;
    final companyDns = dnsServers.firstWhere(
      (s) => s['server'] == '202.96.209.133',
    );
    expect(companyDns['type'], 'udp');
    expect(companyDns['detour'], '内网直连');

    final localDns = dnsServers.firstWhere((s) => s['tag'] == 'local-dns');
    expect(localDns['type'], 'udp');
    // In TUN mode: no detour (avoids routing loops)
    // sing-box FATAL: "detour to an empty direct outbound makes no sense"
    // even with bind_interface nodes, TUN mode must NOT set detour on local-dns
    expect(
      localDns.containsKey('detour'),
      isFalse,
      reason: 'In TUN mode, local-dns must have no detour to avoid routing loops',
    );
    expect(
      config['route'].containsKey('default_interface'),
      isFalse,
      reason: 'In TUN mode, default_interface must not be set',
    );

    // Verify non-TUN + dual-NIC: local-dns gets detour:'direct' ONLY because direct has bind_interface
    final nonTunConfig = ConfigGenerator.generate(
      settings: const AppSettings(tunModeEnabled: false),
      parsedOutbounds: parseResult.outbounds,
      customRules: parseResult.customRules,
      customDns: parseResult.customDns,
    );
    final nonTunDnsServers = (nonTunConfig['dns'] as Map)['servers'] as List;
    final nonTunLocalDns =
        nonTunDnsServers.firstWhere((s) => s['tag'] == 'local-dns');
    // hy2-fast has interface-name: Wi-Fi 2, so direct outbound gets bind_interface → detour:'direct' is safe
    expect(
      nonTunLocalDns['detour'],
      'direct',
      reason: 'Non-TUN with bind_interface node: local-dns should detour via direct (which has bind_interface)',
    );
    expect(nonTunConfig['route']['default_interface'], 'Wi-Fi 2');

    // Verify auto urltest group only contains proxy nodes, not direct outbounds
    final outbounds = config['outbounds'] as List;
    final autoGroup = outbounds.firstWhere((o) => o['tag'] == 'auto');
    expect(
      autoGroup['outbounds'],
      equals(['hy2-fast']),
      reason: 'Auto group must strictly contain hy2-fast and exclude direct outbounds',
    );
  });

  testWidgets('Bottom status ribbon renders listening port and tags', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: BottomStatusRibbon()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Inbound mixed-in PORT tag is rendered in bottom ribbon
    expect(find.text('mixed-in: 7890'), findsOneWidget);
    // Verify default Rule mode tag is rendered in Chinese by default
    expect(find.text('规则分流'), findsOneWidget);
    // Verify Restart button is rendered in bottom ribbon
    expect(find.text('重启'), findsOneWidget);
  });

  test('ProxyFlagHelper and ProxySortMode logic test', () {
    // 1. Verify country flag parsing
    expect(ProxyFlagHelper.getFlag('🇭🇰 HK 香港 01'), '🇭🇰');
    expect(ProxyFlagHelper.getFlag('🇯🇵 Tokyo 日本 02'), '🇯🇵');
    expect(ProxyFlagHelper.getFlag('🇺🇸 US 美国 洛杉矶'), '🇺🇸');
    expect(ProxyFlagHelper.getFlag('🇸🇬 Singapore 新加坡 01'), '🇸🇬');
    expect(ProxyFlagHelper.getFlag('Auto 自动优选'), '⚡');
    expect(ProxyFlagHelper.getFlag('Unknown Node'), '🌐');

    // 2. Verify sorting and filtering
    final nodeA = ProxyNode(name: 'Beta', type: OutboundType.vless, delay: 150);
    final nodeB = ProxyNode(
      name: 'Alpha',
      type: OutboundType.hysteria2,
      delay: 35,
    );
    final nodeC = ProxyNode(
      name: 'Gamma',
      type: OutboundType.shadowsocks,
      delay: -1,
    );

    final state = ProxiesState(
      nodes: {'Beta': nodeA, 'Alpha': nodeB, 'Gamma': nodeC},
      sortMode: ProxySortMode.delayAsc,
      hideUnavailable: true,
    );

    final sorted = state.filteredNodes;
    expect(sorted.length, 2); // Gamma (-1) filtered out
    expect(sorted.first.name, 'Alpha'); // 35ms before 150ms
    expect(sorted.last.name, 'Beta');
  });

  test('DefaultConfigTemplate creates valid sing-box configuration', () {
    final map = DefaultConfigTemplate.getStandardConfigMap();
    expect(map['outbounds'], isNotEmpty);
    expect(map['inbounds'], isNotEmpty);
    expect(map['route'], isNotNull);

    final jsonStr = DefaultConfigTemplate.getStandardConfigJson();
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    expect(decoded['log']['level'], 'info');

    final parseResult = ProfileParser.parse(jsonStr);
    expect(parseResult.count, greaterThanOrEqualTo(2));
    expect(parseResult.format, 'sing-box');
  });

  test('Local config.json file import, sync-save, and disk reload test', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
    );
    final notifier = container.read(profilesProvider.notifier);

    // 1. Create a temporary local config.json file
    final tempDir = await Directory.systemTemp.createTemp('singular_test_');
    final configFile = File('${tempDir.path}/config.json');
    await configFile.writeAsString(DefaultConfigTemplate.getStandardConfigJson());

    // 2. Import from local file
    final success = await notifier.addProfileFromLocalFile(
      name: 'My Local Test Profile',
      filePath: configFile.path,
    );
    expect(success, isTrue);

    var state = container.read(profilesProvider);
    expect(state.profiles.length, 1);
    final profile = state.profiles.first;
    expect(profile.name, 'My Local Test Profile');
    expect(profile.type, ProfileType.local);
    expect(profile.filePath, configFile.path);
    expect(profile.nodeCount, greaterThanOrEqualTo(2));

    // 3. Update profile content with syncToFile: true
    final modifiedJson = DefaultConfigTemplate.getStandardConfigJson().replaceAll('Node-Sample', 'Node-Updated-01');
    final updateSuccess = await notifier.updateProfileContent(
      profile.id,
      modifiedJson,
      syncToFile: true,
    );
    expect(updateSuccess, isTrue);

    // Verify disk file was updated
    final diskContentAfterSave = await configFile.readAsString();
    expect(diskContentAfterSave, contains('Node-Updated-01'));

    // 4. Modify file on disk externally and call refreshProfile
    final externalModified = diskContentAfterSave.replaceAll('Node-Updated-01', 'Node-Disk-External-99');
    await configFile.writeAsString(externalModified);

    final refreshSuccess = await notifier.refreshProfile(profile.id);
    expect(refreshSuccess, isTrue);

    state = container.read(profilesProvider);
    expect(state.profiles.first.rawConfig, contains('Node-Disk-External-99'));

    // Cleanup
    await tempDir.delete(recursive: true);
  });

  testWidgets('ConfigEditorDialog renders, formats JSON, and tracks syntax validation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    final profile = Profile(
      id: 'test-p1',
      name: 'Editor Test Profile',
      type: ProfileType.local,
      filePath: '/dummy/config.json',
      updatedAt: DateTime.now(),
      rawConfig: '{"log":{"level":"debug"},"outbounds":[{"type":"direct","tag":"direct"}]}',
      nodeCount: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConfigEditorDialog(profile: profile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dialog header elements
    expect(find.text('Editor Test Profile'), findsOneWidget);
    expect(find.text('sing-box JSON'), findsOneWidget);
    expect(find.text('语法正确'), findsOneWidget);

    // Verify mode switcher is present
    expect(find.text('可视化编辑'), findsOneWidget);
    expect(find.text('JSON 源码'), findsOneWidget);

    // Switch to JSON Code mode
    await tester.tap(find.text('JSON 源码'));
    await tester.pumpAndSettle();

    // Verify format button is present
    expect(find.byIcon(Icons.format_indent_increase_rounded), findsOneWidget);

    // Tap format button
    await tester.tap(find.byIcon(Icons.format_indent_increase_rounded));
    await tester.pumpAndSettle();

    // Verify JSON was indented (contains newlines)
    expect(find.textContaining('  "log":'), findsOneWidget);

    // Open Search Bar
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2)); // Editor + Search input

    // Verify the editor TextField uses explicit dark background Color(0xFF080C16)
    final editorField = tester.widget<TextField>(find.byType(TextField).first);
    expect(editorField.decoration?.filled, isTrue);
    expect(editorField.decoration?.fillColor, const Color(0xFF080C16));
  });

  testWidgets('JsonCodeSyntaxController produces syntax highlighted spans', (tester) async {
    final controller = JsonCodeSyntaxController(
      text: '{\n  "port": 7890,\n  "tag": "direct",\n  "enabled": true\n}',
    );

    late BuildContext testContext;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          testContext = context;
          return const SizedBox();
        },
      ),
    );

    final span = controller.buildTextSpan(
      context: testContext,
      withComposing: false,
    );

    expect(span.children, isNotNull);
    final textSpans = span.children!.whereType<TextSpan>().toList();

    // Verify key "port" has cyan color
    final portKey = textSpans.firstWhere((s) => s.text == '"port"');
    expect(portKey.style?.color, const Color(0xFF38BDF8));

    // Verify number 7890 has amber color
    final portNum = textSpans.firstWhere((s) => s.text == '7890');
    expect(portNum.style?.color, const Color(0xFFFBBF24));

    // Verify string "direct" has emerald color
    final directVal = textSpans.firstWhere((s) => s.text == '"direct"');
    expect(directVal.style?.color, const Color(0xFF34D399));

    // Verify boolean true has violet color
    final trueVal = textSpans.firstWhere((s) => s.text == 'true');
    expect(trueVal.style?.color, const Color(0xFFC084FC));
  });

  testWidgets('VisualConfigEditor renders outbounds, inbounds, route, and dns tabs', (tester) async {
    final sampleConfig = {
      'log': {'level': 'info', 'timestamp': true},
      'inbounds': [
        {'type': 'mixed', 'tag': 'mixed-in', 'listen': '127.0.0.1', 'listen_port': 2080}
      ],
      'outbounds': [
        {'type': 'vless', 'tag': 'Hong Kong 01', 'server': 'hk.example.com', 'server_port': 443},
        {'type': 'selector', 'tag': 'Proxy', 'outbounds': ['Hong Kong 01', 'direct']},
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {'type': 'dns', 'tag': 'dns-out'}
      ],
      'route': {
        'final': 'Proxy',
        'auto_detect_interface': true,
        'rules': [
          {'action': 'route', 'protocol': 'dns', 'outbound': 'dns-out'},
          {'action': 'route', 'ip_is_private': true, 'outbound': 'direct'}
        ]
      },
      'dns': {
        'servers': [
          {'tag': 'remote-dns', 'address': 'tls://1.1.1.1', 'detour': 'Proxy'},
          {'tag': 'local-dns', 'address': '223.5.5.5', 'detour': 'direct'}
        ],
        'rules': [
          {'domain_suffix': 'google.com', 'server': 'remote-dns'}
        ]
      }
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualConfigEditor(
            config: sampleConfig,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Outbounds Tab by default
    expect(find.text('出站 (Outbounds)'), findsOneWidget);
    expect(find.text('Hong Kong 01'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('添加出站'), findsOneWidget);

    // Switch to Inbounds Tab
    await tester.tap(find.text('入站 (Inbounds)'));
    await tester.pumpAndSettle();
    expect(find.text('mixed-in'), findsOneWidget);
    expect(find.text('添加入站'), findsOneWidget);

    // Switch to Route Tab
    await tester.tap(find.text('路由分流 (Route)'));
    await tester.pumpAndSettle();
    expect(find.text('默认出站 (Final):'), findsOneWidget);
    expect(find.text('添加路由规则'), findsOneWidget);

    // Switch to DNS Tab
    await tester.tap(find.text('DNS 配置 (DNS)'));
    await tester.pumpAndSettle();
    expect(find.text('remote-dns'), findsOneWidget);
    expect(find.text('local-dns'), findsOneWidget);

    // Switch to General Tab
    await tester.tap(find.text('日志与通用 (General)'));
    await tester.pumpAndSettle();
    expect(find.text('日志输出设置 (Log):'), findsOneWidget);
  });
}

