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

  ProxiesNotifier(this._ref) : super(ProxiesState()) {
    _ref.listen<CoreState>(coreProvider, (previous, next) {
      if (next.isRunning && (previous == null || !previous.isRunning)) {
        Future.delayed(const Duration(milliseconds: 200), () => fetchProxies());
        Future.delayed(const Duration(milliseconds: 800), () => fetchProxies(silent: true));
      }
    });

    _populateFromActiveProfile();
  }

  static String? findBestDefaultGroup(Map<String, ProxyGroup> groups) {
    if (groups.isEmpty) return null;

    // 1. First priority: Primary Selector groups
    const primarySelectorNames = ['节点选择', 'Proxy', 'proxy', 'GLOBAL', '漏网之鱼', '国外流量', 'default'];
    for (final name in primarySelectorNames) {
      if (groups.containsKey(name) && groups[name]!.type == OutboundType.selector) {
        return name;
      }
    }

    // 2. Any other Selector group
    for (final entry in groups.entries) {
      if (entry.value.type == OutboundType.selector) {
        return entry.key;
      }
    }

    // 3. Fallback to any group (e.g. urltest)
    return groups.keys.first;
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

        // If no selector group exists in profile, synthesize the primary Proxy group so UI is immediately actionable
        final hasSelector = groups.values.any((g) => g.type == OutboundType.selector);
        if (!hasSelector && (nodes.isNotEmpty || groups.isNotEmpty)) {
          final allTargets = [
            ...groups.keys,
            ...nodes.keys,
            'direct',
          ];
          groups['Proxy'] = ProxyGroup(
            name: 'Proxy',
            type: OutboundType.selector,
            current: groups.keys.isNotEmpty ? groups.keys.first : (nodes.keys.isNotEmpty ? nodes.keys.first : 'direct'),
            all: allTargets,
            raw: {'type': 'selector', 'tag': 'Proxy', 'outbounds': allTargets},
          );
        }

        if (groups.isNotEmpty || nodes.isNotEmpty) {
          String? initialGroup = findBestDefaultGroup(groups);

          state = state.copyWith(
            groups: groups,
            nodes: nodes,
            selectedGroup: initialGroup,
          );
        }
      }
    } catch (_) {}
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

      // First include all profile parsed nodes as baseline so NO node is ever lost or hidden!
      _populateFromActiveProfile();
      nodes.addAll(state.nodes);

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

      // If API returned empty groups, keep profile groups
      if (groups.isEmpty) {
        groups.addAll(state.groups);
      }

      String? activeGroup = state.selectedGroup;
      if (activeGroup == null ||
          !groups.containsKey(activeGroup) ||
          (groups[activeGroup]?.type != OutboundType.selector && groups.values.any((g) => g.type == OutboundType.selector))) {
        activeGroup = findBestDefaultGroup(groups);
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

    // Determine target selector groups:
    final List<String> targetGroups = [];

    // If current group is a selector, target it
    if (state.groups.containsKey(groupName) && state.groups[groupName]!.type == OutboundType.selector) {
      targetGroups.add(groupName);
    } else {
      // User clicked a node inside a URLTest group: find primary selector group (e.g. Proxy) and switch it
      final primarySelector = findBestDefaultGroup(state.groups);
      if (primarySelector != null && !targetGroups.contains(primarySelector)) {
        targetGroups.add(primarySelector);
      }
    }

    // Also include any other selector groups that have this node as an option (e.g. Proxy, GLOBAL)
    for (final entry in state.groups.entries) {
      if (entry.value.type == OutboundType.selector &&
          entry.value.all.contains(nodeName) &&
          !targetGroups.contains(entry.key)) {
        targetGroups.add(entry.key);
      }
    }

    // 1. Optimistic UI update: immediately switch current node in local selector groups
    final updatedGroups = Map<String, ProxyGroup>.from(state.groups);
    for (final grpName in targetGroups) {
      if (updatedGroups.containsKey(grpName)) {
        updatedGroups[grpName] = updatedGroups[grpName]!.copyWith(current: nodeName);
      }
    }
    state = state.copyWith(groups: updatedGroups);

    if (client == null) return true;

    // 2. Dispatch PUT /proxies/{group} to Clash API for all target selector groups
    bool anySuccess = false;
    for (final grp in targetGroups) {
      try {
        final ok = await client.selectProxy(grp, nodeName);
        if (ok) anySuccess = true;
      } catch (_) {}
    }

    // 3. Immediately re-fetch proxies from Clash API to synchronize
    await fetchProxies(silent: true);
    return anySuccess;
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
      // If delay is null or <= 0, mark as -1 (Timeout/Unavailable)
      updatedNodes[nodeName] = nodeAfter.copyWith(delay: delay ?? -1, isTesting: false);
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
}

final proxiesProvider = StateNotifierProvider<ProxiesNotifier, ProxiesState>((ref) {
  return ProxiesNotifier(ref);
});
