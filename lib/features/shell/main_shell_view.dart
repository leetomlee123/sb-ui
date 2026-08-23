import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  final List<Widget> _pages = const [
    DashboardPage(),
    ProxiesPage(),
    ProfilesPage(),
    ConnectionsPage(),
    LogsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final coreState = ref.watch(coreProvider);
    final trafficState = ref.watch(trafficProvider);
    final profilesState = ref.watch(profilesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: Column(
        children: [
          // Top Title Bar
          const AppTitleBar(),

          // Main Center Area (Navigation Rail + Content)
          Expanded(
            child: Row(
              children: [
                // Modern Desktop Navigation Rail
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  minWidth: 76,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.speed_rounded),
                      selectedIcon: Icon(Icons.speed_rounded, color: Color(0xFF818CF8)),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.alt_route_rounded),
                      selectedIcon: Icon(Icons.alt_route_rounded, color: Color(0xFF818CF8)),
                      label: Text('Proxies'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_shared_rounded),
                      selectedIcon: Icon(Icons.folder_shared_rounded, color: Color(0xFF818CF8)),
                      label: Text('Profiles'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.compare_arrows_rounded),
                      selectedIcon: Icon(Icons.compare_arrows_rounded, color: Color(0xFF818CF8)),
                      label: Text('Connections'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.terminal_rounded),
                      selectedIcon: Icon(Icons.terminal_rounded, color: Color(0xFF818CF8)),
                      label: Text('Logs'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_rounded),
                      selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF818CF8)),
                      label: Text('Settings'),
                    ),
                  ],
                ),

                const VerticalDivider(thickness: 1, width: 1),

                // Active Page Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Compact Status Bar
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Active Profile & Mode
                Row(
                  children: [
                    Icon(
                      coreState.isRunning ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: coreState.isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      profilesState.activeProfile?.name ?? 'No Profile',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        settings.routingMode.displayName.toUpperCase(),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                      ),
                    ),
                  ],
                ),

                // Right: Speed Pill
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 2),
                    Text(
                      ByteFormatter.formatSpeed(trafficState.currentDown),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF06B6D4)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF6366F1)),
                    const SizedBox(width: 2),
                    Text(
                      ByteFormatter.formatSpeed(trafficState.currentUp),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
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
}
