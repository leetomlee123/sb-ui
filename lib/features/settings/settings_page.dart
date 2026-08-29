import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/engine/config_generator.dart';
import '../../core/engine/profile_parser.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/app_updater_provider.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/core_updater_provider.dart';
import '../../core/providers/geo_updater_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/network_doctor_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/byte_formatter.dart';
import '../../core/utils/version_utils.dart';
import '../../shared/widgets/double_bezel_card.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _mixedPortCtrl;
  late TextEditingController _httpPortCtrl;
  late TextEditingController _socksPortCtrl;
  late TextEditingController _clashPortCtrl;
  late TextEditingController _clashSecretCtrl;
  late TextEditingController _binaryPathCtrl;
  late TextEditingController _remoteDnsCtrl;
  late TextEditingController _directDnsCtrl;
  late TextEditingController _fakeIpRangeCtrl;
  late TextEditingController _tunMtuCtrl;
  String? _detectedVersion;
  Timer? _debounceSaveTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    final settings = ref.read(settingsProvider);
    _mixedPortCtrl = TextEditingController(text: settings.mixedPort.toString());
    _httpPortCtrl = TextEditingController(text: settings.httpPort.toString());
    _socksPortCtrl = TextEditingController(text: settings.socksPort.toString());
    _clashPortCtrl = TextEditingController(text: settings.clashApiPort.toString());
    _clashSecretCtrl = TextEditingController(text: settings.clashApiSecret);
    _binaryPathCtrl = TextEditingController(text: settings.customSingboxPath);
    _remoteDnsCtrl = TextEditingController(text: settings.remoteDns);
    _directDnsCtrl = TextEditingController(text: settings.directDns);
    _fakeIpRangeCtrl = TextEditingController(text: settings.fakeIpRange);
    _tunMtuCtrl = TextEditingController(text: settings.tunMtu.toString());
    _checkBinaryVersion();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceSaveTimer?.cancel();
    _mixedPortCtrl.dispose();
    _httpPortCtrl.dispose();
    _socksPortCtrl.dispose();
    _clashPortCtrl.dispose();
    _clashSecretCtrl.dispose();
    _binaryPathCtrl.dispose();
    _remoteDnsCtrl.dispose();
    _directDnsCtrl.dispose();
    _fakeIpRangeCtrl.dispose();
    _tunMtuCtrl.dispose();
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
            _detectedVersion = res.stdout.toString().split('\n').firstWhere(
                  (l) => l.contains('sing-box'),
                  orElse: () => 'sing-box core detected',
                );
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

  Future<void> _openConfigFolder() async {
    final dir = await StorageService.getAppConfigDir();
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [dir.path.replaceAll('/', r'\')]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
    }
  }

  void _onFieldChanged() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 600), () {
      _saveSettings(isAuto: true);
    });
  }

  Future<void> _saveSettings({bool isAuto = false}) async {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    final tr = ref.read(translationsProvider);
    final coreIsRunning = ref.read(coreProvider).isRunning;

    final newMixedPort = int.tryParse(_mixedPortCtrl.text) ?? current.mixedPort;
    final newHttpPort = int.tryParse(_httpPortCtrl.text) ?? current.httpPort;
    final newSocksPort = int.tryParse(_socksPortCtrl.text) ?? current.socksPort;
    final newClashPort = int.tryParse(_clashPortCtrl.text) ?? current.clashApiPort;
    final newClashSecret = _clashSecretCtrl.text.trim();
    final newCustomPath = _binaryPathCtrl.text.trim();
    final newRemoteDns = _remoteDnsCtrl.text.trim();
    final newDirectDns = _directDnsCtrl.text.trim();
    final newFakeIpRange = _fakeIpRangeCtrl.text.trim().isNotEmpty ? _fakeIpRangeCtrl.text.trim() : current.fakeIpRange;
    final newTunMtu = int.tryParse(_tunMtuCtrl.text) ?? current.tunMtu;

    final hasCoreConfigChanged = newMixedPort != current.mixedPort ||
        newHttpPort != current.httpPort ||
        newSocksPort != current.socksPort ||
        newClashPort != current.clashApiPort ||
        newClashSecret != current.clashApiSecret ||
        newCustomPath != current.customSingboxPath ||
        newRemoteDns != current.remoteDns ||
        newDirectDns != current.directDns ||
        newFakeIpRange != current.fakeIpRange ||
        newTunMtu != current.tunMtu;

    if (!hasCoreConfigChanged) return;

    final updated = current.copyWith(
      mixedPort: newMixedPort,
      httpPort: newHttpPort,
      socksPort: newSocksPort,
      clashApiPort: newClashPort,
      clashApiSecret: newClashSecret,
      customSingboxPath: newCustomPath,
      remoteDns: newRemoteDns,
      directDns: newDirectDns,
      fakeIpRange: newFakeIpRange,
      tunMtu: newTunMtu,
    );

    await settingsNotifier.updateSettings(updated);

    if (coreIsRunning && hasCoreConfigChanged) {
      await ref.read(coreProvider.notifier).restartCore();
    }

    if (!isAuto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            coreIsRunning && hasCoreConfigChanged
                ? (tr.isZh ? '设置已保存，核心服务已重新加载生效' : 'Settings saved and core service reloaded')
                : tr.savedSuccess,
          ),
        ),
      );
    }
  }

  void _showLiveConfigDialog(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    final profilesState = ref.read(profilesProvider);
    final activeProfile = profilesState.activeProfile;
    final configDir = (await StorageService.getAppConfigDir()).path;

    List<Map<String, dynamic>> outbounds = [];
    List<Map<String, dynamic>> customRules = [];
    Map<String, dynamic>? customDns;

    if (activeProfile != null && activeProfile.rawConfig.isNotEmpty) {
      final parsed = ProfileParser.parse(activeProfile.rawConfig);
      outbounds = parsed.outbounds;
      customRules = parsed.customRules;
      customDns = parsed.customDns;
    }

    final generatedConfig = ConfigGenerator.generate(
      settings: settings,
      parsedOutbounds: outbounds,
      customRules: customRules,
      customDns: customDns,
      configDir: configDir,
    );

    final jsonStr = const JsonEncoder.withIndent('  ').convert(generatedConfig);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: Color(0xFF818CF8)),
            const SizedBox(width: 8),
            Text(ref.read(translationsProvider).previewConfigTitle, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(
              tooltip: ref.read(translationsProvider).copyAll,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.read(translationsProvider).logsCopied), duration: const Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 750,
          height: 500,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
              ),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ref.read(translationsProvider).cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        tr.isZh ? '已开启自动保存' : 'Auto Saved',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF818CF8),
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: [
                  Tab(icon: const Icon(Icons.tune_rounded, size: 16), text: tr.tabGeneral),
                  Tab(icon: const Icon(Icons.lan_rounded, size: 16), text: tr.tabInbounds),
                  Tab(icon: const Icon(Icons.dns_rounded, size: 16), text: tr.tabDns),
                  Tab(icon: const Icon(Icons.alt_route_rounded, size: 16), text: tr.tabRouting),
                  Tab(icon: const Icon(Icons.vpn_lock_rounded, size: 16), text: tr.tabTun),
                  Tab(icon: const Icon(Icons.science_rounded, size: 16), text: tr.tabAdvanced),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(context),
                _buildInboundsTab(context),
                _buildDnsTab(context),
                _buildRoutingTab(context),
                _buildTunTab(context),
                _buildAdvancedTab(context),
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

  Widget _buildGeneralTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appUpdaterState = ref.watch(appUpdaterProvider);
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(tr.secDesktop),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
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
                  title: Text(tr.autoStartTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.autoStartSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.autoStart,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleAutoStart(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.startMinimizedTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.startMinimizedSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.startMinimized,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleStartMinimized(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.closeToTrayTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.closeToTraySubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.closeToTray,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleCloseToTray(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(tr.dashboardDisplay),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.optShowSpeedMetricsTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optShowSpeedMetricsSubtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  value: settings.showSpeedMetrics,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleShowSpeedMetrics(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.optShowTelemetryChartTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optShowTelemetryChartSubtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  value: settings.showTelemetryChart,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleShowTelemetryChart(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAppUpdateSection(context, appUpdaterState, settings, tr),
        ],
      ),
    );
  }

  Widget _buildInboundsTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    await ref.read(coreProvider.notifier).updateSystemProxyState(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.optLanTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optLanSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.allowLan,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleAllowLan(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(tr.secPorts),
          DoubleBezelCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(tr.separateInboundTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.separateInboundDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.separateInboundPorts,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleSeparateInboundPorts(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (!settings.separateInboundPorts)
                  TextField(
                    controller: _mixedPortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr.mixedPortLabel,
                      hintText: '7890',
                    ),
                    onChanged: (_) => _onFieldChanged(),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _httpPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr.httpPortLabel,
                            hintText: '7890',
                          ),
                          onChanged: (_) => _onFieldChanged(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _socksPortCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr.socksPortLabel,
                            hintText: '7891',
                          ),
                          onChanged: (_) => _onFieldChanged(),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _clashPortCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: tr.clashPortLabel,
                          hintText: '9090',
                        ),
                        onChanged: (_) => _onFieldChanged(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _clashSecretCtrl,
                        decoration: InputDecoration(
                          labelText: tr.clashSecretLabel,
                          hintText: tr.clashSecretHint,
                        ),
                        onChanged: (_) => _onFieldChanged(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(tr.secDns),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.fakeIpTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.fakeIpDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.fakeIpEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleFakeIp(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                if (settings.fakeIpEnabled) ...[
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _fakeIpRangeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fake-IP Address Range (CIDR)',
                        hintText: '198.18.0.0/15',
                      ),
                      onChanged: (_) => _onFieldChanged(),
                    ),
                  ),
                ],
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.dnsHijackTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.dnsHijackDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.dnsHijack,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleDnsHijack(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ListTile(
                  title: Text(tr.dnsStrategyTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(settings.dnsStrategy, style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                  trailing: DropdownButton<String>(
                    value: settings.dnsStrategy,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'prefer_ipv4', child: Text('prefer_ipv4 (优先 IPv4)')),
                      DropdownMenuItem(value: 'prefer_ipv6', child: Text('prefer_ipv6 (优先 IPv6)')),
                      DropdownMenuItem(value: 'ipv4_only', child: Text('ipv4_only (仅 IPv4)')),
                      DropdownMenuItem(value: 'ipv6_only', child: Text('ipv6_only (仅 IPv6)')),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await ref.read(settingsProvider.notifier).setDnsStrategy(val);
                        if (coreIsRunning) {
                          await ref.read(coreProvider.notifier).restartCore();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(tr.remoteDnsLabel),
          DoubleBezelCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _remoteDnsCtrl,
                  decoration: InputDecoration(
                    labelText: tr.remoteDnsLabel,
                    hintText: 'https://1.1.1.1/dns-query',
                  ),
                  onChanged: (_) => _onFieldChanged(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Cloudflare DoH', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _remoteDnsCtrl.text = 'https://1.1.1.1/dns-query';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('Google DoH', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _remoteDnsCtrl.text = 'https://dns.google/dns-query';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('NextDNS', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _remoteDnsCtrl.text = 'https://dns.nextdns.io/dns-query';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('AdGuard DoH', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _remoteDnsCtrl.text = 'https://dns.adguard-dns.com/dns-query';
                        _onFieldChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _directDnsCtrl,
                  decoration: InputDecoration(
                    labelText: tr.directDnsLabel,
                    hintText: '223.5.5.5',
                  ),
                  onChanged: (_) => _onFieldChanged(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Aliyun (阿里 223.5.5.5)', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _directDnsCtrl.text = '223.5.5.5';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('DNSPod (腾讯 119.29.29.29)', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _directDnsCtrl.text = '119.29.29.29';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('114 DNS', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _directDnsCtrl.text = '114.114.114.114';
                        _onFieldChanged();
                      },
                    ),
                    ActionChip(
                      label: const Text('Local System', style: TextStyle(fontSize: 10)),
                      onPressed: () {
                        _directDnsCtrl.text = 'local';
                        _onFieldChanged();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final geoState = ref.watch(geoUpdaterProvider);
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(tr.tabRouting),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.blockAdsTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.blockAdsDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.blockAds,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleBlockAds(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ListTile(
                  title: Text(tr.aiServicesTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.aiServicesRoute == 'proxy' ? tr.routeProxy : tr.routeDirect,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8)),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.aiServicesRoute,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'proxy', child: Text(tr.routeProxy)),
                      DropdownMenuItem(value: 'direct', child: Text(tr.routeDirect)),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await ref.read(settingsProvider.notifier).setAiServicesRoute(val);
                        if (coreIsRunning) {
                          await ref.read(coreProvider.notifier).restartCore();
                        }
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ListTile(
                  title: Text(tr.streamMediaTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    settings.streamMediaRoute == 'proxy' ? tr.routeProxy : tr.routeDirect,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8)),
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.streamMediaRoute,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'proxy', child: Text(tr.routeProxy)),
                      DropdownMenuItem(value: 'direct', child: Text(tr.routeDirect)),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await ref.read(settingsProvider.notifier).setStreamMediaRoute(val);
                        if (coreIsRunning) {
                          await ref.read(coreProvider.notifier).restartCore();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildGeoAssetsSection(context, geoState, tr),
        ],
      ),
    );
  }

  Widget _buildTunTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(tr.optTunTitle),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.optTunTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optTunSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.tunModeEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleTunMode(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                if (settings.tunModeEnabled) ...[
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  ListTile(
                    title: Text(tr.isZh ? 'TUN 虚拟网络栈 (Stack)' : 'TUN Network Stack', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      tr.isZh
                          ? 'mixed (混合栈 / 推荐) / system (系统原生栈) / gvisor (用户态栈)'
                          : 'mixed (recommended) / system (native) / gvisor (userspace)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.tunStack.isNotEmpty ? settings.tunStack : 'mixed',
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'mixed', child: Text('mixed (混合栈 / 推荐)')),
                        DropdownMenuItem(value: 'system', child: Text('system (系统原生栈)')),
                        DropdownMenuItem(value: 'gvisor', child: Text('gvisor (用户态栈)')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await ref.read(settingsProvider.notifier).updateTunStack(val);
                          if (coreIsRunning) {
                            await ref.read(coreProvider.notifier).restartCore();
                          }
                        }
                      },
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  SwitchListTile(
                    title: Text(tr.tunGsoTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(tr.tunGsoDesc, style: const TextStyle(fontSize: 12)),
                    value: settings.tunGso,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).toggleTunGso(val);
                      if (coreIsRunning) {
                        await ref.read(coreProvider.notifier).restartCore();
                      }
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  SwitchListTile(
                    title: Text(tr.tunStrictRouteTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(tr.tunStrictRouteDesc, style: const TextStyle(fontSize: 12)),
                    value: settings.tunStrictRoute,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).toggleTunStrictRoute(val);
                      if (coreIsRunning) {
                        await ref.read(coreProvider.notifier).restartCore();
                      }
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  SwitchListTile(
                    title: Text(tr.tunIpv6Title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(tr.tunIpv6Desc, style: const TextStyle(fontSize: 12)),
                    value: settings.tunIpv6,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).toggleTunIpv6(val);
                      if (coreIsRunning) {
                        await ref.read(coreProvider.notifier).restartCore();
                      }
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _tunMtuCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'TUN MTU Size (Default: 9000)',
                        hintText: '9000',
                      ),
                      onChanged: (_) => _onFieldChanged(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final updaterState = ref.watch(coreUpdaterProvider);
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(tr.tabAdvanced),
          DoubleBezelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(tr.sniffingTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.sniffingDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.sniffingEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleSniffing(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                if (settings.sniffingEnabled) ...[
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  SwitchListTile(
                    title: Text(tr.sniffOverrideTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(tr.sniffOverrideDesc, style: const TextStyle(fontSize: 12)),
                    value: settings.sniffingOverrideDestination,
                    onChanged: (val) async {
                      await ref.read(settingsProvider.notifier).toggleSniffingOverrideDestination(val);
                      if (coreIsRunning) {
                        await ref.read(coreProvider.notifier).restartCore();
                      }
                    },
                  ),
                ],
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.tcpFastOpenTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.tcpFastOpenDesc, style: const TextStyle(fontSize: 12)),
                  value: settings.tcpFastOpen,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleTcpFastOpen(val);
                    if (coreIsRunning) {
                      await ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ListTile(
                  title: Text(tr.multiplexTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.multiplexDesc, style: const TextStyle(fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: settings.multiplex,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None (关闭)')),
                      DropdownMenuItem(value: 'smux', child: Text('smux (Smux v1)')),
                      DropdownMenuItem(value: 'yamux', child: Text('yamux (Yamux)')),
                      DropdownMenuItem(value: 'h2mux', child: Text('h2mux (HTTP/2 Mux)')),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await ref.read(settingsProvider.notifier).setMultiplex(val);
                        if (coreIsRunning) {
                          await ref.read(coreProvider.notifier).restartCore();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(tr.btnPreviewConfig),
          DoubleBezelCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr.previewConfigTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr.isZh
                            ? '实时查看并复制当前所有配置项与激活订阅所生成的完整 sing-box config.json'
                            : 'View and copy runtime generated sing-box config.json with current settings',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showLiveConfigDialog(context),
                  icon: const Icon(Icons.data_object_rounded, size: 16),
                  label: Text(tr.btnPreviewConfig, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                        onChanged: (_) {
                          _checkBinaryVersion();
                          _onFieldChanged();
                        },
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
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${tr.detectedCore}${_detectedVersion ?? "Detecting..."}',
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: updaterState.isBusy
                          ? null
                          : () {
                              ref.read(coreUpdaterProvider.notifier).checkForUpdates(
                                    customBinaryPath: _binaryPathCtrl.text.isNotEmpty ? _binaryPathCtrl.text : null,
                                  );
                            },
                      icon: updaterState.status == UpdateStatus.checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.system_update_alt_rounded, size: 16),
                      label: Text(tr.btnCheckUpdate, style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
                if (updaterState.status != UpdateStatus.idle) ...[
                  const SizedBox(height: 16),
                  _buildUpdateStatusBanner(context, updaterState, tr),
                ],
                const SizedBox(height: 14),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.isZh ? '配置与内核日志目录' : 'Config & Core Logs Directory',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr.isZh
                                ? '存放 config.json 与 sing-box.log 日志文件'
                                : 'Houses config.json and sing-box.log files',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openConfigFolder,
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: Text(tr.isZh ? '打开目录' : 'Open Folder', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildDoctorSection(context, settings, coreIsRunning, tr),
        ],
      ),
    );
  }

  Widget _buildUpdateStatusBanner(BuildContext context, CoreUpdaterState updaterState, Translations tr) {
    Color bannerBg;
    Color bannerBorder;
    Widget content;
    if (updaterState.status == UpdateStatus.available) {
      bannerBg = const Color(0xFF6366F1).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF6366F1).withValues(alpha: 0.35);
      final release = updaterState.latestRelease!;
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(6)),
            child: Text(release.tagName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.coreNewBadge, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                Text('${(release.assetSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${release.assetName}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final success = await ref.read(coreUpdaterProvider.notifier).startUpdate();
              if (success) await _checkBinaryVersion();
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr.btnUpdateNow),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          ),
        ],
      );
    } else if (updaterState.status == UpdateStatus.downloading || updaterState.status == UpdateStatus.installing) {
      bannerBg = const Color(0xFF38BDF8).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF38BDF8).withValues(alpha: 0.35);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(updaterState.statusMessage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
              Text('${(updaterState.progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: updaterState.progress, minHeight: 6, backgroundColor: const Color(0xFF1E293B), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8))),
          ),
        ],
      );
    } else if (updaterState.status == UpdateStatus.success) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.35);
      content = Row(children: [const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)), const SizedBox(width: 8), Expanded(child: Text(updaterState.statusMessage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))))]);
    } else if (updaterState.status == UpdateStatus.upToDate) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.08);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.25);
      content = Row(children: [const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)), const SizedBox(width: 8), Expanded(child: Text(updaterState.statusMessage, style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))))]);
    } else {
      bannerBg = const Color(0xFFF43F5E).withValues(alpha: 0.1);
      bannerBorder = const Color(0xFFF43F5E).withValues(alpha: 0.3);
      content = Row(children: [const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF43F5E)), const SizedBox(width: 8), Expanded(child: Text(updaterState.errorMessage ?? updaterState.statusMessage, style: const TextStyle(fontSize: 12, color: Color(0xFFF43F5E))))]);
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: bannerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: bannerBorder, width: 1)), child: content);
  }

  Widget _buildAppUpdateSection(BuildContext context, AppUpdaterState appUpdaterState, AppSettings settings, Translations tr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.secAppUpdate),
        DoubleBezelCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.apps_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${tr.appCurrentVersion}v${normalizeSemver(appUpdaterState.currentVersion ?? "1.2.34")}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: appUpdaterState.isBusy ? null : () => ref.read(appUpdaterProvider.notifier).checkForUpdates(manual: true),
                    icon: appUpdaterState.status == UpdateStatus.checking ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.system_update_alt_rounded, size: 16),
                    label: Text(tr.btnCheckAppUpdate, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                ],
              ),
              if (!Platform.isWindows) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr.appUpdateUnsupported, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))),
                  ],
                ),
              ],
              if (appUpdaterState.status != UpdateStatus.idle) ...[
                const SizedBox(height: 16),
                _buildAppUpdateStatusBanner(context, appUpdaterState, tr),
              ],
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(tr.autoCheckAppUpdatesTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(tr.autoCheckAppUpdatesSubtitle, style: const TextStyle(fontSize: 12)),
                value: settings.autoCheckAppUpdates,
                onChanged: (val) => ref.read(settingsProvider.notifier).toggleAutoCheckAppUpdates(val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppUpdateStatusBanner(BuildContext context, AppUpdaterState state, Translations tr) {
    Color bannerBg;
    Color bannerBorder;
    Widget content;
    if (state.status == UpdateStatus.available) {
      bannerBg = const Color(0xFF6366F1).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF6366F1).withValues(alpha: 0.35);
      final release = state.latestRelease;
      final tagText = release?.tagName ?? state.statusMessage;
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(6)),
            child: Text(tagText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.appNewBadge, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                if (release != null && release.assetSize > 0)
                  Text('${(release.assetSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${release.assetName}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                else
                  Text(state.statusMessage, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: Platform.isWindows ? () => ref.read(appUpdaterProvider.notifier).applyUpdate() : null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr.appUpdateNow),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.4), disabledForegroundColor: Colors.white70),
          ),
        ],
      );
    } else if (state.status == UpdateStatus.downloading || state.status == UpdateStatus.installing) {
      bannerBg = const Color(0xFF38BDF8).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF38BDF8).withValues(alpha: 0.35);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(state.status == UpdateStatus.installing ? tr.appInstallingRestartMsg : state.statusMessage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)))),
              Text('${(state.progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: state.progress > 0 ? state.progress : null, minHeight: 6, backgroundColor: const Color(0xFF1E293B), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8))),
          ),
        ],
      );
    } else if (state.status == UpdateStatus.upToDate || state.status == UpdateStatus.success) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.08);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.25);
      content = Row(children: [const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)), const SizedBox(width: 8), Expanded(child: Text(state.currentVersion != null ? '${tr.appUpToDateMsg} (v${state.currentVersion})' : tr.appUpToDateMsg, style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))))]);
    } else {
      bannerBg = const Color(0xFFF43F5E).withValues(alpha: 0.1);
      bannerBorder = const Color(0xFFF43F5E).withValues(alpha: 0.3);
      content = Row(children: [const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF43F5E)), const SizedBox(width: 8), Expanded(child: SelectableText(state.errorMessage ?? state.statusMessage, style: const TextStyle(fontSize: 12, color: Color(0xFFF43F5E))))]);
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: bannerBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: bannerBorder, width: 1)), child: content);
  }

  Widget _buildGeoAssetsSection(BuildContext context, GeoUpdaterState geoState, Translations tr) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final itemBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.secGeoAssets),
        DoubleBezelCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(tr.autoUpdateRuleset, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(tr.autoUpdateRulesetDesc, style: const TextStyle(fontSize: 11)),
                value: settings.autoUpdateRuleset,
                onChanged: (val) => ref.read(settingsProvider.notifier).toggleAutoUpdateRuleset(val),
              ),
              const SizedBox(height: 16),
              if (geoState.statusMessage.isNotEmpty && geoState.isUpdating) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(geoState.statusMessage, style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8), fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 650 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, mainAxisExtent: 96, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: geoState.assets.length,
                    itemBuilder: (context, index) {
                      final asset = geoState.assets[index];
                      final isCurrentUpdating = geoState.isUpdating && geoState.activeAssetName == asset.name;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: itemBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: itemBorder)),
                        child: Row(
                          children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.dataset_rounded, color: Color(0xFF818CF8), size: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(child: Text(asset.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(color: asset.isInstalled ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                        child: Text(asset.isInstalled ? tr.geoInstalled : '未安装', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: asset.isInstalled ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('${tr.fileSize}${ByteFormatter.formatBytes(asset.sizeInBytes)}', style: TextStyle(fontSize: 10, color: textMuted)),
                                  Text(asset.lastModified != null ? '${tr.lastUpdated}${DateFormat('yyyy-MM-dd HH:mm').format(asset.lastModified!)}' : '${tr.lastUpdated}未知', style: TextStyle(fontSize: 10, color: textMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: isCurrentUpdating || geoState.isUpdating ? null : () => ref.read(geoUpdaterProvider.notifier).updateSingleAsset(asset),
                              icon: isCurrentUpdating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))) : const Icon(Icons.refresh_rounded, size: 16),
                              tooltip: '${tr.updateSingle} ${asset.name}',
                              style: IconButton.styleFrom(backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorSection(BuildContext context, AppSettings settings, bool isRunning, Translations tr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.isZh ? '系统与网络体检诊断' : 'SYSTEM & NETWORK DIAGNOSTICS'),
        DoubleBezelCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(tr.isZh ? '一键网络与核心诊断' : 'One-Click Network Doctor', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(tr.isZh ? '全面检测系统环境、配置与网络连通性' : 'Comprehensive diagnostic check', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDoctorDialog(context, settings, isRunning, tr),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(tr.isZh ? '立即体检' : 'Run Diagnostics', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDoctorDialog(BuildContext context, AppSettings settings, bool isRunning, Translations tr) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        List<DiagnosticItem>? results;
        bool isDiagnosing = true;
        return StatefulBuilder(
          builder: (ctx, setState) {
            if (isDiagnosing && results == null) {
              NetworkDoctorService.runDiagnostics(settings: settings, isCoreRunning: isRunning).then((items) {
                if (ctx.mounted) setState(() { results = items; isDiagnosing = false; });
              });
            }
            return AlertDialog(
              title: Text(tr.isZh ? '诊断报告' : 'Diagnostic Report'),
              content: SizedBox(width: 500, child: isDiagnosing ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())) : Column(children: results!.map((i) => Text('${i.title}: ${i.status}')).toList())),
              actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: Text(tr.confirm))],
            );
          },
        );
      },
    );
  }
}
