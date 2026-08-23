import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/proxy_node.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/proxies_provider.dart';
import '../../shared/widgets/double_bezel_card.dart';

class ProxiesPage extends ConsumerWidget {
  const ProxiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(coreProvider);
    final proxiesState = ref.watch(proxiesProvider);
    final groups = proxiesState.groups;
    final selectedGroupName = proxiesState.selectedGroup;

    if (!coreState.isRunning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_off_rounded, size: 64, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'sing-box Core is Offline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start connection on Dashboard to manage proxies and test latency',
              style: TextStyle(color: Color(0xFF94A3B8)),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar: Strategy Group Chips, Search & Speed Test
          Row(
            children: [
              // Strategy Groups selector chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: groups.keys.map((groupName) {
                      final isSelected = groupName == selectedGroupName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(groupName, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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

              const SizedBox(width: 16),

              // Search Filter Field
              SizedBox(
                width: 220,
                height: 40,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter nodes...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(proxiesProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Speed Test Button
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(proxiesProvider.notifier).testAllInSelectedGroup();
                },
                icon: const Icon(Icons.speed_rounded, size: 16),
                label: const Text('Ping All', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(width: 8),

              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh list',
                onPressed: () {
                  ref.read(proxiesProvider.notifier).fetchProxies();
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Nodes Grid (Asymmetrical Double-Bezel Cards)
          Expanded(
            child: filteredNodes.isEmpty
                ? const Center(
                    child: Text(
                      'No proxy nodes found',
                      style: TextStyle(color: Color(0xFF64748B)),
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
                      final isSelectedInGroup = activeGroup?.current == node.name;

                      return DoubleBezelCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: 14,
                        isSelected: isSelectedInGroup,
                        onTap: () {
                          if (selectedGroupName != null) {
                            ref.read(proxiesProvider.notifier).selectNode(selectedGroupName, node.name);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top: Node Name + Radio Circle
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    node.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelectedInGroup ? FontWeight.bold : FontWeight.w600,
                                      color: isSelectedInGroup ? const Color(0xFF818CF8) : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelectedInGroup)
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, size: 11, color: Colors.white),
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
    required VoidCallback onTest,
  }) {
    if (['direct', 'block', 'dns', 'Auto'].contains(node.name)) {
      return const SizedBox();
    }

    Color delayColor = const Color(0xFF64748B);
    String delayText = '—';

    if (node.isTesting) {
      delayText = 'pinging...';
      delayColor = const Color(0xFFF59E0B);
    } else if (node.delay != null) {
      if (node.delay! <= 0) {
        delayText = 'Timeout';
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
