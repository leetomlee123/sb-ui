import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/double_bezel_card.dart';

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONFIGURATION & PREFERENCES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize network inbounds, DNS resolvers, and desktop behavioral parameters',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Changes'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Core & Proxy Mode Section
          _buildSectionHeader('ROUTING & NETWORK ADAPTERS'),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('System Proxy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Automatically configure OS HTTP/SOCKS system proxy endpoints', style: TextStyle(fontSize: 12)),
                  value: settings.systemProxyEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleSystemProxy(val);
                    if (coreState.isRunning) {
                      ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: const Text('TUN Virtual Adapter Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Route all system IP packets through transparent TUN virtual interface', style: TextStyle(fontSize: 12)),
                  value: settings.tunModeEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleTunMode(val);
                    if (coreState.isRunning) {
                      ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: const Text('Allow Local Network Access (LAN)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Bind inbound mixed proxy to 0.0.0.0 allowing LAN devices to connect', style: TextStyle(fontSize: 12)),
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
          _buildSectionHeader('INBOUND PORTS & CONTROLLER API'),
          DoubleBezelCard(
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
                          labelText: 'Mixed Inbound Port (HTTP / SOCKS5)',
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
                    labelText: 'Clash API Authorization Secret (Optional)',
                    hintText: 'Leave empty for no authentication token',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // DNS Configuration
          _buildSectionHeader('ENCRYPTED & LOCAL DNS RESOLVERS'),
          DoubleBezelCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _remoteDnsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remote DNS (DoH / DoT / HTTPS / UDP)',
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

          const SizedBox(height: 24),

          // sing-box Binary & System
          _buildSectionHeader('SING-BOX CORE EXECUTABLE'),
          DoubleBezelCard(
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
                          labelText: 'Custom Core Binary Path (Optional)',
                          hintText: 'Auto-detected from PATH or bundled sidecar',
                        ),
                        onChanged: (_) => _checkBinaryVersion(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _checkBinaryVersion,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Test Core'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Detected Core: ${_detectedVersion ?? "Detecting..."}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // General & Desktop Behavior
          _buildSectionHeader('DESKTOP ENVIRONMENT PREFERENCES'),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Minimize to System Tray on Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Keep core active in background when clicking window close button', style: TextStyle(fontSize: 12)),
                  value: settings.closeToTray,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(closeToTray: val));
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ListTile(
                  title: const Text('Application Color Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.themeMode.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode_rounded, size: 16), label: Text('Dark')),
                      ButtonSegment(value: 'light', icon: Icon(Icons.light_mode_rounded, size: 16), label: Text('Light')),
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
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF818CF8),
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
