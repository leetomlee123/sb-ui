import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/proxy_node.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/providers/proxies_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../core/utils/proxy_flag_helper.dart';
import '../../shared/widgets/app_title_bar.dart';
import '../connections/connections_page.dart';
import '../dashboard/dashboard_page.dart';
import '../logs/logs_page.dart';
import '../profiles/profiles_page.dart';
import '../proxies/proxies_page.dart';
import '../settings/settings_page.dart';

class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView> {
  int _selectedIndex = 0;

  // Lazy tab mounting: pages are constructed on first visit only, then kept
  // alive by the IndexedStack. Avoids building all six pages (and their
  // initState side effects: process spawns, disk scans, config parsing)
  // during app startup.
  final Set<int> _mountedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Top Frameless Title Bar
          const AppTitleBar(),

          // Main Center Viewport
          Expanded(
            child: Row(
              children: [
                // Refined Obsidian Sidebar Navigation Rail
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                      _mountedTabs.add(index);
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  minWidth: 80,
                  useIndicator: true,
                  indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.speed_rounded),
                      selectedIcon: const Icon(Icons.speed_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navDashboard),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.alt_route_rounded),
                      selectedIcon: const Icon(Icons.alt_route_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navProxies),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_shared_rounded),
                      selectedIcon: const Icon(Icons.folder_shared_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navProfiles),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.compare_arrows_rounded),
                      selectedIcon: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navConnections),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.terminal_rounded),
                      selectedIcon: const Icon(Icons.terminal_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navLogs),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.tune_rounded),
                      selectedIcon: const Icon(Icons.tune_rounded, color: Color(0xFF818CF8)),
                      label: Text(tr.navSettings),
                    ),
                  ],
                ),

                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),

                // Active Tab Content Page
                Expanded(
                  child: Container(
                    color: isDark ? const Color(0xFF070A12) : const Color(0xFFF8FAFC),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        for (var i = 0; i < 6; i++) _buildTab(i),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Telemetry Status Ribbon (Isolated ConsumerWidget to eliminate parent rebuilds)
          const BottomStatusRibbon(),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    if (!_mountedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return DashboardPage(isVisible: _selectedIndex == 0);
      case 1:
        return const ProxiesPage();
      case 2:
        return const ProfilesPage();
      case 3:
        return ConnectionsPage(isVisible: _selectedIndex == 3);
      case 4:
        return LogsPage(isVisible: _selectedIndex == 4);
      case 5:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }
}

class BottomStatusRibbon extends ConsumerWidget {
  const BottomStatusRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final currentDown = ref.watch(trafficProvider.select((s) => s.currentDown));
    final currentUp = ref.watch(trafficProvider.select((s) => s.currentUp));
    final activeProfileName = ref.watch(profilesProvider.select((s) => s.activeProfile?.name));
    final routingMode = ref.watch(settingsProvider.select((s) => s.routingMode));
    final mixedPort = ref.watch(settingsProvider.select((s) => s.mixedPort));
    final allowLan = ref.watch(settingsProvider.select((s) => s.allowLan));
    final tunModeEnabled = ref.watch(settingsProvider.select((s) => s.tunModeEnabled));
    final currentNodeName = ref.watch(proxiesProvider.select((s) {
      final grp = s.groups['Proxy'] ?? (s.groups.isNotEmpty ? s.groups.values.first : null);
      return (grp != null && grp.current.isNotEmpty) ? grp.current : 'Auto';
    }));
    final tr = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C16) : Colors.white,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Connection State, Active Profile & Status Tags
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isRunning ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    shape: BoxShape.circle,
                    boxShadow: isRunning
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    activeProfileName ?? tr.noActiveProfile,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                // Routing Mode Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    routingMode == RoutingMode.rule
                        ? tr.modeRule.toUpperCase()
                        : (routingMode == RoutingMode.global
                            ? tr.modeGlobal.toUpperCase()
                            : tr.modeDirect.toUpperCase()),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Active Outbound Node Tag (interactive with quick switch dialog)
                Tooltip(
                  message: '${tr.isZh ? "当前出口节点" : "Active Outbound Node"}: $currentNodeName\n${tr.isZh ? "点击快捷切换节点" : "Click to quick switch node"}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _showQuickNodeSelectorDialog(
                          context,
                          ref,
                          currentNodeName: currentNodeName,
                          tr: tr,
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isRunning
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFF64748B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                : const Color(0xFF64748B).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hub_rounded,
                              size: 10,
                              color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                isRunning ? currentNodeName : (tr.isZh ? '待机' : 'Standby'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Listening Port Tag (interactive with tooltip, click-to-edit & auto-restart)
                Tooltip(
                  message: '${tr.isZh ? "入站标签" : "Inbound Tag"}: mixed-in (${allowLan ? "0.0.0.0" : "127.0.0.1"}:$mixedPort)\n${tr.isZh ? "点击修改端口或复制地址" : "Click to edit port or copy address"}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _showEditPortDialog(
                          context,
                          ref,
                          currentPort: mixedPort,
                          allowLan: allowLan,
                          isRunning: isRunning,
                          tr: tr,
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isRunning
                              ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
                              : const Color(0xFF64748B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isRunning
                                ? const Color(0xFF0EA5E9).withValues(alpha: 0.3)
                                : const Color(0xFF64748B).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lan_outlined,
                              size: 10,
                              color: isRunning ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'mixed-in: $mixedPort',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontFamily: 'monospace',
                                color: isRunning ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (tunModeEnabled) ...[
                  const SizedBox(width: 8),
                  // TUN Tag
                  Tooltip(
                    message: '${tr.isZh ? "入站标签" : "Inbound Tag"}: tun-in (singbox-tun)',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'TUN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                  ),
                ],
                if (allowLan) ...[
                  const SizedBox(width: 8),
                  // LAN Tag
                  Tooltip(
                    message: tr.isZh ? '允许局域网连接 (0.0.0.0)' : 'Allow LAN Connections (0.0.0.0)',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'LAN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Core Restart Button
                Tooltip(
                  message: isRunning
                      ? (tr.isZh ? '重启 sing-box 核心服务' : 'Restart sing-box core service')
                      : (tr.isZh ? '启动 sing-box 核心服务' : 'Start sing-box core service'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (isRunning) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr.restartingCore),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              width: 320,
                            ),
                          );
                          await ref.read(coreProvider.notifier).restartCore();
                        } else {
                          await ref.read(coreProvider.notifier).startCore();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isRunning
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : const Color(0xFF64748B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isRunning
                                ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                                : const Color(0xFF64748B).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 11,
                              color: isRunning ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tr.isZh ? '重启' : 'RESTART',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isRunning ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right: Real-time Speeds
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward_rounded, size: 13, color: Color(0xFF38BDF8)),
              const SizedBox(width: 3),
              Text(
                ByteFormatter.formatSpeed(currentDown),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF818CF8)),
              const SizedBox(width: 3),
              Text(
                ByteFormatter.formatSpeed(currentUp),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditPortDialog(
    BuildContext context,
    WidgetRef ref, {
    required int currentPort,
    required bool allowLan,
    required bool isRunning,
    required Translations tr,
  }) {
    final controller = TextEditingController(text: currentPort.toString());
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lan_outlined, size: 20, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text(tr.editPortTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.editPortDesc,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr.mixedPortLabel,
                hintText: '7890',
                prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${allowLan ? "0.0.0.0" : "127.0.0.1"}:$currentPort'));
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tr.isZh ? "已复制代理地址" : "Proxy address copied"}: ${allowLan ? "0.0.0.0" : "127.0.0.1"}:$currentPort'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 320,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: Text(tr.copy),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(tr.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPort = int.tryParse(controller.text.trim());
              if (newPort != null && newPort > 0 && newPort <= 65535) {
                Navigator.of(dialogCtx).pop();
                if (newPort != currentPort) {
                  await ref.read(settingsProvider.notifier).updateMixedPort(newPort);
                  if (isRunning) {
                    await ref.read(coreProvider.notifier).restartCore();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isRunning
                              ? (tr.isZh ? '端口已更新为 $newPort，核心已重启生效' : 'Port updated to $newPort, core restarted')
                              : (tr.isZh ? '端口已更新为 $newPort' : 'Port updated to $newPort'),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        width: 320,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(tr.confirm),
          ),
        ],
      ),
    );
  }

  void _showQuickNodeSelectorDialog(
    BuildContext context,
    WidgetRef ref, {
    required String currentNodeName,
    required Translations tr,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setState) {
            final proxiesState = ref.watch(proxiesProvider);
            final groups = proxiesState.groups;
            final activeGroupName = proxiesState.selectedGroup ?? (groups.isNotEmpty ? groups.keys.first : null);
            final activeGroup = activeGroupName != null ? groups[activeGroupName] : null;

            final allNodesInGroup = (activeGroup?.all ?? []).map((name) {
              if (proxiesState.nodes.containsKey(name)) return proxiesState.nodes[name]!;
              if (groups.containsKey(name)) {
                final grp = groups[name]!;
                return ProxyNode(name: name, type: grp.type);
              }
              return ProxyNode(name: name, type: OutboundType.unknown);
            }).where((n) => n.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  const Icon(Icons.hub_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr.quickSelectNode,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.speed_rounded, size: 18),
                    tooltip: tr.pingAll,
                    onPressed: () {
                      ref.read(proxiesProvider.notifier).testAllInSelectedGroup();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                height: 400,
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: tr.filterNodes,
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16),
                        isDense: true,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),

                    // Selector groups tabs if multiple
                    if (proxiesState.sortedGroupNames.length > 1)
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: proxiesState.sortedGroupNames.map((gName) {
                            final isCur = gName == activeGroupName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(gName, style: const TextStyle(fontSize: 11)),
                                selected: isCur,
                                visualDensity: VisualDensity.compact,
                                onSelected: (sel) {
                                  if (sel) {
                                    ref.read(proxiesProvider.notifier).setSelectedGroup(gName);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Nodes List
                    Expanded(
                      child: allNodesInGroup.isEmpty
                          ? Center(
                              child: Text(
                                tr.noNodesFound,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.builder(
                              itemCount: allNodesInGroup.length,
                              itemBuilder: (ctx, idx) {
                                final node = allNodesInGroup[idx];
                                final isSelected = activeGroup?.current == node.name || (activeGroup == null && currentNodeName == node.name);
                                final isAuto = node.type == OutboundType.urltest || node.name.toLowerCase() == 'auto';
                                final flag = isAuto ? '⚡' : ProxyFlagHelper.getFlag(node.name);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Text(flag, style: const TextStyle(fontSize: 16)),
                                    title: Text(
                                      isAuto ? (tr.isZh ? 'Auto 自动优选' : 'Auto Failover') : node.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF10B981) : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      node.type.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (node.isTesting)
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 1.5),
                                          )
                                        else if ((node.delay ?? 0) > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: ((node.delay ?? 0) < 200 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${node.delay}ms',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: (node.delay ?? 0) < 200 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          )
                                        else if (node.delay == -1)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tr.timeout,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                                            ),
                                          ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                        ],
                                      ],
                                    ),
                                    onTap: () async {
                                      Navigator.of(dialogCtx).pop();
                                      if (activeGroupName != null) {
                                        await ref.read(proxiesProvider.notifier).selectNode(activeGroupName, node.name);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('${tr.nodeSwitchedTo}${node.name}'),
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                              width: 320,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
