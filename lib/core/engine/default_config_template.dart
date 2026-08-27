import 'dart:convert';
import 'dart:io';
import '../services/storage_service.dart';

class DefaultConfigTemplate {
  /// Returns a clean, standard, and working sing-box `config.json` structure
  static Map<String, dynamic> getStandardConfigMap() {
    return {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': {
        'servers': [
          {
            'tag': 'remote-dns',
            'address': 'tls://1.1.1.1',
            'detour': 'Proxy',
          },
          {
            'tag': 'local-dns',
            'address': '223.5.5.5',
            'detour': 'direct',
          },
        ],
        'rules': [
          {
            'outbound': 'any',
            'server': 'local-dns',
          },
          {
            'clash_mode': 'Global',
            'server': 'remote-dns',
          },
          {
            'clash_mode': 'Direct',
            'server': 'local-dns',
          },
          {
            'rule_set': ['geosite-cn'],
            'server': 'local-dns',
          },
        ],
        'strategy': 'prefer_ipv4',
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': 2080,
        },
      ],
      'outbounds': [
        {
          'type': 'selector',
          'tag': 'Proxy',
          'outbounds': ['Node-Sample', 'direct'],
          'default': 'Node-Sample',
        },
        {
          'type': 'vless',
          'tag': 'Node-Sample',
          'server': 'example.com',
          'server_port': 443,
          'uuid': '00000000-0000-0000-0000-000000000000',
          'flow': 'xtls-rprx-vision',
          'tls': {
            'enabled': true,
            'server_name': 'example.com',
            'reality': {
              'enabled': true,
              'public_key': 'YourPublicKeyHere',
              'short_id': '0123456789abcdef',
            },
          },
        },
        {
          'type': 'direct',
          'tag': 'direct',
        },
        {
          'type': 'block',
          'tag': 'block',
        },
        {
          'type': 'dns',
          'tag': 'dns-out',
        },
      ],
      'route': {
        'rules': [
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
          },
        ],
        'auto_detect_interface': true,
      },
    };
  }

  /// Returns a formatted JSON string of the standard template
  static String getStandardConfigJson() {
    return const JsonEncoder.withIndent('  ').convert(getStandardConfigMap());
  }

  /// Creates a local `config.json` in the user's config directory
  static Future<File> createLocalConfigFile({String fileName = 'config.json'}) async {
    final dir = await StorageService.getAppConfigDir();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      await file.writeAsString(getStandardConfigJson());
    }
    return file;
  }
}
