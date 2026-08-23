import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_info.dart';
import 'core_provider.dart';

class DomainTrafficStat {
  final String domain;
  final int upload;
  final int download;
  final int total;
  final int connectionCount;

  const DomainTrafficStat({
    required this.domain,
    required this.upload,
    required this.download,
    required this.total,
    required this.connectionCount,
  });
}

class OutboundTrafficStat {
  final String outbound;
  final int upload;
  final int download;
  final int total;
  final int connectionCount;

  const OutboundTrafficStat({
    required this.outbound,
    required this.upload,
    required this.download,
    required this.total,
    required this.connectionCount,
  });
}

class ConnectionsState {
  final List<ActiveConnection> connections;
  final int downloadTotal;
  final int uploadTotal;
  final bool isLoading;
  final String searchQuery;

  // Cached aggregations
  final List<DomainTrafficStat> topDomains;
  final List<OutboundTrafficStat> topOutbounds;
  final Map<String, int> protocolBreakdown;

  ConnectionsState({
    this.connections = const [],
    this.downloadTotal = 0,
    this.uploadTotal = 0,
    this.isLoading = false,
    this.searchQuery = '',
    List<DomainTrafficStat>? topDomains,
    List<OutboundTrafficStat>? topOutbounds,
    Map<String, int>? protocolBreakdown,
  })  : topDomains = topDomains ?? _computeTopDomains(connections),
        topOutbounds = topOutbounds ?? _computeTopOutbounds(connections),
        protocolBreakdown = protocolBreakdown ?? _computeProtocolBreakdown(connections);

  int get combinedTotal => downloadTotal + uploadTotal;

  List<ActiveConnection> get filteredConnections {
    if (searchQuery.isEmpty) return connections;
    final q = searchQuery.toLowerCase();
    return connections.where((c) {
      return c.metadata.host.toLowerCase().contains(q) ||
          c.metadata.destinationIP.contains(q) ||
          c.rule.toLowerCase().contains(q) ||
          c.chains.any((chain) => chain.toLowerCase().contains(q));
    }).toList();
  }

  static List<DomainTrafficStat> _computeTopDomains(List<ActiveConnection> conns) {
    if (conns.isEmpty) return const [];
    final Map<String, _TempTraffic> map = {};
    for (final c in conns) {
      final host = c.metadata.host.isNotEmpty
          ? c.metadata.host
          : (c.metadata.destinationIP.isNotEmpty ? c.metadata.destinationIP : 'Unknown');
      
      final entry = map.putIfAbsent(host, () => _TempTraffic());
      entry.upload += c.upload;
      entry.download += c.download;
      entry.count += 1;
    }

    final list = map.entries.map((e) {
      return DomainTrafficStat(
        domain: e.key,
        upload: e.value.upload,
        download: e.value.download,
        total: e.value.upload + e.value.download,
        connectionCount: e.value.count,
      );
    }).toList();

    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  static List<OutboundTrafficStat> _computeTopOutbounds(List<ActiveConnection> conns) {
    if (conns.isEmpty) return const [];
    final Map<String, _TempTraffic> map = {};
    for (final c in conns) {
      final outbound = c.chains.isNotEmpty ? c.chains.join(' → ') : (c.rule.isNotEmpty ? c.rule : 'Direct');
      final entry = map.putIfAbsent(outbound, () => _TempTraffic());
      entry.upload += c.upload;
      entry.download += c.download;
      entry.count += 1;
    }

    final list = map.entries.map((e) {
      return OutboundTrafficStat(
        outbound: e.key,
        upload: e.value.upload,
        download: e.value.download,
        total: e.value.upload + e.value.download,
        connectionCount: e.value.count,
      );
    }).toList();

    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  static Map<String, int> _computeProtocolBreakdown(List<ActiveConnection> conns) {
    if (conns.isEmpty) return const {};
    final Map<String, int> map = {};
    for (final c in conns) {
      final net = c.metadata.network.toUpperCase();
      final key = net.isNotEmpty ? net : 'TCP';
      map[key] = (map[key] ?? 0) + (c.upload + c.download);
    }
    return map;
  }

  ConnectionsState copyWith({
    List<ActiveConnection>? connections,
    int? downloadTotal,
    int? uploadTotal,
    bool? isLoading,
    String? searchQuery,
  }) {
    final nextConns = connections ?? this.connections;
    final connsChanged = connections != null && connections != this.connections;

    return ConnectionsState(
      connections: nextConns,
      downloadTotal: downloadTotal ?? this.downloadTotal,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      topDomains: connsChanged ? _computeTopDomains(nextConns) : topDomains,
      topOutbounds: connsChanged ? _computeTopOutbounds(nextConns) : topOutbounds,
      protocolBreakdown: connsChanged ? _computeProtocolBreakdown(nextConns) : protocolBreakdown,
    );
  }
}

class _TempTraffic {
  int upload = 0;
  int download = 0;
  int count = 0;
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final Ref _ref;

  ConnectionsNotifier(this._ref) : super(ConnectionsState()) {
    _ref.listen<CoreState>(coreProvider, (prev, next) {
      if (next.isRunning && (prev == null || !prev.isRunning)) {
        refresh();
      } else if (!next.isRunning) {
        state = state.copyWith(connections: []);
      }
    });
  }

  Future<void> refresh({bool silent = false}) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    if (!silent) state = state.copyWith(isLoading: true);
    try {
      final data = await client.getConnectionsData();
      state = state.copyWith(
        connections: data.connections,
        downloadTotal: data.downloadTotal > 0 ? data.downloadTotal : state.downloadTotal,
        uploadTotal: data.uploadTotal > 0 ? data.uploadTotal : state.uploadTotal,
        isLoading: false,
      );
    } catch (_) {
      if (!silent) state = state.copyWith(isLoading: false);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> closeConnection(String id) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return false;

    final success = await client.closeConnection(id);
    if (success) {
      final updated = state.connections.where((c) => c.id != id).toList();
      state = state.copyWith(connections: updated);
    }
    return success;
  }

  Future<bool> closeAllConnections() async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return false;

    final success = await client.closeAllConnections();
    if (success) {
      state = state.copyWith(connections: []);
    }
    return success;
  }
}

final connectionsProvider = StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ref);
});
