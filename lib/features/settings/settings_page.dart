import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _mixedPortCtrl;
  late TextEditingController _clashPortCtrl;
  late TextEditingController _clashSecretCtrl;
  late TextEditingController _binaryPathCtrl;
  late TextEditingController _remoteDnsCtrl;
  late TextEditingController _directDnsCtrl;
  String? _detectedVersion;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _mixedPortCtrl = TextEditingController(text: settings.mixedPort.toString());
    _clashPortCtrl = TextEditingController(text: settings.clashApiPort.toString());
    _clashSecretCtrl = TextEditingController(text: settings.clashApiSecret);
    _binaryPathCtrl = TextEditingController(text: settings.customSingboxPath);
    _remoteDnsCtrl = TextEditingController(text: settings.remoteDns);
    _directDnsCtrl = TextEditingController(text: settings.directDns);
    _checkBinaryVersion();
  }

  @override
  void dispose() {
    _mixedPortCtrl.dispose();
    _clashPortCtrl.dispose();
    _clashSecretCtrl.dispose();
    _binaryPathCtrl.dispose();
    _remoteDnsCtrl.dispose();
    _directDnsCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBinaryVersion() async {
    final processMgr = ref.read(coreProvider.notifier).processManager;
    final binary = await processMgr.findSingboxBinary(
      customPath: _binaryPathCtrl.text.isNotEmpty ? _binaryPathCtrl.text : null,
    );
    if (binary != null) {
      try {
        final res = await Process.run(binary, ['version']);
        if (mounted) {
          setState(() {
            _detectedVersion = res.stdout.toString().split('\n').firstWhere((l) => l.contains('sing-box'), orElse: () => 'sing-box core detected');
          });
        }
      } catch (_) {}
    } else {
      if (mounted) {
        setState(() {
          _detectedVersion = 'Binary not found';
        });
      }
    }
  }

  void _saveSettings() {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);

    final updated = current.copyWith(
      mixedPort: int.tryParse(_mixedPortCtrl.text) ?? current.mixedPort,
      clashApiPort: int.tryParse(_clashPortCtrl.text) ?? current.clashApiPort,
      clashApiSecret: _clashSecretCtrl.text.trim(),
      customSingboxPath: _binaryPathCtrl.text.trim(),
      remoteDns: _remoteDnsCtrl.text.trim(),
      directDns: _directDnsCtrl.text.trim(),
    );

    settingsNotifier.updateSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreState = ref.watch(coreProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settings & Configuration',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Settings'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Core & Proxy Mode Section
          _buildSectionHeader('Proxy & Networking Modes'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('System Proxy', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Automatically configure OS system HTTP/SOCKS proxy settings'),
                  value: settings.systemProxyEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleSystemProxy(val);
                    if (coreState.isRunning) {
                      ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('TUN Mode (Virtual Network Interface)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Route all system traffic through a virtual TUN adapter (may require root/admin privileges)'),
                  value: settings.tunModeEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleTunMode(val);
                    if (coreState.isRunning) {
                      ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Allow LAN Connections', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bind inbound proxy port to 0.0.0.0 allowing devices on the local network to connect'),
                  value: settings.allowLan,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleAllowLan(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Ports & Core Inbound
          _buildSectionHeader('Ports & Core Inbound'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mixedPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mixed Inbound Port (HTTP & SOCKS)',
                            hintText: '2080',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _clashPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Clash API External Controller Port',
                            hintText: '9090',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _clashSecretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clash API Secret (Optional)',
                      hintText: 'Leave empty for no auth token',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // DNS Configuration
          _buildSectionHeader('DNS Resolution'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _remoteDnsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remote DNS (Encrypted DoH / DoT / UDP)',
                      hintText: 'https://1.1.1.1/dns-query',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _directDnsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Direct / Domestic DNS',
                      hintText: '223.5.5.5',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // sing-box Binary & System
          _buildSectionHeader('sing-box Core Binary'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _binaryPathCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Custom sing-box Binary Path (Optional)',
                            hintText: 'Leave blank to auto-detect from PATH (/usr/local/bin/sing-box)',
                          ),
                          onChanged: (_) => _checkBinaryVersion(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _checkBinaryVersion,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Test'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        'Detected Core: ${_detectedVersion ?? "Detecting..."}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // General & Desktop Behavior
          _buildSectionHeader('Desktop Preferences'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Close to System Tray', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Keep application running in background when clicking close'),
                  value: settings.closeToTray,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(closeToTray: val));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(settings.themeMode.toUpperCase()),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode, size: 16)),
                      ButtonSegment(value: 'light', icon: Icon(Icons.light_mode, size: 16)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) {
                      ref.read(settingsProvider.notifier).setThemeMode(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF818CF8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
