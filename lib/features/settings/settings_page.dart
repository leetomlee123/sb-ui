import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/app_updater_provider.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/core_updater_provider.dart';
import '../../core/providers/geo_updater_provider.dart';
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

  Future<void> _saveSettings() async {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    final tr = ref.read(translationsProvider);
    final coreIsRunning = ref.read(coreProvider).isRunning;

    final newMixedPort = int.tryParse(_mixedPortCtrl.text) ?? current.mixedPort;
    final newClashPort = int.tryParse(_clashPortCtrl.text) ?? current.clashApiPort;
    final newClashSecret = _clashSecretCtrl.text.trim();
    final newCustomPath = _binaryPathCtrl.text.trim();
    final newRemoteDns = _remoteDnsCtrl.text.trim();
    final newDirectDns = _directDnsCtrl.text.trim();

    final hasCoreConfigChanged = newMixedPort != current.mixedPort ||
        newClashPort != current.clashApiPort ||
        newClashSecret != current.clashApiSecret ||
        newCustomPath != current.customSingboxPath ||
        newRemoteDns != current.remoteDns ||
        newDirectDns != current.directDns;

    final updated = current.copyWith(
      mixedPort: newMixedPort,
      clashApiPort: newClashPort,
      clashApiSecret: newClashSecret,
      customSingboxPath: newCustomPath,
      remoteDns: newRemoteDns,
      directDns: newDirectDns,
    );

    await settingsNotifier.updateSettings(updated);

    if (coreIsRunning && hasCoreConfigChanged) {
      await ref.read(coreProvider.notifier).restartCore();
    }

    if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final coreIsRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final updaterState = ref.watch(coreUpdaterProvider);
    final geoState = ref.watch(geoUpdaterProvider);
    final appUpdaterState = ref.watch(appUpdaterProvider);
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
                    await ref.read(coreProvider.notifier).updateSystemProxyState(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                SwitchListTile(
                  title: Text(tr.optTunTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.optTunSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.tunModeEnabled,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).toggleTunMode(val);
                    if (coreIsRunning) {
                      ref.read(coreProvider.notifier).restartCore();
                    }
                  },
                ),
                if (settings.tunModeEnabled) ...[
                  Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  ListTile(
                    title: Text(tr.isZh ? 'TUN 网络栈 (Stack)' : 'TUN Network Stack', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      tr.isZh
                          ? 'system (推荐：系统原生栈，低CPU，适配UDP/Hy2) / mixed / gvisor'
                          : 'system (recommended: native stack, low CPU) / mixed / gvisor',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.tunStack.isNotEmpty ? settings.tunStack : 'system',
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'system', child: Text('system (系统原生/低CPU)')),
                        DropdownMenuItem(value: 'mixed', child: Text('mixed (混合栈)')),
                        DropdownMenuItem(value: 'gvisor', child: Text('gvisor (用户态栈)')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await ref.read(settingsProvider.notifier).updateTunStack(val);
                          if (coreIsRunning) {
                            ref.read(coreProvider.notifier).restartCore();
                          }
                        }
                      },
                    ),
                  ),
                ],
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
                          hintText: '7890',
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

          // sing-box Binary & Remote Update System
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
                const SizedBox(height: 14),

                // Core Status & Remote Update Panel
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

                // Update info banner when available or downloading
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
                            tr.isZh ? '配置与内核日志' : 'Config & Core Logs',
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

          // Geo Assets & Routing Datasets (v2rayNG style)
          _buildGeoAssetsSection(context, geoState, tr),

          const SizedBox(height: 24),

          // Network & Core Diagnostic Doctor
          _buildDoctorSection(context, settings, coreIsRunning, tr),

          const SizedBox(height: 24),

          // App Self-Update (GitHub Releases)
          _buildAppUpdateSection(context, appUpdaterState, settings, tr),

          const SizedBox(height: 24),

          // Dashboard Module Preferences
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
                // Auto start on boot
                SwitchListTile(
                  title: Text(tr.autoStartTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.autoStartSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.autoStart,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleAutoStart(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                // Start minimized to tray
                SwitchListTile(
                  title: Text(tr.startMinimizedTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(tr.startMinimizedSubtitle, style: const TextStyle(fontSize: 12)),
                  value: settings.startMinimized,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleStartMinimized(val);
                  },
                ),
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                // Close to tray
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
        ],
      ),
    );
  }

  Widget _buildUpdateStatusBanner(
    BuildContext context,
    CoreUpdaterState updaterState,
    Translations tr,
  ) {
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
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              release.tagName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.coreNewBadge,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                ),
                Text(
                  '${(release.assetSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${release.assetName}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final success = await ref.read(coreUpdaterProvider.notifier).startUpdate();
              if (success) {
                await _checkBinaryVersion();
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr.btnUpdateNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    } else if (updaterState.status == UpdateStatus.downloading ||
        updaterState.status == UpdateStatus.installing) {
      bannerBg = const Color(0xFF38BDF8).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF38BDF8).withValues(alpha: 0.35);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                updaterState.statusMessage,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
              Text(
                '${(updaterState.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: updaterState.progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
        ],
      );
    } else if (updaterState.status == UpdateStatus.success) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.35);

      content = Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              updaterState.statusMessage,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            ),
          ),
        ],
      );
    } else if (updaterState.status == UpdateStatus.upToDate) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.08);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.25);

      content = Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              updaterState.statusMessage,
              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
            ),
          ),
        ],
      );
    } else {
      bannerBg = const Color(0xFFF43F5E).withValues(alpha: 0.1);
      bannerBorder = const Color(0xFFF43F5E).withValues(alpha: 0.3);

      content = Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              updaterState.errorMessage ?? updaterState.statusMessage,
              style: const TextStyle(fontSize: 12, color: Color(0xFFF43F5E)),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerBorder, width: 1),
      ),
      child: content,
    );
  }

  Widget _buildAppUpdateSection(
    BuildContext context,
    AppUpdaterState appUpdaterState,
    AppSettings settings,
    Translations tr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.secAppUpdate),
        DoubleBezelCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current version + check button
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
                            '${tr.appCurrentVersion}v${normalizeSemver(appUpdaterState.currentVersion ?? "1.2.19")}',
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: appUpdaterState.isBusy
                        ? null
                        : () {
                            ref.read(appUpdaterProvider.notifier).checkForUpdates(manual: true);
                          },
                    icon: appUpdaterState.status == UpdateStatus.checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.system_update_alt_rounded, size: 16),
                    label: Text(tr.btnCheckAppUpdate, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),

              if (!Platform.isWindows) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr.appUpdateUnsupported,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ],

              // Update status banner (available / progress / error)
              if (appUpdaterState.status != UpdateStatus.idle) ...[
                const SizedBox(height: 16),
                _buildAppUpdateStatusBanner(context, appUpdaterState, tr),
              ],

              const Divider(height: 24),

              // Auto check on startup preference
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(tr.autoCheckAppUpdatesTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(tr.autoCheckAppUpdatesSubtitle, style: const TextStyle(fontSize: 12)),
                value: settings.autoCheckAppUpdates,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).toggleAutoCheckAppUpdates(val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppUpdateStatusBanner(
    BuildContext context,
    AppUpdaterState state,
    Translations tr,
  ) {
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
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tagText,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.appNewBadge,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                ),
                if (release != null && release.assetSize > 0)
                  Text(
                    '${(release.assetSize / (1024 * 1024)).toStringAsFixed(1)} MB • ${release.assetName}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  )
                else
                  Text(
                    state.statusMessage,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: Platform.isWindows
                ? () {
                    ref.read(appUpdaterProvider.notifier).applyUpdate();
                  }
                : null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr.appUpdateNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.4),
              disabledForegroundColor: Colors.white70,
            ),
          ),
        ],
      );
    } else if (state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      bannerBg = const Color(0xFF38BDF8).withValues(alpha: 0.12);
      bannerBorder = const Color(0xFF38BDF8).withValues(alpha: 0.35);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  state.status == UpdateStatus.installing
                      ? tr.appInstallingRestartMsg
                      : state.statusMessage,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
              ),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              minHeight: 6,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
        ],
      );
    } else if (state.status == UpdateStatus.upToDate ||
        state.status == UpdateStatus.success) {
      bannerBg = const Color(0xFF10B981).withValues(alpha: 0.08);
      bannerBorder = const Color(0xFF10B981).withValues(alpha: 0.25);

      content = Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.currentVersion != null
                  ? '${tr.appUpToDateMsg} (v${state.currentVersion})'
                  : tr.appUpToDateMsg,
              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
            ),
          ),
        ],
      );
    } else {
      bannerBg = const Color(0xFFF43F5E).withValues(alpha: 0.1);
      bannerBorder = const Color(0xFFF43F5E).withValues(alpha: 0.3);

      content = Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              state.errorMessage ?? state.statusMessage,
              style: const TextStyle(fontSize: 12, color: Color(0xFFF43F5E)),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerBorder, width: 1),
      ),
      child: content,
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

  Widget _buildGeoAssetsSection(
    BuildContext context,
    GeoUpdaterState geoState,
    Translations tr,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final itemBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final itemBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final textMuted = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.secGeoAssets),
        DoubleBezelCard(
          backgroundColor: cardBg,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tr.geoAssetsDesc,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: geoState.isUpdating
                        ? null
                        : () {
                            ref.read(geoUpdaterProvider.notifier).updateAllAssets();
                          },
                    icon: geoState.isUpdating && geoState.activeAssetName == null
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 16),
                    label: Text(tr.updateAllGeo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
              if (geoState.isUpdating) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF0284C7) : const Color(0xFFBAE6FD),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: geoState.progress > 0 ? geoState.progress : null,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFBAE6FD),
                          color: const Color(0xFF0284C7),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.sync_rounded, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              geoState.statusMessage,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (geoState.successMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          geoState.successMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (geoState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF881337).withValues(alpha: 0.3) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFFE11D48) : const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFF43F5E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          geoState.errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...geoState.assets.map((asset) {
                final isCurrentUpdating = geoState.isUpdating && geoState.activeAssetName == asset.name;
                final dateStr = asset.lastModified != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(asset.lastModified!)
                    : 'Bundled (内置)';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: itemBorder, width: 1.2),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(Icons.storage_rounded, size: 20, color: Color(0xFF818CF8)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  asset.displayName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: asset.isInstalled
                                        ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFDCFCE7))
                                        : (isDark ? const Color(0xFF64748B).withValues(alpha: 0.2) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: asset.isInstalled
                                          ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF86EFAC))
                                          : (isDark ? const Color(0xFF64748B).withValues(alpha: 0.4) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Text(
                                    asset.isInstalled ? tr.geoInstalled : 'Missing',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: asset.isInstalled
                                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF166534))
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              asset.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    '${tr.fileSize}${ByteFormatter.formatBytes(asset.sizeInBytes)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    '${tr.lastUpdated}$dateStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton.icon(
                        onPressed: geoState.isUpdating
                            ? null
                            : () {
                                ref.read(geoUpdaterProvider.notifier).updateSingleAsset(asset);
                              },
                        icon: isCurrentUpdating
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(tr.updateSingle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF818CF8),
                          side: const BorderSide(color: Color(0xFF818CF8), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorSection(
    BuildContext context,
    AppSettings settings,
    bool isRunning,
    Translations tr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(tr.isZh ? '网络与核心健康诊断' : 'DIAGNOSTIC & HEALTH DOCTOR'),
        DoubleBezelCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.health_and_safety_rounded, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          tr.isZh ? '一键网络与核心诊断' : 'One-Click Network Doctor',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr.isZh
                          ? '对 sing-box 可执行文件、端口冲突、Geo 规则库完整性、系统 DNS 及 Clash 控制信道执行全面体检'
                          : 'Check core binary, port conflicts, Geo assets, system DNS and Clash API channel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showDoctorDialog(context, settings, isRunning, tr),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: Text(tr.isZh ? '立即体检' : 'Run Diagnostics', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDoctorDialog(
    BuildContext context,
    AppSettings settings,
    bool isRunning,
    Translations tr,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        List<DiagnosticItem>? results;
        bool isDiagnosing = true;

        return StatefulBuilder(
          builder: (ctx, setState) {
            if (isDiagnosing && results == null) {
              NetworkDoctorService.runDiagnostics(
                settings: settings,
                isCoreRunning: isRunning,
              ).then((items) {
                if (ctx.mounted) {
                  setState(() {
                    results = items;
                    isDiagnosing = false;
                  });
                }
              });
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              title: Row(
                children: [
                  const Icon(Icons.medical_services_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr.isZh ? '网络与核心环境诊断报告' : 'Diagnostic Health Report',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: tr.refresh,
                    onPressed: isDiagnosing
                        ? null
                        : () {
                            setState(() {
                              isDiagnosing = true;
                              results = null;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: isDiagnosing
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('正在检测系统环境、端口占用与核心连接...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: results!.map((item) {
                          IconData statusIcon;
                          Color statusColor;
                          switch (item.status) {
                            case DiagnosticStatus.pass:
                              statusIcon = Icons.check_circle_rounded;
                              statusColor = const Color(0xFF10B981);
                              break;
                            case DiagnosticStatus.warn:
                              statusIcon = Icons.warning_rounded;
                              statusColor = const Color(0xFFF59E0B);
                              break;
                            case DiagnosticStatus.fail:
                              statusIcon = Icons.cancel_rounded;
                              statusColor = const Color(0xFFF43F5E);
                              break;
                            case DiagnosticStatus.checking:
                              statusIcon = Icons.hourglass_top_rounded;
                              statusColor = const Color(0xFF38BDF8);
                              break;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(statusIcon, size: 18, color: statusColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.detail,
                                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(tr.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
