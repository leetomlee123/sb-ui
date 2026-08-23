import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/proxies_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../shared/widgets/double_bezel_card.dart';

class DashboardPage extends ConsumerWidget {
  final bool isVisible;
  const DashboardPage({super.key, this.isVisible = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select individual fields instead of watching the whole CoreState object:
    // the uptime timer rewrites the state every second, which would otherwise
    // rebuild this entire page (chart included) even while hidden.
    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final activeProfileName = ref.watch(coreProvider.select((s) => s.activeProfileName));
    final errorMessage = ref.watch(coreProvider.select((s) => s.errorMessage));
    final settings = ref.watch(settingsProvider);
    final tr = ref.watch(translationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Hero Bento Grid (Power Hub + Mode Controller)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero Tile: Core Power Station
                Expanded(
                  flex: 5,
                  child: DoubleBezelCard(
                    padding: const EdgeInsets.all(22),
                    isSelected: isRunning,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                  isRunning ? tr.connected : tr.disconnected,
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
                                  ? '${tr.isZh ? "当前配置" : "Profile"}: ${activeProfileName ?? (tr.isZh ? "默认配置" : "Default")}'
                                  : (errorMessage ?? tr.clickToConnect),
                              style: TextStyle(
                                fontSize: 13,
                                color: errorMessage != null
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
                                Expanded(
                                  child: _UptimeText(
                                    isRunning: isRunning,
                                    uptimeLabel: tr.uptime,
                                    standbyLabel: tr.standby,
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
                      Text(
                        tr.routingPolicy,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<RoutingMode>(
                        segments: [
                          ButtonSegment(value: RoutingMode.rule, label: Text(tr.modeRule, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ButtonSegment(value: RoutingMode.global, label: Text(tr.modeGlobal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ButtonSegment(value: RoutingMode.direct, label: Text(tr.modeDirect, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
                              title: tr.tunMode,
                              isActive: settings.tunModeEnabled,
                              icon: Icons.vpn_key_rounded,
                              activeColor: const Color(0xFF6366F1),
                              onTap: () async {
                                final next = !settings.tunModeEnabled;
                                await ref.read(settingsProvider.notifier).toggleTunMode(next);
                                if (isRunning) {
                                  await ref.read(coreProvider.notifier).restartCore();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFeaturePill(
                              context,
                              title: tr.systemProxy,
                              isActive: settings.systemProxyEnabled,
                              icon: Icons.lan_rounded,
                              activeColor: const Color(0xFF10B981),
                              onTap: () async {
                                final next = !settings.systemProxyEnabled;
                                await ref.read(settingsProvider.notifier).toggleSystemProxy(next);
                                if (isRunning) {
                                  await ref.read(coreProvider.notifier).restartCore();
                                }
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
        ),

          const SizedBox(height: 16),

          // Row 2: Metrics Bento Strip (Down/Up Speeds + Totals + Combined Total + Current Node)
          const _SpeedMetricsStrip(),

          const SizedBox(height: 16),

          // Row 3: Telemetry Stream LineChart (Obsidian Glow Graph)
          _TelemetryGraphCard(visible: isVisible),
        ],
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
}

/// Isolated so the once-per-second uptime tick only rebuilds this tiny Text,
/// not the whole hero card / page.
class _UptimeText extends ConsumerWidget {
  final bool isRunning;
  final String uptimeLabel;
  final String standbyLabel;

  const _UptimeText({
    required this.isRunning,
    required this.uptimeLabel,
    required this.standbyLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uptime = isRunning ? ref.watch(coreProvider.select((s) => s.uptime)) : Duration.zero;
    return Text(
      isRunning ? '$uptimeLabel ${ByteFormatter.formatDuration(uptime)}' : standbyLabel,
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'monospace',
        color: isRunning ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
      ),
    );
  }
}

class _SpeedMetricsStrip extends ConsumerWidget {
  const _SpeedMetricsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final currentDown = ref.watch(trafficProvider.select((s) => s.currentDown));
    final currentUp = ref.watch(trafficProvider.select((s) => s.currentUp));
    final totalDown = ref.watch(trafficProvider.select((s) => s.totalDown));
    final totalUp = ref.watch(trafficProvider.select((s) => s.totalUp));
    final totalCombined = totalDown + totalUp;

    // Get current active proxy node
    final currentNodeName = ref.watch(proxiesProvider.select((s) {
      final grp = s.groups['Proxy'] ?? (s.groups.isNotEmpty ? s.groups.values.first : null);
      return (grp != null && grp.current.isNotEmpty) ? grp.current : 'Auto';
    }));
    final tr = ref.watch(translationsProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricCard(
            context,
            title: tr.downloadSpeed,
            value: ByteFormatter.formatSpeed(currentDown),
            total: '${tr.totalDownload}: ${ByteFormatter.formatBytes(totalDown)}',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            context,
            title: tr.uploadSpeed,
            value: ByteFormatter.formatSpeed(currentUp),
            total: '${tr.totalUpload}: ${ByteFormatter.formatBytes(totalUp)}',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFF818CF8),
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            context,
            title: tr.totalTraffic,
            value: ByteFormatter.formatBytes(totalCombined),
            total: isRunning ? (tr.isZh ? '实时累计流量' : 'Session Total') : tr.standby,
            icon: Icons.data_usage_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildActiveNodeCard(
            context,
            title: tr.activeOutbound,
            nodeName: currentNodeName,
            isRunning: isRunning,
            notConnectedStr: tr.notConnected,
            routingStatus: isRunning ? (tr.isZh ? '直连路由链' : 'Direct Routing') : tr.standby,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                      fontSize: 15,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    required String title,
    required String nodeName,
    required bool isRunning,
    required String notConnectedStr,
    required String routingStatus,
  }) {
    return Expanded(
      child: DoubleBezelCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hub_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                    isRunning ? nodeName : notConnectedStr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routingStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
    );
  }
}

class _TelemetryGraphCard extends ConsumerWidget {
  final bool visible;
  const _TelemetryGraphCard({required this.visible});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip the 1 Hz traffic watch entirely while the dashboard is hidden
    // behind the IndexedStack: no FlSpot mapping, no chart repaint.
    final trafficState = visible ? ref.watch(trafficProvider) : null;
    final tr = ref.watch(translationsProvider);
    final currentDown = trafficState?.currentDown ?? 0;
    final currentUp = trafficState?.currentUp ?? 0;
    final history = trafficState?.history ?? const [];

    return DoubleBezelCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    tr.telemetryStream,
                    style: const TextStyle(
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tr.isZh ? '90s 时间线' : '90s Timeline',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151E33),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tr.live,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildLegendPill(const Color(0xFF38BDF8), '↓ ${ByteFormatter.formatSpeed(currentDown)}'),
                  const SizedBox(width: 12),
                  _buildLegendPill(const Color(0xFF818CF8), '↑ ${ByteFormatter.formatSpeed(currentUp)}'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 205,
            child: !visible || history.isEmpty
                ? Center(
                    child: Text(
                      tr.telemetryEmptyHint,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  )
                : RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minX: 0,
                        maxX: math.max(30.0, (history.length - 1).toDouble()),
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 15,
                              getTitlesWidget: (value, meta) {
                                final total = history.length;
                                final valInt = value.toInt();
                                final diff = (total - 1 - valInt).abs();
                                Widget child = const SizedBox.shrink();

                                if (valInt == total - 1) {
                                  child = Text(
                                    tr.isZh ? '实时' : 'Now',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                } else if (diff == 30 || diff == 60 || diff == 90) {
                                  child = Text(
                                    '${diff}s',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  );
                                }

                                return SideTitleWidget(
                                  meta: meta,
                                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                                    meta,
                                    distanceFromEdge: 6,
                                  ),
                                  child: child,
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // Download curve (Sky Cyan)
                          LineChartBarData(
                            spots: history
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
                            spots: history
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
                      duration: Duration.zero,
                    ),
                  ),
          ),
        ],
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
