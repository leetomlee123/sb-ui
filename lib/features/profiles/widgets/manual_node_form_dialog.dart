import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/translations.dart';
import '../../../core/providers/profiles_provider.dart';

enum ProtocolOption {
  shadowsocks('Shadowsocks (SS)', 'shadowsocks', Icons.security_rounded),
  vmess('VMess', 'vmess', Icons.cloud_queue_rounded),
  vless('VLESS (Reality/TLS)', 'vless', Icons.flash_on_rounded),
  trojan('Trojan', 'trojan', Icons.shield_rounded),
  hysteria2('Hysteria 2 (Hy2)', 'hysteria2', Icons.rocket_launch_rounded),
  tuic('TUIC', 'tuic', Icons.speed_rounded),
  socks5('SOCKS5', 'socks', Icons.sync_alt_rounded),
  http('HTTP Proxy', 'http', Icons.http_rounded);

  final String label;
  final String typeKey;
  final IconData icon;
  const ProtocolOption(this.label, this.typeKey, this.icon);
}

class ManualNodeFormDialog extends ConsumerStatefulWidget {
  const ManualNodeFormDialog({super.key});

  @override
  ConsumerState<ManualNodeFormDialog> createState() => _ManualNodeFormDialogState();
}

class _ManualNodeFormDialogState extends ConsumerState<ManualNodeFormDialog> {
  ProtocolOption _protocol = ProtocolOption.vless;

