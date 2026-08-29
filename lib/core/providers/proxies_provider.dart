import 'dart:async';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/profile_parser.dart';
import '../models/proxy_node.dart';
import 'core_provider.dart';
import 'profiles_provider.dart';
import 'settings_provider.dart';

enum ProxySortMode {
  defaultOrder,
  delayAsc,
  nameAsc,
}

class ProxiesState {
  final Map<String, ProxyGroup> groups;
  final Map<String, ProxyNode> nodes;
  final bool isLoading;
  final bool isTestingAll;
  final String? selectedGroup;
  final String searchQuery;
  final ProxySortMode sortMode;
  final bool hideUnavailable;

  ProxiesState({
    this.groups = const {},
    this.nodes = const {},
    this.isLoading = false,
    this.isTestingAll = false,
    this.selectedGroup,
    this.searchQuery = '',
    this.sortMode = ProxySortMode.defaultOrder,
    this.hideUnavailable = false,
  });

  List<ProxyNode> get filteredNodes {
    List<ProxyNode> list = [];
    if (selectedGroup != null && groups.containsKey(selectedGroup)) {
      final group = groups[selectedGroup]!;
      list = group.all
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
    } else if (nodes.isNotEmpty) {
      list = nodes.values
          .where((n) => n.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    if (hideUnavailable) {
      list = list.where((n) => (n.delay ?? 0) > 0).toList();
    }

    if (sortMode == ProxySortMode.delayAsc) {
      list.sort((a, b) {
        final dA = a.delay ?? 0;
        final dB = b.delay ?? 0;
        final delayA = dA <= 0 ? 999999 : dA;
        final delayB = dB <= 0 ? 999999 : dB;
        return delayA.compareTo(delayB);
      });
    } else if (sortMode == ProxySortMode.nameAsc) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return list;
  }

  List<String> get sortedGroupNames {
    final keys = groups.keys.toList();
    keys.sort((a, b) {
      if (a == 'Proxy' || a == '节点选择') return -1;
      if (b == 'Proxy' || b == '节点选择') return 1;
      final grpA = groups[a];
      final grpB = groups[b];
      final isSelectorA = grpA?.type == OutboundType.selector;
      final isSelectorB = grpB?.type == OutboundType.selector;
      if (isSelectorA && !isSelectorB) return -1;
      if (!isSelectorA && isSelectorB) return 1;
      return a.compareTo(b);
    });
    return keys;
  }

  ProxiesState copyWith({
    Map<String, ProxyGroup>? groups,
    Map<String, ProxyNode>? nodes,
    bool? isLoading,
    bool? isTestingAll,
    String? selectedGroup,
    String? searchQuery,
    ProxySortMode? sortMode,
    bool? hideUnavailable,
  }) {
    return ProxiesState(
      groups: groups ?? this.groups,
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      isTestingAll: isTestingAll ?? this.isTestingAll,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      searchQuery: searchQuery ?? this.searchQuery,
      sortMode: sortMode ?? this.sortMode,
      hideUnavailable: hideUnavailable ?? this.hideUnavailable,
    );
  }
}

class ProxiesNotifier extends StateNotifier<ProxiesState> {
  final Ref _ref;

  // Startup dedupe: track which raw config has already been parsed so the
  // potentially large subscription config is decoded once, not on every
  // fetchProxies() fallback.
  String? _populatedForRaw;
  bool _populateInFlight = false;

  ProxiesNotifier(this._ref) : super(ProxiesState()) {
    _ref.listen<CoreState>(coreProvider, (previous, next) {
      if (next.isRunning && (previous == null || !previous.isRunning)) {
        Future.delayed(const Duration(milliseconds: 300), () => fetchProxies());
        Future.delayed(const Duration(milliseconds: 1000), () => fetchProxies(silent: true));
      }
    });

    // Non-blocking: parsing runs in a background isolate and fills state
    // when ready, keeping the first frame free of heavy JSON/YAML work.
    unawaited(_populateFromActiveProfile());
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

  final Map<String, int> _delayCache = {};

  Future<void> _populateFromActiveProfile() async {
    if (_populateInFlight) return;
    try {
      final activeProfile = _ref.read(profilesProvider).activeProfile;
      final raw = activeProfile?.rawConfig ?? '';
      if (raw.isEmpty || raw == _populatedForRaw) return;

      _populateInFlight = true;
      // Heavy JSON/YAML decode of the raw subscription runs off the UI isolate.
      final parseResult = await Isolate.run(() => ProfileParser.parse(raw));
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
            delay: _delayCache[tag] ?? state.nodes[tag]?.delay,
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
        final preferredNode = _ref.read(settingsProvider).selectedProxyNode;
        final initialCurrent = (preferredNode.isNotEmpty && allTargets.contains(preferredNode))
            ? preferredNode
            : (groups.keys.isNotEmpty ? groups.keys.first : (nodes.keys.isNotEmpty ? nodes.keys.first : 'direct'));

        groups['Proxy'] = ProxyGroup(
          name: 'Proxy',
          type: OutboundType.selector,
          current: initialCurrent,
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
      _populatedForRaw = raw;
    } catch (_) {
    } finally {
      _populateInFlight = false;
    }
  }

  Future<void> fetchProxies({bool silent = false}) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) {
      await _populateFromActiveProfile();
      return;
    }

    if (!silent) state = state.copyWith(isLoading: true);
    try {
      final rawProxies = await client.getProxiesRaw();
      if (rawProxies.isEmpty) {
        await _populateFromActiveProfile();
        if (!silent) state = state.copyWith(isLoading: false);
        return;
      }

      final Map<String, ProxyGroup> groups = {};
      final Map<String, ProxyNode> nodes = {};

      rawProxies.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          final type = (val['type'] ?? '').toString().toLowerCase();
          if (['selector', 'urltest', 'fallback', 'loadbalance'].contains(type)) {
            groups[key] = ProxyGroup.fromClashApi(key, val);
          } else {
            final parsed = ProxyNode.fromClashApi(key, val);
            final preservedDelay = parsed.delay ?? _delayCache[key] ?? state.nodes[key]?.delay;
            if (preservedDelay != null) {
              _delayCache[key] = preservedDelay;
            }
            nodes[key] = parsed.copyWith(
              delay: preservedDelay,
              isTesting: false,
            );
          }
        }
      });

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
      await _populateFromActiveProfile();
      if (!silent) state = state.copyWith(isLoading: false);
    }
  }

  void setSelectedGroup(String groupName) {
    state = state.copyWith(selectedGroup: groupName);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortMode(ProxySortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void toggleHideUnavailable(bool hide) {
    state = state.copyWith(hideUnavailable: hide);
  }

  void stopTesting() {
    _testGeneration++;
    final updatedNodes = Map<String, ProxyNode>.from(state.nodes);
    bool changed = false;
    for (final entry in updatedNodes.entries) {
      if (entry.value.isTesting) {
        updatedNodes[entry.key] = entry.value.copyWith(isTesting: false);
        changed = true;
      }
    }
    state = state.copyWith(
      nodes: changed ? updatedNodes : state.nodes,
      isTestingAll: false,
    );
  }

  Future<int> removeUnavailableNodes() async {
    // 1. Immediately abort any running test batch
    stopTesting();

    // 2. Identify all unavailable nodes (delay != null && delay <= 0)
    final deadNodeNames = state.nodes.entries
        .where((e) => e.value.delay != null && e.value.delay! <= 0)
        .map((e) => e.key)
        .toSet();

    if (deadNodeNames.isEmpty) {
      return 0;
    }

    // 3. Remove dead nodes from delay cache
    for (final dead in deadNodeNames) {
      _delayCache.remove(dead);
    }

    // 4. Remove dead nodes from in-memory state
    final updatedNodes = Map<String, ProxyNode>.from(state.nodes)
      ..removeWhere((key, _) => deadNodeNames.contains(key));

    final updatedGroups = <String, ProxyGroup>{};
    for (final entry in state.groups.entries) {
      final grp = entry.value;
      final newAll = grp.all.where((name) => !deadNodeNames.contains(name)).toList();
      final newCurrent = deadNodeNames.contains(grp.current)
          ? (newAll.isNotEmpty ? newAll.first : '')
          : grp.current;
      updatedGroups[entry.key] = grp.copyWith(
        all: newAll,
        current: newCurrent,
      );
    }

    state = state.copyWith(
      nodes: updatedNodes,
      groups: updatedGroups,
      isTestingAll: false,
    );

    // 5. Update the active profile's rawConfig on disk and in ProfilesState
    final activeProfile = _ref.read(profilesProvider).activeProfile;
    if (activeProfile != null && activeProfile.rawConfig.isNotEmpty) {
      final newRawConfig = ProfileParser.removeNodesFromContent(
        activeProfile.rawConfig,
        deadNodeNames,
      );
      await _ref.read(profilesProvider.notifier).updateProfileContent(
        activeProfile.id,
        newRawConfig,
      );
    }

    // 6. If core is running, restart core to apply updated node list immediately
    final isRunning = _ref.read(coreProvider).isRunning;
    if (isRunning) {
      await _ref.read(coreProvider.notifier).restartCore();
    }

    return deadNodeNames.length;
  }

  Future<bool> selectNode(String groupName, String nodeName) async {
    // 1. Save user node preference in persistent settings
    _ref.read(settingsProvider.notifier).setSelectedProxyNode(nodeName);

    // 2. Identify target selector groups
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

    // Also include any other selector groups that have this node as an option (e.g. Proxy, GLOBAL if selector)
    for (final entry in state.groups.entries) {
      if (entry.value.type == OutboundType.selector &&
          entry.value.all.contains(nodeName) &&
          !targetGroups.contains(entry.key)) {
        targetGroups.add(entry.key);
      }
    }

    // 3. Optimistic UI update: immediately switch current node in local selector groups
    final updatedGroups = Map<String, ProxyGroup>.from(state.groups);
    for (final grpName in targetGroups) {
      if (updatedGroups.containsKey(grpName)) {
        updatedGroups[grpName] = updatedGroups[grpName]!.copyWith(current: nodeName);
      }
    }
    state = state.copyWith(groups: updatedGroups);

    final client = _ref.read(clashApiClientProvider);
    if (client == null) return true;

    // 4. Dispatch PUT /proxies/{group} to Clash API for all target selector groups
    bool anySuccess = false;
    for (final grp in targetGroups) {
      try {
        final ok = await client.selectProxy(grp, nodeName);
        if (ok) anySuccess = true;
      } catch (_) {}
    }

    // 5. Immediately re-fetch proxies from Clash API to synchronize
    await fetchProxies(silent: true);
    return anySuccess;
  }

  int _testGeneration = 0;

  Future<void> testNodeDelay(String nodeName) async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    final current = state.nodes[nodeName];
    if (current == null) return;

    // 1. Atomically mark node as testing
    final updating = Map<String, ProxyNode>.from(state.nodes);
    updating[nodeName] = current.copyWith(isTesting: true);
    state = state.copyWith(nodes: updating);

    int? delay;
    try {
      delay = await client.testDelay(nodeName).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (_) {
      delay = null;
    }

    final finalDelay = delay ?? -1;
    _delayCache[nodeName] = finalDelay;

    // 2. Atomically update with fresh state snapshot
    final latestNodes = Map<String, ProxyNode>.from(state.nodes);
    final target = latestNodes[nodeName] ?? current;
    latestNodes[nodeName] = target.copyWith(
      delay: finalDelay,
      isTesting: false,
    );
    state = state.copyWith(nodes: latestNodes);
  }

  Future<void> testAllInSelectedGroup() async {
    final selectedGroup = state.selectedGroup;
    if (selectedGroup == null || !state.groups.containsKey(selectedGroup)) return;
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    final group = state.groups[selectedGroup]!;
    final List<String> targetNodeNames = group.all
        .where((name) => state.nodes.containsKey(name))
        .toList();

    if (targetNodeNames.isEmpty) return;

    final generation = ++_testGeneration;

    // 1. Mark all targeted nodes as testing in ONE atomic state update
    final initialNodes = Map<String, ProxyNode>.from(state.nodes);
    for (final name in targetNodeNames) {
      if (initialNodes.containsKey(name)) {
        initialNodes[name] = initialNodes[name]!.copyWith(isTesting: true);
      }
    }
    state = state.copyWith(nodes: initialNodes, isTestingAll: true);

    try {
      // 2. Concurrently test in worker pool of 12 parallel tasks
      const concurrency = 12;
      int currentIndex = 0;

      Future<void> worker() async {
        while (currentIndex < targetNodeNames.length) {
          if (_testGeneration != generation) return;
          final index = currentIndex++;
          if (index >= targetNodeNames.length) break;
          final nodeName = targetNodeNames[index];

          int? delay;
          try {
            delay = await client.testDelay(nodeName).timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            );
          } catch (_) {
            delay = null;
          }

          if (_testGeneration != generation) return;

          final finalDelay = delay ?? -1;
          _delayCache[nodeName] = finalDelay;

          // Fresh atomic update for completed node
          final freshNodes = Map<String, ProxyNode>.from(state.nodes);
          final current = freshNodes[nodeName];
          if (current != null) {
            freshNodes[nodeName] = current.copyWith(
              delay: finalDelay,
              isTesting: false,
            );
            state = state.copyWith(nodes: freshNodes);
          }
        }
      }

      final workerCount = targetNodeNames.length < concurrency ? targetNodeNames.length : concurrency;
      final workers = List.generate(workerCount, (_) => worker());

      await Future.wait(workers);
    } finally {
      if (_testGeneration == generation) {
        // 3. Safety cleanup: ensure no node in state is left stuck with isTesting: true
        final cleanupNodes = Map<String, ProxyNode>.from(state.nodes);
        bool hasStuck = false;
        for (final entry in cleanupNodes.entries) {
          if (entry.value.isTesting) {
            cleanupNodes[entry.key] = entry.value.copyWith(isTesting: false);
            hasStuck = true;
          }
        }
        state = state.copyWith(
          nodes: hasStuck ? cleanupNodes : state.nodes,
          isTestingAll: false,
        );
      }
    }
  }
}

final proxiesProvider = StateNotifierProvider<ProxiesNotifier, ProxiesState>((ref) {
  return ProxiesNotifier(ref);
});
