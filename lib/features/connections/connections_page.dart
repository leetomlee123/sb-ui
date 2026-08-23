import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connections_provider.dart';
import '../../core/providers/core_provider.dart';
import '../../core/utils/byte_formatter.dart';
import '../../shared/widgets/double_bezel_card.dart';

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
            Icon(Icons.link_off_rounded, size: 64, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'sing-box Core is Offline',
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIVE CONNECTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tracking ${connState.connections.length} live TCP / UDP sessions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
                    prefixIcon: Icon(Icons.search_rounded, size: 16),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
                icon: const Icon(Icons.close_fullscreen_rounded, size: 16),
                label: const Text('Close All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Connections Data Table in DoubleBezelCard
          Expanded(
            child: connections.isEmpty
                ? const Center(
                    child: Text(
                      'No active connections matching filter',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : DoubleBezelCard(
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

                          return ListTile(
                            dense: true,
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
                            title: Text(
                              destination,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
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
                                    'Route: ${conn.chains.join(" → ")}',
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
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                    ),
                                    Text(
                                      '↑ ${ByteFormatter.formatBytes(conn.upload)}',
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  tooltip: 'Kill Connection',
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
                  ),
          ),
        ],
      ),
    );
  }
}
