import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proxy_node.dart';
import 'core_provider.dart';

class ProxiesState {
  final Map<String, ProxyGroup> groups;
  final Map<String, ProxyNode> nodes;
  final bool isLoading;
  final String? selectedGroup;
  final String searchQuery;

  ProxiesState({
    this.groups = const {},
    this.nodes = const {},
    this.isLoading = false,
    this.selectedGroup,
    this.searchQuery = '',
  });

  List<ProxyNode> get filteredNodes {
    if (selectedGroup == null || !groups.containsKey(selectedGroup)) {
      return nodes.values.toList();
    }
    final group = groups[selectedGroup]!;
    return group.all
        .map((name) => nodes[name] ?? ProxyNode(name: name, type: OutboundType.unknown))
        .where((n) => n.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  ProxiesState copyWith({
    Map<String, ProxyGroup>? groups,
    Map<String, ProxyNode>? nodes,
    bool? isLoading,
    String? selectedGroup,
    String? searchQuery,
  }) {
    return ProxiesState(
      groups: groups ?? this.groups,
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ProxiesNotifier extends StateNotifier<ProxiesState> {
  final Ref _ref;
  Timer? _refreshTimer;

  ProxiesNotifier(this._ref) : super(ProxiesState()) {
    _ref.listen<CoreState>(coreProvider, (previous, next) {
      if (next.isRunning && (previous == null || !previous.isRunning)) {
        fetchProxies();
        _startAutoRefresh();
      } else if (!next.isRunning) {
        _stopAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchProxies(silent: true));
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> fetchProxies({bool silent = false}) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    if (!silent) state = state.copyWith(isLoading: true);
    try {
      final rawProxies = await client.getProxiesRaw();
      final Map<String, ProxyGroup> groups = {};
      final Map<String, ProxyNode> nodes = {};

      rawProxies.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          final type = (val['type'] ?? '').toString().toLowerCase();
          if (['selector', 'urltest', 'fallback', 'loadbalance'].contains(type)) {
            groups[key] = ProxyGroup.fromClashApi(key, val);
          } else {
            nodes[key] = ProxyNode.fromClashApi(key, val);
          }
        }
      });

      String? activeGroup = state.selectedGroup;
      if (activeGroup == null || !groups.containsKey(activeGroup)) {
        if (groups.containsKey('Proxy')) {
          activeGroup = 'Proxy';
        } else if (groups.isNotEmpty) {
          activeGroup = groups.keys.first;
        }
      }

      state = state.copyWith(
        groups: groups,
        nodes: nodes,
        selectedGroup: activeGroup,
        isLoading: false,
      );
    } catch (_) {
      if (!silent) state = state.copyWith(isLoading: false);
    }
  }

  void setSelectedGroup(String groupName) {
    state = state.copyWith(selectedGroup: groupName);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> selectNode(String groupName, String nodeName) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return false;

    final success = await client.selectProxy(groupName, nodeName);
    if (success) {
      if (state.groups.containsKey(groupName)) {
        final currentGroup = state.groups[groupName]!;
        final updatedGroups = Map<String, ProxyGroup>.from(state.groups);
        updatedGroups[groupName] = currentGroup.copyWith(current: nodeName);
        state = state.copyWith(groups: updatedGroups);
      }
    }
    return success;
  }

  Future<void> testNodeDelay(String nodeName) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    if (state.nodes.containsKey(nodeName)) {
      final current = state.nodes[nodeName]!;
      final updatedNodes = Map<String, ProxyNode>.from(state.nodes);
      updatedNodes[nodeName] = current.copyWith(isTesting: true);
      state = state.copyWith(nodes: updatedNodes);

      final delay = await client.testDelay(nodeName);
      final nodeAfter = state.nodes[nodeName] ?? current;
      updatedNodes[nodeName] = nodeAfter.copyWith(delay: delay, isTesting: false);
      state = state.copyWith(nodes: updatedNodes);
    }
  }

  Future<void> testAllInSelectedGroup() async {
    if (state.selectedGroup == null || !state.groups.containsKey(state.selectedGroup)) return;
    final group = state.groups[state.selectedGroup]!;
    final List<Future> tests = [];

    for (final nodeName in group.all) {
      tests.add(testNodeDelay(nodeName));
    }
    await Future.wait(tests);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final proxiesProvider = StateNotifierProvider<ProxiesNotifier, ProxiesState>((ref) {
  return ProxiesNotifier(ref);
});
