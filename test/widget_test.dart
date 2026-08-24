import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/core/engine/profile_parser.dart';
import 'package:sb_ui/core/engine/config_generator.dart';
import 'package:sb_ui/core/models/app_settings.dart';

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
      mixedPort: 2080,
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
    expect(defaultSettings.mixedPort, 2080);
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
    expect(parseResult.customRules.length, 5);
    expect(parseResult.customDns, isNotNull);

    // Verify outbounds
    final hy2 = parseResult.outbounds.firstWhere((o) => o['tag'] == 'hy2-fast');
    expect(hy2['type'], 'hysteria2');
    expect(hy2['bind_interface'], 'Wi-Fi 2');

    final intranet = parseResult.outbounds.firstWhere((o) => o['tag'] == '内网直连');
    expect(intranet['type'], 'direct');
    expect(intranet['bind_interface'], 'Wi-Fi');

    // Generate config
    final config = ConfigGenerator.generate(
      settings: const AppSettings(),
      parsedOutbounds: parseResult.outbounds,
      customRules: parseResult.customRules,
      customDns: parseResult.customDns,
    );

    final routeRules = config['route']['rules'] as List;
    final processRule = routeRules.firstWhere((r) => r['process_name'] != null);
    expect(processRule['process_name'], contains('uSmartView.exe'));
    expect(processRule['outbound'], '内网直连');

    final domainRule = routeRules.firstWhere((r) => r['domain_suffix'] != null && (r['domain_suffix'] as List).contains('cpic.com.cn'));
    expect(domainRule['outbound'], '内网直连');

    final dns = config['dns'] as Map<String, dynamic>;
    final dnsServers = dns['servers'] as List;
    expect(dnsServers.any((s) => s['address'] == '202.96.209.133'), isTrue);
  });
}
