import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/proxy_node.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/proxies_provider.dart';
import '../../core/utils/proxy_flag_helper.dart';
import '../../shared/widgets/double_bezel_card.dart';

class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(proxiesProvider.notifier).fetchProxies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(coreProvider.select((s) => s.isRunning));
    final proxiesState = ref.watch(proxiesProvider);
    final tr = ref.watch(translationsProvider);

    final groups = proxiesState.groups;
    final selectedGroupName = proxiesState.selectedGroup;

    if (!isRunning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_off_rounded, size: 64, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
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

    if (proxiesState.isLoading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeGroup = selectedGroupName != null && groups.containsKey(selectedGroupName)
        ? groups[selectedGroupName]
        : null;

    final filteredNodes = proxiesState.filteredNodes;
    final autoGroup = groups['auto'] ?? groups['Auto'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Strategy Groups Row & Quick Actions
          Row(
            children: [
              // Strategy Groups selector chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: proxiesState.sortedGroupNames.map((groupName) {
                      final isSelected = groupName == selectedGroupName;
                      final grp = groups[groupName];
                      final isAutoType = grp?.type == OutboundType.urltest;
                      final typeLabel = grp?.type == OutboundType.urltest
                          ? 'URLTest'
                          : (grp?.type == OutboundType.fallback
                              ? 'Fallback'
                              : (grp?.type == OutboundType.loadbalance ? 'LoadBalance' : 'Selector'));
                      final currentTarget = grp?.current ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: isAutoType
                              ? const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF59E0B))
                              : const Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFF818CF8)),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                groupName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isAutoType
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                      : const Color(0xFF818CF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isAutoType ? const Color(0xFFF59E0B) : const Color(0xFF818CF8),
                                  ),
                                ),
                              ),
                              if (currentTarget.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  ':: $currentTarget',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(proxiesProvider.notifier).setSelectedGroup(groupName);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Speed Test Button / Stop Test Button
              if (proxiesState.isTestingAll)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(proxiesProvider.notifier).stopTesting();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr.testStopped),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.stop_circle_rounded, size: 16, color: Colors.white),
                  label: Text(
                    tr.stopPing,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(proxiesProvider.notifier).testAllInSelectedGroup();
                  },
                  icon: const Icon(Icons.speed_rounded, size: 15),
                  label: Text(
                    tr.pingAll,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),

              const SizedBox(width: 6),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: tr.refresh,
                onPressed: () {
                  ref.read(proxiesProvider.notifier).fetchProxies();
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Sub-Toolbar: Group Info Badge & Filtering Controls (Search, Hide Unavailable, Sort)
          Row(
            children: [
              // Active Group Status Indicator badge
              if (activeGroup != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          activeGroup.type == OutboundType.urltest ? Icons.bolt_rounded : Icons.alt_route_rounded,
                          size: 14,
                          color: activeGroup.type == OutboundType.urltest ? const Color(0xFFF59E0B) : const Color(0xFF818CF8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${activeGroup.name}: ',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                        Flexible(
                          child: Text(
                            activeGroup.current,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (activeGroup.type == OutboundType.urltest) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '⚡ (自动优选)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          '(${filteredNodes.length}/${activeGroup.all.length} 节点)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 12),

              // Delete Unavailable Nodes Button
              OutlinedButton.icon(
                onPressed: () async {
                  final unavailableCount = proxiesState.nodes.values
                      .where((n) => n.delay != null && n.delay! <= 0)
                      .length;

                  if (unavailableCount == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr.noUnavailableNodesFound),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tr.deleteUnavailableNodes),
                      content: Text(
                        tr.isZh
                            ? '当前共检测到 $unavailableCount 个不可用（超时）节点。\n确定要从当前配置文件中彻底删除这些节点吗？'
                            : 'Found $unavailableCount unavailable (timeout) nodes.\nDelete them permanently from config?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(tr.cancel),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(tr.isZh ? '确认删除' : 'Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    final deleted = await ref.read(proxiesProvider.notifier).removeUnavailableNodes();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr.deletedUnavailableNodesCount(deleted)),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: Color(0xFFEF4444)),
                label: Text(
                  tr.deleteUnavailableNodes,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),

              const SizedBox(width: 8),

              // Sort Mode Menu
              PopupMenuButton<ProxySortMode>(
                tooltip: '排序方式',
                initialValue: proxiesState.sortMode,
                onSelected: (mode) {
                  ref.read(proxiesProvider.notifier).setSortMode(mode);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: ProxySortMode.defaultOrder,
                    child: Row(
                      children: [
                        const Icon(Icons.sort_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text(tr.sortDefault),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ProxySortMode.delayAsc,
                    child: Row(
                      children: [
                        const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(tr.sortDelayAsc),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: ProxySortMode.nameAsc,
                    child: Row(
                      children: [
                        const Icon(Icons.sort_by_alpha_rounded, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Text(tr.sortNameAsc),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        proxiesState.sortMode == ProxySortMode.delayAsc
                            ? Icons.speed_rounded
                            : (proxiesState.sortMode == ProxySortMode.nameAsc ? Icons.sort_by_alpha_rounded : Icons.sort_rounded),
                        size: 15,
                        color: proxiesState.sortMode != ProxySortMode.defaultOrder ? const Color(0xFF818CF8) : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        proxiesState.sortMode == ProxySortMode.delayAsc
                            ? tr.sortDelayAsc
                            : (proxiesState.sortMode == ProxySortMode.nameAsc ? tr.sortNameAsc : tr.sortDefault),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Search Filter Field
              SizedBox(
                width: 170,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: tr.filterNodes,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(proxiesProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Nodes Grid (Asymmetrical Double-Bezel Cards)
          Expanded(
            child: filteredNodes.isEmpty
                ? Center(
                    child: Text(
                      tr.noNodesFound,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 104,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: filteredNodes.length,
                    itemBuilder: (context, index) {
                      final node = filteredNodes[index];
                      final isAutoNode = node.type == OutboundType.urltest || node.name.toLowerCase() == 'auto';
                      
                      // Active check: in currently selected strategy group
                      final isSelectedInGroup = activeGroup?.current == node.name;

                      return DoubleBezelCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        isSelected: isSelectedInGroup,
                        onTap: () {
                          ref.read(proxiesProvider.notifier).selectNode(
                            selectedGroupName ?? 'Proxy',
                            node.name,
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top: Node Name + Radio Circle
                            Row(
                              children: [
                                if (isAutoNode)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(
                                      ProxyFlagHelper.getFlag(node.name),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAutoNode ? (tr.isZh ? 'Auto 自动优选' : 'Auto Failover') : node.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelectedInGroup ? FontWeight.bold : FontWeight.w600,
                                          color: isSelectedInGroup ? const Color(0xFF818CF8) : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isAutoNode && autoGroup != null && autoGroup.current.isNotEmpty)
                                        Text(
                                          '-> ${autoGroup.current}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF10B981)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelectedInGroup)
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                              ],
                            ),

                            // Bottom: Protocol Tag + Latency Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Protocol badge with protocol-specific color
                                _buildProtocolTag(node.type),

                                // Latency Ping chip
                                _buildDelayBadge(
                                  node: node,
                                  tr: tr,
                                  onTest: () {
                                    ref.read(proxiesProvider.notifier).testNodeDelay(node.name);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolTag(OutboundType type) {
    Color tagColor;
    switch (type) {
      case OutboundType.shadowsocks:
        tagColor = const Color(0xFF38BDF8);
        break;
      case OutboundType.vmess:
        tagColor = const Color(0xFF818CF8);
        break;
      case OutboundType.vless:
        tagColor = const Color(0xFF10B981);
        break;
      case OutboundType.trojan:
        tagColor = const Color(0xFFA855F7);
        break;
      case OutboundType.hysteria2:
        tagColor = const Color(0xFFF59E0B);
        break;
      case OutboundType.tuic:
        tagColor = const Color(0xFFF43F5E);
        break;
      case OutboundType.wireguard:
        tagColor = const Color(0xFF2DD4BF);
        break;
      case OutboundType.urltest:
      case OutboundType.selector:
        tagColor = const Color(0xFF818CF8);
        break;
      default:
        tagColor = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tagColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        type.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: tagColor,
        ),
      ),
    );
  }

  Widget _buildDelayBadge({
    required ProxyNode node,
    required Translations tr,
    required VoidCallback onTest,
  }) {
    if (['direct', 'block', 'dns'].contains(node.name)) {
      return const SizedBox();
    }

    Color delayColor = const Color(0xFF64748B);
    String delayText = tr.isZh ? '测速' : 'Test';

    if (node.isTesting) {
      delayText = tr.pinging;
      delayColor = const Color(0xFFF59E0B);
    } else if (node.delay != null) {
      if (node.delay! <= 0) {
        delayText = tr.isZh ? '不可用' : 'Timeout';
        delayColor = const Color(0xFFF43F5E);
      } else {
        delayText = '${node.delay} ms';
        if (node.delay! < 200) {
          delayColor = const Color(0xFF10B981);
        } else if (node.delay! < 500) {
          delayColor = const Color(0xFFF59E0B);
        } else {
          delayColor = const Color(0xFFF43F5E);
        }
      }
    }

    return InkWell(
      onTap: onTest,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: delayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: delayColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              delayText,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: delayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
