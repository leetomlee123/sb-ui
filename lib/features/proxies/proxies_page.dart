import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/proxy_node.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/proxies_provider.dart';

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
            Icon(Icons.power_off_rounded, size: 64, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Core is not running',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start sing-box from Dashboard to view and switch proxies',
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
          // Header Row: Group selector chips, Search, Speedtest button
          Row(
            children: [
              // Strategy Groups Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: groups.keys.map((groupName) {
                      final isSelected = groupName == selectedGroupName;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(groupName),
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

              // Search field
              SizedBox(
                width: 200,
                height: 40,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter nodes...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
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

              // Speed test button
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(proxiesProvider.notifier).testAllInSelectedGroup();
                },
                icon: const Icon(Icons.speed_rounded, size: 16),
                label: const Text('Speed Test', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(width: 8),

              // Refresh proxies
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

          // Nodes Grid
          Expanded(
            child: filteredNodes.isEmpty
                ? const Center(
                    child: Text(
                      'No proxy nodes found',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      mainAxisExtent: 100,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredNodes.length,
                    itemBuilder: (context, index) {
                      final node = filteredNodes[index];
                      final isSelectedInGroup = activeGroup?.current == node.name;

                      return _buildNodeCard(
                        context,
                        node: node,
                        isSelected: isSelectedInGroup,
                        onTap: () {
                          if (selectedGroupName != null) {
                            ref.read(proxiesProvider.notifier).selectNode(selectedGroupName, node.name);
                          }
                        },
                        onTestDelay: () {
                          ref.read(proxiesProvider.notifier).testNodeDelay(node.name);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeCard(
    BuildContext context, {
    required ProxyNode node,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onTestDelay,
  }) {
    Color delayColor = const Color(0xFF94A3B8);
    String delayText = '—';

    if (node.isTesting) {
      delayText = 'testing...';
      delayColor = const Color(0xFFF59E0B);
    } else if (node.delay != null) {
      if (node.delay! <= 0) {
        delayText = 'Timeout';
        delayColor = const Color(0xFFEF4444);
      } else {
        delayText = '${node.delay} ms';
        if (node.delay! < 200) {
          delayColor = const Color(0xFF10B981);
        } else if (node.delay! < 600) {
          delayColor = const Color(0xFFF59E0B);
        } else {
          delayColor = const Color(0xFFEF4444);
        }
      }
    }

    final isSpecial = ['direct', 'block', 'dns', 'Auto'].contains(node.name);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Node Name & Active Radio Icon
            Row(
              children: [
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF818CF8) : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF6366F1)),
              ],
            ),

            // Bottom Row: Protocol Badge & Latency Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Protocol badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.type.displayName.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                  ),
                ),

                // Latency pill with tap to ping
                if (!isSpecial)
                  InkWell(
                    onTap: onTestDelay,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
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
                              fontWeight: FontWeight.w600,
                              color: delayColor,
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
    );
  }
}
