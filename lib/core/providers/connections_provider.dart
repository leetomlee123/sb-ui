import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_info.dart';
import 'core_provider.dart';

class ConnectionsState {
  final List<ActiveConnection> connections;
  final bool isLoading;
  final String searchQuery;

  ConnectionsState({
    this.connections = const [],
    this.isLoading = false,
    this.searchQuery = '',
  });

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

  ConnectionsState copyWith({
    List<ActiveConnection>? connections,
    bool? isLoading,
    String? searchQuery,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final Ref _ref;
  Timer? _timer;

  ConnectionsNotifier(this._ref) : super(ConnectionsState()) {
    _ref.listen<CoreState>(coreProvider, (prev, next) {
      if (next.isRunning && (prev == null || !prev.isRunning)) {
        refresh();
        _startTimer();
      } else if (!next.isRunning) {
        _stopTimer();
        state = state.copyWith(connections: []);
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh(silent: true));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh({bool silent = false}) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    if (!silent) state = state.copyWith(isLoading: true);
    try {
      final conns = await client.getConnections();
      state = state.copyWith(connections: conns, isLoading: false);
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectionsProvider = StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ref);
});
