import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/i18n/translations.dart';
import '../../core/models/connection_info.dart';
import '../../core/providers/connections_provider.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/traffic_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../shared/widgets/double_bezel_card.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  final bool isVisible;
  const ConnectionsPage({super.key, this.isVisible = true});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  int _selectedTab = 0; // 0: Active Connections, 1: Traffic Analytics
  int _refreshIntervalSeconds = 5; // 0: Paused, 5: 5s, 10: 10s
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isVisible) {
        _startPolling();
      }
    });
  }

  @override
  void didUpdateWidget(ConnectionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _startPolling();
      } else {
        _stopPolling();
      }
    }
  }

  void _startPolling() {
    _stopPolling();
    if (!widget.isVisible || _refreshIntervalSeconds <= 0) return;

    ref.read(connectionsProvider.notifier).refresh(
      computeAnalytics: _selectedTab == 1,
    );

    _pollTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (_) {
      if (mounted && widget.isVisible && _refreshIntervalSeconds > 0) {
        ref.read(connectionsProvider.notifier).refresh(
          silent: true,
          computeAnalytics: _selectedTab == 1,
        );
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final connState = ref.watch(connectionsProvider);
    final totalDown = ref.watch(trafficProvider.select((s) => s.totalDown));
    final totalUp = ref.watch(trafficProvider.select((s) => s.totalUp));
    final tr = ref.watch(translationsProvider);

    if (!isRunning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded, size: 64, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              tr.coreOfflineTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              tr.coreOfflineHint,
              style: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final connections = connState.filteredConnections;
    final effectiveTotalDown = connState.downloadTotal > 0 ? connState.downloadTotal : totalDown;
    final effectiveTotalUp = connState.uploadTotal > 0 ? connState.uploadTotal : totalUp;
    final combinedTotal = effectiveTotalDown + effectiveTotalUp;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Tab Selector, Stats, Search, Close All
          Row(
            children: [
              // Segmented Tab Switcher
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.hub_outlined, size: 16),
                    label: Text(
                      '${tr.connectionsTab} (${connState.connections.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: Text(
                      tr.analyticsTab,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (val) {
                  setState(() => _selectedTab = val.first);
                  if (_selectedTab == 1) {
                    ref.read(connectionsProvider.notifier).computeAnalyticsNow();
                  }
                  _startPolling();
                },
              ),

              const SizedBox(width: 12),

              // Auto-refresh interval selector
              PopupMenuButton<int>(
                tooltip: tr.isZh ? '自动刷新频率' : 'Auto-refresh interval',
                initialValue: _refreshIntervalSeconds,
                onSelected: (val) {
                  setState(() => _refreshIntervalSeconds = val);
                  _startPolling();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _refreshIntervalSeconds > 0
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : const Color(0xFF1E293B).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _refreshIntervalSeconds > 0
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _refreshIntervalSeconds > 0 ? Icons.sync_rounded : Icons.pause_circle_outline_rounded,
                        size: 14,
                        color: _refreshIntervalSeconds > 0 ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _refreshIntervalSeconds > 0 ? '${_refreshIntervalSeconds}s 刷新' : (tr.isZh ? '已暂停' : 'Paused'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _refreshIntervalSeconds > 0 ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 0, child: Text(tr.isZh ? '⏸️ 暂停自动刷新' : '⏸️ Pause auto-refresh')),
                  PopupMenuItem(value: 5, child: Text(tr.isZh ? '⚡ 5 秒低频刷新 (推荐)' : '⚡ 5s (Recommended)')),
                  PopupMenuItem(value: 10, child: Text(tr.isZh ? '🌿 10 秒极低功耗刷新' : '🌿 10s Low power')),
                ],
              ),

              const SizedBox(width: 6),

              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: tr.refresh,
                onPressed: () {
                  ref.read(connectionsProvider.notifier).refresh(
                    computeAnalytics: _selectedTab == 1,
                  );
                },
              ),

              const Spacer(),

              if (_selectedTab == 0) ...[
                // Search field
                SizedBox(
                  width: 220,
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: tr.searchConnections,
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (val) {
                      ref.read(connectionsProvider.notifier).setSearchQuery(val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: connState.connections.isEmpty
                      ? null
                      : () {
                          ref.read(connectionsProvider.notifier).closeAllConnections();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 15),
                  label: Text(tr.closeAll, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 0
                ? _buildConnectionsListView(connections, tr)
                : _buildAnalyticsView(
                    connState: connState,
                    totalDown: totalDown,
                    totalUp: totalUp,
                    combinedTotal: combinedTotal,
                    tr: tr,
                  ),
          ),
        ],
      ),
    );
  }

  // --- Tab 0: Active Connections List ---
  Widget _buildConnectionsListView(List<ActiveConnection> connections, Translations tr) {
    if (connections.isEmpty) {
      return Center(
        child: Text(
          tr.noConnectionsMatching,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return DoubleBezelCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          itemCount: connections.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          itemBuilder: (context, index) {
            final conn = connections[index];
            final destination = conn.metadata.host.isNotEmpty
                ? conn.metadata.host
                : '${conn.metadata.destinationIP}:${conn.metadata.destinationPort}';
            final ruleName = conn.rule.isEmpty ? 'Match' : conn.rule;
            final fullRule = conn.rulePayload.isNotEmpty
                ? '$ruleName (${conn.rulePayload})'
                : ruleName;
            final processName = (conn.metadata.processPath != null && conn.metadata.processPath!.isNotEmpty)
                ? p.basename(conn.metadata.processPath!)
                : null;

            return ListTile(
              dense: true,
              mouseCursor: SystemMouseCursors.click,
              onTap: () => _showConnectionDetailsDialog(context, conn, tr),
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Text(
                  conn.metadata.network.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      destination,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (processName != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        processName,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    // Matched Rule: constrained with ellipsis and tooltip for arbitrarily long rules
                    Flexible(
                      flex: 3,
                      child: Tooltip(
                        message: '${tr.rulePrefix}$fullRule\n${tr.isZh ? "点击查看详情" : "Click for details"}',
                        waitDuration: const Duration(milliseconds: 250),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rule_rounded, size: 11, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${tr.rulePrefix}$fullRule',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (conn.chains.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      // Outbound Chains: constrained with ellipsis and tooltip
                      Flexible(
                        flex: 4,
                        child: Tooltip(
                          message: '${tr.routePrefix}${conn.chains.join(" → ")}',
                          waitDuration: const Duration(milliseconds: 250),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 11, color: Color(0xFF818CF8)),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  conn.chains.join(" → "),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF818CF8)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '↓ ${ByteFormatter.formatBytes(conn.download)}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                      Text(
                        '↑ ${ByteFormatter.formatBytes(conn.upload)}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: tr.killSession,
                    hoverColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    onPressed: () {
                      ref.read(connectionsProvider.notifier).closeConnection(conn.id);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showConnectionDetailsDialog(
    BuildContext context,
    ActiveConnection conn,
    Translations tr,
  ) {
    final destination = conn.metadata.host.isNotEmpty
        ? conn.metadata.host
        : '${conn.metadata.destinationIP}:${conn.metadata.destinationPort}';
    final ruleName = conn.rule.isEmpty ? 'Match' : conn.rule;
    final fullRule = conn.rulePayload.isNotEmpty
        ? '$ruleName (${conn.rulePayload})'
        : ruleName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duration = DateTime.now().difference(conn.start);
    final durationStr = duration.inMinutes > 0
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : '${duration.inSeconds}s';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0E1424) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Text(
                conn.metadata.network.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr.isZh ? '连接详情' : 'Connection Details',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Matched Rule Section (Prominently shows full rule with selectable text & copy button)
                _buildDetailSection(
                  context,
                  title: tr.isZh ? '命中规则' : 'Matched Rule',
                  icon: Icons.rule_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF060910) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SelectableText(
                                fullRule,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: tr.isZh ? '复制规则' : 'Copy Rule',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: fullRule));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(tr.isZh ? '已复制命中规则' : 'Rule copied'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (conn.rulePayload.isNotEmpty && conn.rule.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '类型: ${conn.rule}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '匹配值: ${conn.rulePayload}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Outbound Chains
                if (conn.chains.isNotEmpty) ...[
                  _buildDetailSection(
                    context,
                    title: tr.isZh ? '节点链路' : 'Routing Chains',
                    icon: Icons.alt_route_rounded,
                    iconColor: const Color(0xFF818CF8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (int i = 0; i < conn.chains.length; i++) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF818CF8).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              conn.chains[i],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF818CF8),
                              ),
                            ),
                          ),
                          if (i < conn.chains.length - 1)
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF818CF8)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Network Endpoints
                _buildDetailSection(
                  context,
                  title: tr.isZh ? '网络端点' : 'Network Endpoints',
                  icon: Icons.lan_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        context,
                        label: tr.isZh ? '目标主机' : 'Host',
                        value: destination,
                        canCopy: true,
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        context,
                        label: tr.isZh ? '目标 IP:端口' : 'Dest IP:Port',
                        value: '${conn.metadata.destinationIP}:${conn.metadata.destinationPort}',
                        canCopy: true,
                      ),
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        context,
                        label: tr.isZh ? '源地址' : 'Source IP:Port',
                        value: '${conn.metadata.sourceIP}:${conn.metadata.sourcePort}',
                      ),
                      if (conn.metadata.processPath != null && conn.metadata.processPath!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow(
                          context,
                          label: tr.isZh ? '发起进程' : 'Process',
                          value: conn.metadata.processPath!,
                          canCopy: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Traffic & Timing
                _buildDetailSection(
                  context,
                  title: tr.isZh ? '流量与耗时' : 'Traffic & Timing',
                  icon: Icons.data_usage_rounded,
                  iconColor: const Color(0xFF10B981),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatMiniBox(
                          label: tr.isZh ? '下载流量' : 'Download',
                          value: ByteFormatter.formatBytes(conn.download),
                          color: const Color(0xFF38BDF8),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatMiniBox(
                          label: tr.isZh ? '上传流量' : 'Upload',
                          value: ByteFormatter.formatBytes(conn.upload),
                          color: const Color(0xFF818CF8),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatMiniBox(
                          label: tr.isZh ? '持续时间' : 'Duration',
                          value: durationStr,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFF43F5E)),
            label: Text(
              tr.killSession,
              style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF43F5E), width: 1),
            ),
            onPressed: () {
              ref.read(connectionsProvider.notifier).closeConnection(conn.id);
              Navigator.of(ctx).pop();
            },
          ),
          ElevatedButton(
            child: Text(tr.isZh ? '关闭' : 'Close'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    bool canCopy = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500),
            ),
          ),
          if (canCopy)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '复制',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatMiniBox({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Traffic Analytics View ---
  Widget _buildAnalyticsView({
    required ConnectionsState connState,
    required int totalDown,
    required int totalUp,
    required int combinedTotal,
    required Translations tr,
  }) {
    final topDomains = connState.topDomains;
    final topOutbounds = connState.topOutbounds;
    final protocols = connState.protocolBreakdown;

    final maxDomainTotal = topDomains.isNotEmpty && topDomains.first.total > 0
        ? topDomains.first.total
        : 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Total Traffic Hero Bento Row
          Row(
            children: [
              _buildStatCard(
                title: tr.totalTraffic,
                value: ByteFormatter.formatBytes(combinedTotal),
                subtitle: tr.isZh ? '累计总流量' : 'Combined Bandwidth',
                icon: Icons.data_usage_rounded,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                title: tr.totalDownload,
                value: ByteFormatter.formatBytes(totalDown),
                subtitle: tr.isZh ? '下行流量' : 'Inbound Traffic',
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                title: tr.totalUpload,
                value: ByteFormatter.formatBytes(totalUp),
                subtitle: tr.isZh ? '上行流量' : 'Outbound Traffic',
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFF818CF8),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                title: tr.isZh ? '活动会话数' : 'Active Sessions',
                value: '${connState.connections.length}',
                subtitle: tr.isZh ? '当前网络连接' : 'Live Sockets',
                icon: Icons.sensors_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Main Analytics Grid (Top Domains + Outbound Distribution)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Domain Traffic Ranking
              Expanded(
                flex: 6,
                child: DoubleBezelCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.leaderboard_rounded, size: 16, color: Color(0xFF818CF8)),
                          const SizedBox(width: 8),
                          Text(
                            tr.domainRanking,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (topDomains.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              tr.noTrafficData,
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: topDomains.take(10).length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = topDomains[index];
                            final progress = (item.total / maxDomainTotal).clamp(0.05, 1.0);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: index < 3
                                            ? const Color(0xFF818CF8).withValues(alpha: 0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: index < 3 ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.domain,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ByteFormatter.formatBytes(item.total),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Stack(
                                  children: [
                                    Container(
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF334155).withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Right: Outbound & Protocol Breakdown
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Outbound Distribution
                    DoubleBezelCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 8),
                              Text(
                                tr.outboundDistribution,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (topOutbounds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  tr.noTrafficData,
                                  style: const TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          else
                            ...topOutbounds.take(5).map((ob) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        ob.outbound,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      ByteFormatter.formatBytes(ob.total),
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Protocol Breakdown
                    DoubleBezelCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.network_check_rounded, size: 16, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Text(
                                tr.protocolDistribution,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (protocols.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  tr.noTrafficData,
                                  style: const TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: protocols.entries.map((e) {
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF151E33),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.key,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ByteFormatter.formatBytes(e.value),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: DoubleBezelCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF818CF8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
