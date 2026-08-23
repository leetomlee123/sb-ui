import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/proxies_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../shared/widgets/double_bezel_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(coreProvider);
    final trafficState = ref.watch(trafficProvider);
    final settings = ref.watch(settingsProvider);
    final proxiesState = ref.watch(proxiesProvider);

    final isRunning = coreState.isRunning;

    // Get current active proxy node
    final activeGroup = proxiesState.groups['Proxy'];
    final currentNodeName = activeGroup?.current ?? 'Auto';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Hero Bento Grid (Power Hub + Mode Controller)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Tile: Core Power Station
              Expanded(
                flex: 5,
                child: DoubleBezelCard(
                  padding: const EdgeInsets.all(24),
                  isSelected: isRunning,
                  child: Row(
                    children: [
                      // Concentric Tactile Switch Button
                      GestureDetector(
                        onTap: () {
                          ref.read(coreProvider.notifier).toggleCore();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRunning
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF1E293B).withValues(alpha: 0.5),
                            border: Border.all(
                              color: isRunning
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF334155),
                              width: 2,
                            ),
                            boxShadow: isRunning
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isRunning
                                    ? const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFF334155), Color(0xFF1E293B)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                              ),
                              child: Icon(
                                Icons.power_settings_new_rounded,
                                size: 32,
                                color: isRunning ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Core Status Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isRunning ? 'CONNECTED' : 'DISCONNECTED',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isRunning)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isRunning
                                  ? 'Profile: ${coreState.activeProfileName ?? "Default"}'
                                  : (coreState.errorMessage ?? 'Click the power button to start sing-box'),
                              style: TextStyle(
                                fontSize: 13,
                                color: coreState.errorMessage != null
                                    ? const Color(0xFFF43F5E)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.av_timer_rounded,
                                  size: 14,
                                  color: isRunning ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isRunning
                                      ? 'Uptime ${ByteFormatter.formatDuration(coreState.uptime)}'
                                      : 'Standby mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: isRunning ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Side Tile: Routing Mode & Toggles
              Expanded(
                flex: 4,
                child: DoubleBezelCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROUTING POLICY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<RoutingMode>(
                        segments: const [
                          ButtonSegment(value: RoutingMode.rule, label: Text('Rule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ButtonSegment(value: RoutingMode.global, label: Text('Global', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ButtonSegment(value: RoutingMode.direct, label: Text('Direct', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                        selected: {settings.routingMode},
                        onSelectionChanged: (set) {
                          final newMode = set.first;
                          ref.read(settingsProvider.notifier).setRoutingMode(newMode);
                          if (isRunning) {
                            ref.read(coreProvider.notifier).restartCore();
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      // Pill Indicators
                      Row(
                        children: [
                          Expanded(
                            child: _buildFeaturePill(
                              context,
                              title: 'TUN Mode',
                              isActive: settings.tunModeEnabled,
                              icon: Icons.vpn_key_rounded,
                              activeColor: const Color(0xFF6366F1),
                              onTap: () {
                                ref.read(settingsProvider.notifier).toggleTunMode(!settings.tunModeEnabled);
                                if (isRunning) ref.read(coreProvider.notifier).restartCore();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFeaturePill(
                              context,
                              title: 'System Proxy',
                              isActive: settings.systemProxyEnabled,
                              icon: Icons.public_rounded,
                              activeColor: const Color(0xFF38BDF8),
                              onTap: () {
                                ref.read(settingsProvider.notifier).toggleSystemProxy(!settings.systemProxyEnabled);
                                if (isRunning) ref.read(coreProvider.notifier).restartCore();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 2: Metrics Bento Strip (Down/Up Speeds + Totals + Current Node)
          Row(
            children: [
              _buildMetricCard(
                context,
                title: 'DOWNLOAD',
                value: ByteFormatter.formatSpeed(trafficState.currentDown),
                total: 'Total: ${ByteFormatter.formatBytes(trafficState.totalDown)}',
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 12),
              _buildMetricCard(
                context,
                title: 'UPLOAD',
                value: ByteFormatter.formatSpeed(trafficState.currentUp),
                total: 'Total: ${ByteFormatter.formatBytes(trafficState.totalUp)}',
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFF818CF8),
              ),
              const SizedBox(width: 12),
              _buildActiveNodeCard(
                context,
                nodeName: currentNodeName,
                isRunning: isRunning,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 3: Telemetry Stream LineChart (Obsidian Glow Graph)
          DoubleBezelCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'TELEMETRY STREAM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151E33),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildLegendPill(const Color(0xFF38BDF8), 'Down ${ByteFormatter.formatSpeed(trafficState.currentDown)}'),
                        const SizedBox(width: 12),
                        _buildLegendPill(const Color(0xFF818CF8), 'Up ${ByteFormatter.formatSpeed(trafficState.currentUp)}'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 190,
                  child: trafficState.history.isEmpty
                      ? Center(
                          child: Text(
                            'Telemetry data will populate when connection is established',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: const FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              // Download curve (Sky Cyan)
                              LineChartBarData(
                                spots: trafficState.history
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(e.key.toDouble(), e.value.down.toDouble() / 1024))
                                    .toList(),
                                isCurved: true,
                                curveSmoothness: 0.35,
                                color: const Color(0xFF38BDF8),
                                barWidth: 2.5,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                ),
                              ),
                              // Upload curve (Electric Indigo)
                              LineChartBarData(
                                spots: trafficState.history
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(e.key.toDouble(), e.value.up.toDouble() / 1024))
                                    .toList(),
                                isCurved: true,
                                curveSmoothness: 0.35,
                                color: const Color(0xFF818CF8),
                                barWidth: 2,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF818CF8).withValues(alpha: 0.08),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String total,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: DoubleBezelCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveNodeCard(
    BuildContext context, {
    required String nodeName,
    required bool isRunning,
  }) {
    return Expanded(
      child: DoubleBezelCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE OUTBOUND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isRunning ? nodeName : 'Not Connected',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRunning ? 'Primary Group: Proxy' : 'Standby',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(
    BuildContext context, {
    required String title,
    required bool isActive,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isActive ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? activeColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendPill(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
