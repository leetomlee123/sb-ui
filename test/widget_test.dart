import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/core/engine/profile_parser.dart';
import 'package:sb_ui/core/engine/config_generator.dart';
import 'package:sb_ui/core/models/app_settings.dart';
import 'package:sb_ui/core/models/proxy_node.dart';
import 'package:sb_ui/core/providers/proxies_provider.dart';
import 'package:sb_ui/core/providers/storage_provider.dart';
import 'package:sb_ui/core/services/storage_service.dart';
import 'package:sb_ui/core/utils/proxy_flag_helper.dart';
import 'package:sb_ui/features/shell/main_shell_view.dart';
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
    expect(generated['experimental']['clash_api']['external_controller'], '127.0.0.1:9090');

    final outboundsList = generated['outbounds'] as List;
    final allTags = outboundsList.map((o) => o['tag'].toString()).toSet();

    // Verify auto group sanitized non-existent-node
    final autoGroup = outboundsList.firstWhere((o) => o['tag'] == 'auto');
    expect(autoGroup['outbounds'], contains('vless-cdn'));
    expect(autoGroup['outbounds'], isNot(contains('non-existent-node')));

    // Verify Proxy group dependencies ALL exist in allTags
    final proxyGroup = outboundsList.firstWhere((o) => o['tag'] == 'Proxy');
    for (final dest in proxyGroup['outbounds'] as List) {
      expect(allTags.contains(dest) || ['direct', 'block'].contains(dest), isTrue,
          reason: 'Dependency $dest must exist in outbounds');
    }

    // Verify preferred selectedProxyNode is set as default in Proxy group
    const customNodeSettings = AppSettings(
      selectedProxyNode: 'HK-Node-01',
    );
    final customGenerated = ConfigGenerator.generate(
      settings: customNodeSettings,
      parsedOutbounds: result.outbounds,
    );
    final customProxyGroup = (customGenerated['outbounds'] as List).firstWhere((o) => o['tag'] == 'Proxy');
    expect(customProxyGroup['default'], 'HK-Node-01');
  });

  test('AppSettings serialization and defaults', () {
    const defaultSettings = AppSettings();
    expect(defaultSettings.closeToTray, isTrue);
    expect(defaultSettings.hasAskedCloseToTray, isFalse);
    expect(defaultSettings.mixedPort, 7890);
    expect(defaultSettings.clashApiPort, 9090);

    final json = defaultSettings.toJson();
    final restored = AppSettings.fromJson(json);
    expect(restored.closeToTray, isTrue);
    expect(restored.hasAskedCloseToTray, isFalse);

    final updated = defaultSettings.copyWith(
      hasAskedCloseToTray: true,
      closeToTray: false,
    );
    expect(updated.hasAskedCloseToTray, isTrue);
    expect(updated.closeToTray, isFalse);
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
      'obfs': {
        'type': 'salamander',
        'password': 'obfspassword',
      },
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
    const testContent = 'proxies:\n  - name: test-ss\n    type: ss\n    server: 1.1.1.1\n    port: 8388\n    cipher: aes-128-gcm\n    password: pwd';
    
    final result1 = ProfileParser.parse(testContent);
    final result2 = ProfileParser.parse(testContent);
    expect(identical(result1, result2), isTrue, reason: 'Repeated parse should return identical cached instance');

    ProfileParser.clearCache();
    final result3 = ProfileParser.parse(testContent);
    expect(identical(result1, result3), isFalse, reason: 'clearCache should flush the cached instance');
    expect(result3.count, result1.count);
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
    expect(parseResult.customRules.length, 4); // 4 conditional rules (MATCH is skipped as fallback)
    expect(parseResult.customDns, isNotNull);

    // Verify outbounds
    final hy2 = parseResult.outbounds.firstWhere((o) => o['tag'] == 'hy2-fast');
    expect(hy2['type'], 'hysteria2');
    expect(hy2['bind_interface'], 'Wi-Fi 2');

    final intranet = parseResult.outbounds.firstWhere((o) => o['tag'] == '内网直连');
    expect(intranet['type'], 'direct');
    expect(intranet['bind_interface'], 'Wi-Fi');

    // Generate config with TUN enabled
    final config = ConfigGenerator.generate(
      settings: const AppSettings(tunModeEnabled: true),
      parsedOutbounds: parseResult.outbounds,
      customRules: parseResult.customRules,
      customDns: parseResult.customDns,
    );

    // Verify TUN strict_route is false
    final inbounds = config['inbounds'] as List;
    final tunInbound = inbounds.firstWhere((i) => i['type'] == 'tun');
    expect(tunInbound['strict_route'], isFalse);

    final routeRules = config['route']['rules'] as List;

    // Verify auto-bypass rule for proxy server IP
    final proxyBypassRule = routeRules.firstWhere((r) => r['ip_cidr'] != null && (r['ip_cidr'] as List).contains('158.180.92.85/32'));
    expect(proxyBypassRule['outbound'], '热点直连');

    final processRule = routeRules.firstWhere((r) => r['process_name'] != null);
    expect(processRule['process_name'], contains('uSmartView.exe'));
    expect(processRule['outbound'], '内网直连');

    final domainRule = routeRules.firstWhere((r) => r['domain_suffix'] != null && (r['domain_suffix'] as List).contains('cpic.com.cn'));
    expect(domainRule['outbound'], '内网直连');

    // Verify NO unconditional rule in routeRules
    final unconditionalRules = routeRules.where((r) => r['outbound'] != null && (r as Map).keys.length == 1).toList();
    expect(unconditionalRules.length, 1, reason: 'Only the single final catch-all at the bottom of route.rules is allowed');

    final dns = config['dns'] as Map<String, dynamic>;
    final dnsServers = dns['servers'] as List;
    final companyDns = dnsServers.firstWhere((s) => s['address'] == '202.96.209.133');
    expect(companyDns['detour'], '内网直连');

    // Verify auto urltest group only contains proxy nodes, not direct outbounds
    final outbounds = config['outbounds'] as List;
    final autoGroup = outbounds.firstWhere((o) => o['tag'] == 'auto');
    expect(autoGroup['outbounds'], equals(['hy2-fast']), reason: 'Auto group must strictly contain hy2-fast and exclude direct outbounds');
  });

  testWidgets('Bottom status ribbon renders listening port and tags', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomStatusRibbon(),
          ),
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
    final nodeB = ProxyNode(name: 'Alpha', type: OutboundType.hysteria2, delay: 35);
    final nodeC = ProxyNode(name: 'Gamma', type: OutboundType.shadowsocks, delay: -1);

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
}
