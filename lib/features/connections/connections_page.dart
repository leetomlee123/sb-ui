import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connections_provider.dart';
import '../../core/providers/core_provider.dart';
import '../../core/utils/byte_formatter.dart';

class ConnectionsPage extends ConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(coreProvider);
    final connState = ref.watch(connectionsProvider);

    if (!coreState.isRunning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off_rounded, size: 64, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Core is not running',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Active network connections will appear here once connected',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final connections = connState.filteredConnections;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Count, Search, Close All
          Row(
            children: [
              Text(
                'Active Connections (${connState.connections.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Search field
              SizedBox(
                width: 250,
                height: 40,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search host, IP, or rule...',
                    hintStyle: TextStyle(fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (val) {
                    ref.read(connectionsProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: connState.connections.isEmpty
                    ? null
                    : () {
                        ref.read(connectionsProvider.notifier).closeAllConnections();
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                label: const Text('Close All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Connections Data Table
          Expanded(
            child: connections.isEmpty
                ? const Center(
                    child: Text(
                      'No active connections matching query',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: connections.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final conn = connections[index];
                        final destination = conn.metadata.host.isNotEmpty
                            ? conn.metadata.host
                            : '${conn.metadata.destinationIP}:${conn.metadata.destinationPort}';

                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              conn.metadata.network.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                            ),
                          ),
                          title: Text(
                            destination,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                'Rule: ${conn.rule.isEmpty ? "Match" : conn.rule}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 12),
                              if (conn.chains.isNotEmpty)
                                Text(
                                  'Out: ${conn.chains.join(" → ")}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF818CF8)),
                                ),
                            ],
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
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4)),
                                  ),
                                  Text(
                                    '↑ ${ByteFormatter.formatBytes(conn.upload)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1)),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Terminate connection',
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
          ),
        ],
      ),
    );
  }
}
