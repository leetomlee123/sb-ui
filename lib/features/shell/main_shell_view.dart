import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';
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
                        DashboardPage(isVisible: _selectedIndex == 0),
                        const ProxiesPage(),
                        const ProfilesPage(),
                        ConnectionsPage(isVisible: _selectedIndex == 3),
                        LogsPage(isVisible: _selectedIndex == 4),
                        const SettingsPage(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Telemetry Status Ribbon (Isolated ConsumerWidget to eliminate parent rebuilds)
          const _BottomStatusRibbon(),
        ],
      ),
    );
  }
}

class _BottomStatusRibbon extends ConsumerWidget {
  const _BottomStatusRibbon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final currentDown = ref.watch(trafficProvider.select((s) => s.currentDown));
    final currentUp = ref.watch(trafficProvider.select((s) => s.currentUp));
    final activeProfileName = ref.watch(profilesProvider.select((s) => s.activeProfile?.name));
    final routingMode = ref.watch(settingsProvider.select((s) => s.routingMode));
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
          // Left: Connection State & Active Profile
          Row(
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
              Text(
                activeProfileName ?? tr.noActiveProfile,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
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
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF818CF8)),
                ),
              ),
            ],
          ),

          // Right: Real-time Speeds
          Row(
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
}
