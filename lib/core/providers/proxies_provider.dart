import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/profile_parser.dart';
import '../models/proxy_node.dart';
import 'core_provider.dart';
import 'profiles_provider.dart';

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
    if (selectedGroup != null && groups.containsKey(selectedGroup)) {
      final group = groups[selectedGroup]!;
      return group.all
          .map((name) {
            if (nodes.containsKey(name)) return nodes[name]!;
            if (groups.containsKey(name)) {
              final grp = groups[name]!;
              return ProxyNode(name: name, type: grp.type);
            }
            return ProxyNode(name: name, type: OutboundType.unknown);
          })
          .where((n) => n.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    if (nodes.isNotEmpty) {
      return nodes.values
          .where((n) => n.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return [];
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
        Future.delayed(const Duration(milliseconds: 200), () => fetchProxies());
        Future.delayed(const Duration(milliseconds: 800), () => fetchProxies(silent: true));
        _startAutoRefresh();
      } else if (!next.isRunning) {
        _stopAutoRefresh();
      }
    });

    // Populate fallback nodes from active profile immediately
    _populateFromActiveProfile();
  }

  void _populateFromActiveProfile() {
    try {
      final activeProfile = _ref.read(profilesProvider).activeProfile;
      if (activeProfile != null && activeProfile.rawConfig.isNotEmpty) {
        final parseResult = ProfileParser.parse(activeProfile.rawConfig);
        final Map<String, ProxyGroup> groups = {};
        final Map<String, ProxyNode> nodes = {};

        for (final ob in parseResult.outbounds) {
          final tag = (ob['tag'] ?? '').toString();
          final type = (ob['type'] ?? '').toString().toLowerCase();
          if (['selector', 'urltest', 'fallback', 'loadbalance'].contains(type)) {
            final allList = (ob['outbounds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            groups[tag] = ProxyGroup(
              name: tag,
              type: OutboundType.fromString(type),
              current: allList.isNotEmpty ? allList.first : '',
              all: allList,
              raw: ob,
            );
          } else if (tag.isNotEmpty) {
            nodes[tag] = ProxyNode(
              name: tag,
              type: OutboundType.fromString(type),
              server: ob['server']?.toString(),
              port: ob['server_port'] is int ? ob['server_port'] : int.tryParse(ob['server_port']?.toString() ?? ''),
              raw: ob,
            );
          }
        }

        if (groups.isNotEmpty || nodes.isNotEmpty) {
          String? initialGroup = state.selectedGroup;
          if (initialGroup == null || !groups.containsKey(initialGroup)) {
            if (groups.containsKey('Proxy')) {
              initialGroup = 'Proxy';
            } else if (groups.isNotEmpty) {
              initialGroup = groups.keys.first;
            }
          }

          state = state.copyWith(
            groups: groups,
            nodes: nodes,
            selectedGroup: initialGroup,
          );
        }
      }
    } catch (_) {}
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
    if (client == null) {
      _populateFromActiveProfile();
      return;
    }

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

      // Fallback if API returned empty
      if (groups.isEmpty && nodes.isEmpty) {
        _populateFromActiveProfile();
        if (!silent) state = state.copyWith(isLoading: false);
        return;
      }

      String? activeGroup = state.selectedGroup;
      if (activeGroup == null || !groups.containsKey(activeGroup)) {
        if (groups.containsKey('Proxy')) {
          activeGroup = 'Proxy';
        } else if (groups.containsKey('auto')) {
          activeGroup = 'auto';
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
      _populateFromActiveProfile();
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
