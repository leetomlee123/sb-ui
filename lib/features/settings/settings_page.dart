import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
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
    final tr = ref.read(translationsProvider);

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
      SnackBar(content: Text(tr.savedSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreState = ref.watch(coreProvider);
    final tr = ref.watch(translationsProvider);

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
                  Text(
                    tr.settingsHeader,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr.settingsHeaderDesc,
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
                label: Text(tr.saveChanges),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Core & Proxy Mode Section
          _buildSectionHeader(tr.secRouting),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.optSysProxyTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optSysProxySubtitle, style: const TextStyle(fontSize: 12)),
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
                  title: Text(tr.optTunTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optTunSubtitle, style: const TextStyle(fontSize: 12)),
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
                  title: Text(tr.optLanTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optLanSubtitle, style: const TextStyle(fontSize: 12)),
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
          _buildSectionHeader(tr.secPorts),
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
                        decoration: InputDecoration(
                          labelText: tr.mixedPortLabel,
                          hintText: '2080',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _clashPortCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr.clashPortLabel,
                          hintText: '9090',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _clashSecretCtrl,
                  decoration: InputDecoration(
                    labelText: tr.clashSecretLabel,
                    hintText: tr.clashSecretHint,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // DNS Configuration
          _buildSectionHeader(tr.secDns),
          DoubleBezelCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _remoteDnsCtrl,
                  decoration: InputDecoration(
                    labelText: tr.remoteDnsLabel,
                    hintText: 'https://1.1.1.1/dns-query',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _directDnsCtrl,
                  decoration: InputDecoration(
                    labelText: tr.directDnsLabel,
                    hintText: '223.5.5.5',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // sing-box Binary & System
          _buildSectionHeader(tr.secBinary),
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
                        decoration: InputDecoration(
                          labelText: tr.customBinaryLabel,
                          hintText: tr.customBinaryHint,
                        ),
                        onChanged: (_) => _checkBinaryVersion(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _checkBinaryVersion,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(tr.testCore),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      '${tr.detectedCore}${_detectedVersion ?? "Detecting..."}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // General & Desktop Behavior
          _buildSectionHeader(tr.secDesktop),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Language selector
                ListTile(
                  title: Text(tr.languageTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.language == 'zh' ? '简体中文' : 'English', style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                  trailing: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'zh', label: Text(tr.langZh, style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'en', label: Text(tr.langEn, style: const TextStyle(fontSize: 12))),
                    ],
                    selected: {settings.language},
                    onSelectionChanged: (set) {
                      ref.read(settingsProvider.notifier).setLanguage(set.first);
                    },
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                // Theme selector
                ListTile(
                  title: Text(tr.themeTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.closeToTrayTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.closeToTraySubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.closeToTray,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(closeToTray: val));
                  },
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