  // Common Controllers
  final _tagCtrl = TextEditingController(text: 'My Node');
  final _serverCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '443');

  // Auth / Key Controllers
  final _passwordCtrl = TextEditingController();
  final _uuidCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  // Shadowsocks specific
  String _ssMethod = '2022-blake3-aes-128-gcm';
  final _pluginCtrl = TextEditingController();
  final _pluginOptsCtrl = TextEditingController();

  // VMess specific
  String _vmessSecurity = 'auto';
  final _alterIdCtrl = TextEditingController(text: '0');

  // VLESS specific
  String _vlessFlow = 'xtls-rprx-vision';
  String _vlessTlsType = 'reality'; // 'none', 'tls', 'reality'
  final _realityPbkCtrl = TextEditingController();
  final _realitySidCtrl = TextEditingController();
  String _fingerprint = 'chrome';

  // Common Transport & TLS
  String _transportType = 'tcp'; // 'tcp', 'ws', 'grpc', 'httpupgrade'
  final _pathCtrl = TextEditingController(text: '/');
  final _hostCtrl = TextEditingController();
  final _serviceNameCtrl = TextEditingController();

  bool _enableTls = true;
  final _sniCtrl = TextEditingController();
  bool _allowInsecure = false;

  // Hysteria 2 specific
  final _obfsPasswordCtrl = TextEditingController();
  final _upMbpsCtrl = TextEditingController(text: '100');
  final _downMbpsCtrl = TextEditingController(text: '500');

  // TUIC specific
  String _congestionControl = 'bbr'; // 'bbr', 'cubic', 'new_reno'
  String _udpRelayMode = 'native'; // 'native', 'quic'
  bool _zeroRtt = false;

  // Interface / Wi-Fi Binding
  final _bindInterfaceCtrl = TextEditingController();

  @override
  void dispose() {
    _tagCtrl.dispose();
    _serverCtrl.dispose();
    _portCtrl.dispose();
    _passwordCtrl.dispose();
    _uuidCtrl.dispose();
    _usernameCtrl.dispose();
    _pluginCtrl.dispose();
    _pluginOptsCtrl.dispose();
    _alterIdCtrl.dispose();
    _realityPbkCtrl.dispose();
    _realitySidCtrl.dispose();
    _pathCtrl.dispose();
    _hostCtrl.dispose();
    _serviceNameCtrl.dispose();
    _sniCtrl.dispose();
    _obfsPasswordCtrl.dispose();
    _upMbpsCtrl.dispose();
    _downMbpsCtrl.dispose();
    _bindInterfaceCtrl.dispose();
    super.dispose();
  }

  void _onProtocolChanged(ProtocolOption newProto) {
    setState(() {
      _protocol = newProto;
      switch (newProto) {
        case ProtocolOption.shadowsocks:
          _portCtrl.text = '8388';
          _ssMethod = '2022-blake3-aes-128-gcm';
          break;
        case ProtocolOption.vmess:
          _portCtrl.text = '443';
          _transportType = 'ws';
          _enableTls = true;
          break;
        case ProtocolOption.vless:
          _portCtrl.text = '443';
          _transportType = 'tcp';
          _vlessTlsType = 'reality';
          _vlessFlow = 'xtls-rprx-vision';
          break;
        case ProtocolOption.trojan:
          _portCtrl.text = '443';
          _transportType = 'tcp';
          _enableTls = true;
          break;
        case ProtocolOption.hysteria2:
          _portCtrl.text = '443';
          _enableTls = true;
          break;
        case ProtocolOption.tuic:
          _portCtrl.text = '443';
          _enableTls = true;
          break;
        case ProtocolOption.socks5:
          _portCtrl.text = '1080';
          break;
        case ProtocolOption.http:
          _portCtrl.text = '8080';
          break;
      }
    });
  }

  Map<String, dynamic> _generateOutbound() {
    final tag = _tagCtrl.text.trim().isEmpty ? 'Custom Node' : _tagCtrl.text.trim();
    final server = _serverCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 443;
    final Map<String, dynamic> map;

    switch (_protocol) {
      case ProtocolOption.shadowsocks:
        map = <String, dynamic>{
          'type': 'shadowsocks',
          'tag': tag,
          'server': server,
          'server_port': port,
          'method': _ssMethod,
          'password': _passwordCtrl.text.trim(),
        };
        if (_pluginCtrl.text.trim().isNotEmpty) {
          map['plugin'] = _pluginCtrl.text.trim();
        }
        if (_pluginOptsCtrl.text.trim().isNotEmpty) {
          map['plugin_opts'] = _pluginOptsCtrl.text.trim();
        }
        break;

      case ProtocolOption.vmess:
        map = <String, dynamic>{
          'type': 'vmess',
          'tag': tag,
          'server': server,
          'server_port': port,
          'uuid': _uuidCtrl.text.trim(),
          'alter_id': int.tryParse(_alterIdCtrl.text.trim()) ?? 0,
          'security': _vmessSecurity,
        };
        if (_transportType != 'tcp') {
          final transport = <String, dynamic>{'type': _transportType};
          if (_transportType == 'ws' || _transportType == 'httpupgrade') {
            if (_pathCtrl.text.trim().isNotEmpty) transport['path'] = _pathCtrl.text.trim();
            if (_hostCtrl.text.trim().isNotEmpty) {
              transport['headers'] = {'Host': _hostCtrl.text.trim()};
            }
          } else if (_transportType == 'grpc') {
            if (_serviceNameCtrl.text.trim().isNotEmpty) {
              transport['service_name'] = _serviceNameCtrl.text.trim();
            }
          }
          map['transport'] = transport;
        }
        if (_enableTls) {
          final tls = <String, dynamic>{'enabled': true};
          if (_sniCtrl.text.trim().isNotEmpty) tls['server_name'] = _sniCtrl.text.trim();
          if (_allowInsecure) tls['insecure'] = true;
          map['tls'] = tls;
        }
        break;

      case ProtocolOption.vless:
        map = <String, dynamic>{
          'type': 'vless',
          'tag': tag,
          'server': server,
          'server_port': port,
          'uuid': _uuidCtrl.text.trim(),
        };
        if (_vlessFlow.isNotEmpty && _vlessFlow != 'none') {
          map['flow'] = _vlessFlow;
        }
        if (_transportType != 'tcp') {
          final transport = <String, dynamic>{'type': _transportType};
          if (_transportType == 'ws' || _transportType == 'httpupgrade') {
            if (_pathCtrl.text.trim().isNotEmpty) transport['path'] = _pathCtrl.text.trim();
            if (_hostCtrl.text.trim().isNotEmpty) {
              transport['headers'] = {'Host': _hostCtrl.text.trim()};
            }
          } else if (_transportType == 'grpc') {
            if (_serviceNameCtrl.text.trim().isNotEmpty) {
              transport['service_name'] = _serviceNameCtrl.text.trim();
            }
          }
          map['transport'] = transport;
        }
        if (_vlessTlsType == 'tls') {
          final tls = <String, dynamic>{
            'enabled': true,
            'utls': {
              'enabled': true,
              'fingerprint': _fingerprint,
            },
          };
          if (_sniCtrl.text.trim().isNotEmpty) tls['server_name'] = _sniCtrl.text.trim();
          if (_allowInsecure) tls['insecure'] = true;
          map['tls'] = tls;
        } else if (_vlessTlsType == 'reality') {
          final tls = <String, dynamic>{
            'enabled': true,
            'server_name': _sniCtrl.text.trim(),
            'utls': {
              'enabled': true,
              'fingerprint': _fingerprint,
            },
            'reality': {
              'enabled': true,
              'public_key': _realityPbkCtrl.text.trim(),
              'short_id': _realitySidCtrl.text.trim(),
            },
          };
          map['tls'] = tls;
        }
        break;

      case ProtocolOption.trojan:
        map = <String, dynamic>{
          'type': 'trojan',
          'tag': tag,
          'server': server,
          'server_port': port,
          'password': _passwordCtrl.text.trim(),
          'tls': {
            'enabled': true,
            if (_sniCtrl.text.trim().isNotEmpty) 'server_name': _sniCtrl.text.trim(),
            if (_allowInsecure) 'insecure': true,
            'alpn': ['h2', 'http/1.1'],
          },
        };
        if (_transportType != 'tcp') {
          final transport = <String, dynamic>{'type': _transportType};
          if (_transportType == 'ws') {
            if (_pathCtrl.text.trim().isNotEmpty) transport['path'] = _pathCtrl.text.trim();
            if (_hostCtrl.text.trim().isNotEmpty) {
              transport['headers'] = {'Host': _hostCtrl.text.trim()};
            }
          } else if (_transportType == 'grpc') {
            if (_serviceNameCtrl.text.trim().isNotEmpty) {
              transport['service_name'] = _serviceNameCtrl.text.trim();
            }
          }
          map['transport'] = transport;
        }
        break;

      case ProtocolOption.hysteria2:
        map = <String, dynamic>{
          'type': 'hysteria2',
          'tag': tag,
          'server': server,
          'server_port': port,
          'password': _passwordCtrl.text.trim(),
          'tls': {
            'enabled': true,
            if (_sniCtrl.text.trim().isNotEmpty) 'server_name': _sniCtrl.text.trim(),
            if (_allowInsecure) 'insecure': true,
          },
        };
        if (_obfsPasswordCtrl.text.trim().isNotEmpty) {
          map['obfs'] = {
            'type': 'salamander',
            'password': _obfsPasswordCtrl.text.trim(),
          };
        }
        final up = int.tryParse(_upMbpsCtrl.text.trim());
        final down = int.tryParse(_downMbpsCtrl.text.trim());
        if (up != null && up > 0) map['up_mbps'] = up;
        if (down != null && down > 0) map['down_mbps'] = down;
        break;

      case ProtocolOption.tuic:
        map = <String, dynamic>{
          'type': 'tuic',
          'tag': tag,
          'server': server,
          'server_port': port,
          'uuid': _uuidCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
          'congestion_control': _congestionControl,
          'udp_relay_mode': _udpRelayMode,
          'zero_rtt_handshake': _zeroRtt,
          'tls': {
            'enabled': true,
            if (_sniCtrl.text.trim().isNotEmpty) 'server_name': _sniCtrl.text.trim(),
            if (_allowInsecure) 'insecure': true,
            'alpn': ['h3'],
          },
        };
        break;

      case ProtocolOption.socks5:
      case ProtocolOption.http:
        map = <String, dynamic>{
          'type': _protocol.typeKey,
          'tag': tag,
          'server': server,
          'server_port': port,
        };
        if (_usernameCtrl.text.trim().isNotEmpty) {
          map['username'] = _usernameCtrl.text.trim();
        }
        if (_passwordCtrl.text.trim().isNotEmpty) {
          map['password'] = _passwordCtrl.text.trim();
        }
        break;
    }

    final iface = _bindInterfaceCtrl.text.trim();
    if (iface.isNotEmpty) {
      map['bind_interface'] = iface;
    }
    return map;
  }

  Future<void> _submit() async {
    final tr = ref.read(translationsProvider);
    final server = _serverCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim());
    final tag = _tagCtrl.text.trim();

    if (server.isEmpty || port == null || port <= 0 || port > 65535 || tag.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.fillRequiredFields)),
      );
      return;
    }

    final outbound = _generateOutbound();
    final jsonConfig = const JsonEncoder.withIndent('  ').convert({
      'outbounds': [outbound],
    });

    Navigator.pop(context);

    await ref.read(profilesProvider.notifier).addProfileFromRawText(
      name: tag,
      rawContent: jsonConfig,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.isZh ? '节点配置已成功创建' : 'Node profile created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(_protocol.icon, color: const Color(0xFF818CF8), size: 22),
          const SizedBox(width: 10),
          Text(
            tr.tabManualForm,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Protocol Selector
              Text(
                tr.protocolType,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProtocolOption>(
                    value: _protocol,
                    isExpanded: true,
                    items: ProtocolOption.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(p.icon, size: 18, color: const Color(0xFF38BDF8)),
                            const SizedBox(width: 10),
                            Text(p.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onProtocolChanged(val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Base Info: Node Name, Host, Port
              Text(
                tr.isZh ? '基本连接参数' : 'BASIC ENDPOINTS',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagCtrl,
                decoration: InputDecoration(
                  labelText: tr.nodeName,
                  hintText: tr.isZh ? '例如：香港 01 | 专属节点' : 'e.g. HK-Premium-01',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: TextField(
                      controller: _serverCtrl,
                      decoration: InputDecoration(
                        labelText: tr.serverHost,
                        hintText: 'example.com / 1.2.3.4',
                        prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: tr.serverPort,
                        hintText: '443',
                        prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. Protocol-Specific Section
              ..._buildProtocolFields(context, tr),

              const SizedBox(height: 18),

              // 4. Transport & TLS (for VMess, VLESS, Trojan)
              if ([ProtocolOption.vmess, ProtocolOption.vless, ProtocolOption.trojan].contains(_protocol)) ...[
                _buildTransportAndTlsSection(context, tr),
                const SizedBox(height: 18),
              ],

              // 5. Interface & Wi-Fi Binding
              Text(
                tr.isZh ? '出口网卡与 Wi-Fi 绑定 (可选)' : 'INTERFACE & WI-FI BINDING (OPTIONAL)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bindInterfaceCtrl,
                decoration: InputDecoration(
                  labelText: tr.isZh ? '绑定物理网卡 / Wi-Fi 名称 (bind_interface)' : 'Bind Network Interface (e.g. Wi-Fi 2)',
                  hintText: tr.isZh ? '例如：Wi-Fi、Wi-Fi 2、WLAN 或以太网 (留空默认跟随系统)' : 'e.g. Wi-Fi, Wi-Fi 2, eth0, wlan0',
                  helperText: tr.isZh ? '指定此节点流量仅通过特定的 Wi-Fi 或物理网卡出口发送' : 'Direct this node traffic through a specific physical NIC / Wi-Fi',
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(tr.createNodeProfile),
        ),
      ],
    );
  }

  List<Widget> _buildProtocolFields(BuildContext context, Translations tr) {
    switch (_protocol) {
      case ProtocolOption.shadowsocks:
        return [
          Text(
            tr.isZh ? 'Shadowsocks 认证与加密' : 'SHADOWSOCKS CREDENTIALS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _ssMethod,
            decoration: InputDecoration(labelText: tr.cipherLabel),
            items: const [
              DropdownMenuItem(value: '2022-blake3-aes-128-gcm', child: Text('2022-blake3-aes-128-gcm (AEAD-2022)')),
              DropdownMenuItem(value: '2022-blake3-aes-256-gcm', child: Text('2022-blake3-aes-256-gcm (AEAD-2022)')),
              DropdownMenuItem(value: '2022-blake3-chacha20-poly1305', child: Text('2022-blake3-chacha20-poly1305')),
              DropdownMenuItem(value: 'aes-256-gcm', child: Text('aes-256-gcm')),
              DropdownMenuItem(value: 'aes-128-gcm', child: Text('aes-128-gcm')),
              DropdownMenuItem(value: 'chacha20-ietf-poly1305', child: Text('chacha20-ietf-poly1305')),
              DropdownMenuItem(value: 'none', child: Text('none')),
            ],
            onChanged: (v) => setState(() => _ssMethod = v ?? 'aes-256-gcm'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr.passwordLabel,
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pluginCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plugin (可选)',
                    hintText: 'obfs-local / v2ray-plugin',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pluginOptsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Plugin Opts (可选)',
                    hintText: 'obfs=tls;obfs-host=...',
                  ),
                ),
              ),
            ],
          ),
        ];

      case ProtocolOption.vmess:
        return [
          Text(
            tr.isZh ? 'VMess 用户凭据' : 'VMESS CREDENTIALS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _uuidCtrl,
            decoration: InputDecoration(
              labelText: tr.uuidLabel,
              hintText: '00000000-0000-0000-0000-000000000000',
              prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: DropdownButtonFormField<String>(
                  initialValue: _vmessSecurity,
                  decoration: InputDecoration(labelText: tr.cipherLabel),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('auto (默认)')),
                    DropdownMenuItem(value: 'aes-128-gcm', child: Text('aes-128-gcm')),
                    DropdownMenuItem(value: 'chacha20-poly1305', child: Text('chacha20-poly1305')),
                    DropdownMenuItem(value: 'none', child: Text('none')),
                  ],
                  onChanged: (v) => setState(() => _vmessSecurity = v ?? 'auto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _alterIdCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'AlterId (通常填 0)',
                    hintText: '0',
                  ),
                ),
              ),
            ],
          ),
        ];

      case ProtocolOption.vless:
        return [
          Text(
            tr.isZh ? 'VLESS 认证与流控' : 'VLESS CREDENTIALS & FLOW',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _uuidCtrl,
            decoration: InputDecoration(
              labelText: tr.uuidLabel,
              hintText: '00000000-0000-0000-0000-000000000000',
              prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _vlessFlow,
            decoration: InputDecoration(labelText: tr.flowLabel),
            items: const [
              DropdownMenuItem(value: 'xtls-rprx-vision', child: Text('xtls-rprx-vision (Vision 流控)')),
              DropdownMenuItem(value: 'none', child: Text('none (无流控)')),
            ],
            onChanged: (v) => setState(() => _vlessFlow = v ?? 'none'),
          ),
          const SizedBox(height: 14),
          Text(
            tr.isZh ? 'TLS / Reality 安全伪装模式' : 'SECURITY & TLS TYPE',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'reality', label: Text('Reality 伪装')),
              ButtonSegment(value: 'tls', label: Text('标准 TLS')),
              ButtonSegment(value: 'none', label: Text('无加密 (none)')),
            ],
            selected: {_vlessTlsType},
            onSelectionChanged: (set) => setState(() => _vlessTlsType = set.first),
          ),
          if (_vlessTlsType == 'reality') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _sniCtrl,
              decoration: InputDecoration(
                labelText: tr.sniLabel,
                hintText: 'e.g. itunes.apple.com / www.microsoft.com',
                prefixIcon: const Icon(Icons.public_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _realityPbkCtrl,
              decoration: InputDecoration(
                labelText: tr.realityPublicKey,
                hintText: 'PublicKey (Base64)',
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _realitySidCtrl,
                    decoration: InputDecoration(
                      labelText: tr.realityShortId,
                      hintText: 'Short ID (HEX, e.g. 16, 6ba85179e30d4fc2)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _fingerprint,
                    decoration: const InputDecoration(labelText: 'uTLS Fingerprint'),
                    items: const [
                      DropdownMenuItem(value: 'chrome', child: Text('Chrome')),
                      DropdownMenuItem(value: 'firefox', child: Text('Firefox')),
                      DropdownMenuItem(value: 'safari', child: Text('Safari')),
                      DropdownMenuItem(value: 'ios', child: Text('iOS')),
                      DropdownMenuItem(value: 'randomized', child: Text('Randomized')),
                    ],
                    onChanged: (v) => setState(() => _fingerprint = v ?? 'chrome'),
                  ),
                ),
              ],
            ),
          ],
        ];

      case ProtocolOption.trojan:
        return [
          Text(
            tr.isZh ? 'Trojan 认证密码' : 'TROJAN AUTHENTICATION',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr.passwordLabel,
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sniCtrl,
            decoration: InputDecoration(
              labelText: tr.sniLabel,
              hintText: 'your-trojan-server.com',
              prefixIcon: const Icon(Icons.public_rounded, size: 18),
            ),
          ),
        ];

      case ProtocolOption.hysteria2:
        return [
          Text(
            tr.isZh ? 'Hysteria 2 认证与带宽参数' : 'HYSTERIA 2 CREDENTIALS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr.passwordLabel,
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sniCtrl,
            decoration: InputDecoration(
              labelText: tr.sniLabel,
              hintText: 'hy2-server.example.com',
              prefixIcon: const Icon(Icons.public_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obfsPasswordCtrl,
            decoration: InputDecoration(
              labelText: tr.obfsPassword,
              hintText: 'salamander password (可选)',
              prefixIcon: const Icon(Icons.blur_on_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _upMbpsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '上行带宽 (Up Mbps)', hintText: '100'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _downMbpsCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '下行带宽 (Down Mbps)', hintText: '500'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: Text(tr.allowInsecure, style: const TextStyle(fontSize: 13)),
            value: _allowInsecure,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _allowInsecure = v),
          ),
        ];

      case ProtocolOption.tuic:
        return [
          Text(
            tr.isZh ? 'TUIC 用户凭据与算法' : 'TUIC CREDENTIALS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _uuidCtrl,
            decoration: InputDecoration(
              labelText: tr.uuidLabel,
              hintText: 'UUID',
              prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: tr.passwordLabel,
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _congestionControl,
                  decoration: InputDecoration(labelText: tr.congestionControl),
                  items: const [
                    DropdownMenuItem(value: 'bbr', child: Text('BBR (推荐)')),
                    DropdownMenuItem(value: 'cubic', child: Text('CUBIC')),
                    DropdownMenuItem(value: 'new_reno', child: Text('New Reno')),
                  ],
                  onChanged: (v) => setState(() => _congestionControl = v ?? 'bbr'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _udpRelayMode,
                  decoration: const InputDecoration(labelText: 'UDP Relay Mode'),
                  items: const [
                    DropdownMenuItem(value: 'native', child: Text('native')),
                    DropdownMenuItem(value: 'quic', child: Text('quic')),
                  ],
                  onChanged: (v) => setState(() => _udpRelayMode = v ?? 'native'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sniCtrl,
            decoration: InputDecoration(
              labelText: tr.sniLabel,
              hintText: 'tuic-server.com',
              prefixIcon: const Icon(Icons.public_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            title: const Text('Zero RTT Handshake', style: TextStyle(fontSize: 13)),
            value: _zeroRtt,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _zeroRtt = v),
          ),
        ];

      case ProtocolOption.socks5:
      case ProtocolOption.http:
        return [
          Text(
            tr.isZh ? '认证凭据 (可选)' : 'AUTHENTICATION (OPTIONAL)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username (可选)',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (可选)',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ];
    }
  }

  Widget _buildTransportAndTlsSection(BuildContext context, Translations tr) {
    if (_protocol == ProtocolOption.vless && _vlessTlsType == 'reality') {
      // For VLESS Reality, Transport is typically TCP (or gRPC), TLS is handled above
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.transportLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _transportType,
            decoration: InputDecoration(labelText: tr.transportLabel),
            items: const [
              DropdownMenuItem(value: 'tcp', child: Text('TCP (推荐配合 Reality)')),
              DropdownMenuItem(value: 'grpc', child: Text('gRPC')),
              DropdownMenuItem(value: 'ws', child: Text('WebSocket (ws)')),
              DropdownMenuItem(value: 'httpupgrade', child: Text('HTTPUpgrade')),
            ],
            onChanged: (v) => setState(() => _transportType = v ?? 'tcp'),
          ),
          if (_transportType == 'grpc') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _serviceNameCtrl,
              decoration: InputDecoration(
                labelText: tr.grpcServiceName,
                hintText: 'e.g. grpc-service',
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.transportLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _transportType,
          decoration: InputDecoration(labelText: tr.transportLabel),
          items: const [
            DropdownMenuItem(value: 'tcp', child: Text('TCP')),
            DropdownMenuItem(value: 'ws', child: Text('WebSocket (ws)')),
            DropdownMenuItem(value: 'grpc', child: Text('gRPC')),
            DropdownMenuItem(value: 'httpupgrade', child: Text('HTTPUpgrade')),
          ],
          onChanged: (v) => setState(() => _transportType = v ?? 'tcp'),
        ),
        if (_transportType == 'ws' || _transportType == 'httpupgrade') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _pathCtrl,
                  decoration: InputDecoration(
                    labelText: tr.wsPath,
                    hintText: '/ws',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _hostCtrl,
                  decoration: InputDecoration(
                    labelText: tr.wsHost,
                    hintText: 'example.com',
                  ),
                ),
              ),
            ],
          ),
        ] else if (_transportType == 'grpc') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _serviceNameCtrl,
            decoration: InputDecoration(
              labelText: tr.grpcServiceName,
              hintText: 'serviceName',
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (_protocol != ProtocolOption.trojan && (_protocol != ProtocolOption.vless || _vlessTlsType != 'none')) ...[
          Text(
            tr.tlsLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(tr.tlsLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            value: _enableTls,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _enableTls = v),
          ),
          if (_enableTls) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _sniCtrl,
              decoration: InputDecoration(
                labelText: tr.sniLabel,
                hintText: 'server.example.com',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              title: Text(tr.allowInsecure, style: const TextStyle(fontSize: 13)),
              value: _allowInsecure,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _allowInsecure = v),
            ),
          ],
        ],
      ],
    );
  }
}
