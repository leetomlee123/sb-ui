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
}
