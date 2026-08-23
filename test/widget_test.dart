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

    // Verify auto group sanitized non-existent-node
    final autoGroup = (generated['outbounds'] as List).firstWhere((o) => o['tag'] == 'auto');
    expect(autoGroup['outbounds'], contains('vless-cdn'));
    expect(autoGroup['outbounds'], isNot(contains('non-existent-node')));
  });
}
