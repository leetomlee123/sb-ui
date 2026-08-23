import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(coreProvider);
    final trafficState = ref.watch(trafficProvider);
    final settings = ref.watch(settingsProvider);

    final isRunning = coreState.isRunning;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Core Status Switch Hero Card & Mode Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Core Switch Hero Card
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        // Big Toggle Button
                        InkWell(
                          onTap: () {
                            ref.read(coreProvider.notifier).toggleCore();
                          },
                          borderRadius: BorderRadius.circular(50),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isRunning
                                  ? const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF475569), Color(0xFF334155)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: isRunning
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: const Icon(
                              Icons.power_settings_new_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Status info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRunning ? 'CONNECTED' : 'DISCONNECTED',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isRunning
                                    ? 'Active Profile: ${coreState.activeProfileName ?? "Default"}'
                                    : (coreState.errorMessage ?? 'Click the power button to connect'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: coreState.errorMessage != null
                                      ? const Color(0xFFEF4444)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isRunning) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Uptime: ${ByteFormatter.formatDuration(coreState.uptime)}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Routing Mode & Quick TUN / System Proxy Toggles
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Routing Mode',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<RoutingMode>(
                          segments: const [
                            ButtonSegment(value: RoutingMode.rule, label: Text('Rule', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: RoutingMode.global, label: Text('Global', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: RoutingMode.direct, label: Text('Direct', style: TextStyle(fontSize: 11))),
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
                        Row(
                          children: [
                            // TUN badge
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: settings.tunModeEnabled
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: settings.tunModeEnabled ? const Color(0xFF6366F1) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.vpn_key_rounded,
                                      size: 14,
                                      color: settings.tunModeEnabled ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'TUN Mode',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: settings.tunModeEnabled ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // System proxy badge
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: settings.systemProxyEnabled
                                      ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: settings.systemProxyEnabled ? const Color(0xFF06B6D4) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.public_rounded,
                                      size: 14,
                                      color: settings.systemProxyEnabled ? const Color(0xFF06B6D4) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'System Proxy',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: settings.systemProxyEnabled ? const Color(0xFF06B6D4) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Speed Statistics Grid (Download, Upload, Total Down, Total Up)
          Row(
            children: [
              _buildStatCard(
                context,
                title: 'Download Speed',
                value: ByteFormatter.formatSpeed(trafficState.currentDown),
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF06B6D4),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                title: 'Upload Speed',
                value: ByteFormatter.formatSpeed(trafficState.currentUp),
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                title: 'Total Download',
                value: ByteFormatter.formatBytes(trafficState.totalDown),
                icon: Icons.cloud_download_outlined,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                context,
                title: 'Total Upload',
                value: ByteFormatter.formatBytes(trafficState.totalUp),
                icon: Icons.cloud_upload_outlined,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Real-time Traffic Graph Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Traffic Chart',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          _buildLegendItem(const Color(0xFF06B6D4), 'Download'),
                          const SizedBox(width: 16),
                          _buildLegendItem(const Color(0xFF6366F1), 'Upload'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 180,
                    child: trafficState.history.isEmpty
                        ? const Center(
                            child: Text(
                              'Traffic data will appear here once connected',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
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
                                // Download curve
                                LineChartBarData(
                                  spots: trafficState.history
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.down.toDouble() / 1024))
                                      .toList(),
                                  isCurved: true,
                                  color: const Color(0xFF06B6D4),
                                  barWidth: 2.5,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                                  ),
                                ),
                                // Upload curve
                                LineChartBarData(
                                  spots: trafficState.history
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(e.key.toDouble(), e.value.up.toDouble() / 1024))
                                      .toList(),
                                  isCurved: true,
                                  color: const Color(0xFF6366F1),
                                  barWidth: 2,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
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
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
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
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
