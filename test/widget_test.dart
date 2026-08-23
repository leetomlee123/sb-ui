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
''';

    final result = ProfileParser.parse(rawClash);
    expect(result.count, 2);
    expect(result.outbounds.length, 2);
    expect(result.outbounds[0]['tag'], 'HK-Node-01');
    expect(result.outbounds[1]['tag'], 'US-Node-02');

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
  });
}
