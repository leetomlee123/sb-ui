import 'dart:convert';
import 'package:flutter/material.dart';

class VisualConfigEditor extends StatefulWidget {
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const VisualConfigEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<VisualConfigEditor> createState() => _VisualConfigEditorState();
}

class _VisualConfigEditorState extends State<VisualConfigEditor> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _config;

  String _outboundSearch = '';
  String _outboundFilter = 'all'; // 'all', 'proxy', 'group', 'special'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _config = _deepCloneMap(widget.config);
  }

  @override
  void didUpdateWidget(covariant VisualConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(widget.config) != jsonEncode(_config)) {
      _config = _deepCloneMap(widget.config);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _deepCloneMap(Map<String, dynamic> map) {
    try {
      return jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
    } catch (_) {
      return Map<String, dynamic>.from(map);
    }
  }

  void _notifyChange() {
    widget.onChanged(_deepCloneMap(_config));
    setState(() {});
  }

  // --- Outbounds Helpers ---
  List<Map<String, dynamic>> get _outbounds {
    if (_config['outbounds'] is List) {
      return (_config['outbounds'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _outbounds(List<Map<String, dynamic>> list) {
    _config['outbounds'] = list;
    _notifyChange();
  }

  List<String> get _allOutboundTags {
    return _outbounds
        .map((e) => (e['tag'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // --- Inbounds Helpers ---
  List<Map<String, dynamic>> get _inbounds {
    if (_config['inbounds'] is List) {
      return (_config['inbounds'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _inbounds(List<Map<String, dynamic>> list) {
    _config['inbounds'] = list;
    _notifyChange();
  }

  // --- Route Helpers ---
  Map<String, dynamic> get _routeMap {
    if (_config['route'] is Map) {
      return Map<String, dynamic>.from(_config['route'] as Map);
    }
    return {};
  }

  List<Map<String, dynamic>> get _routeRules {
    final route = _routeMap;
    if (route['rules'] is List) {
      return (route['rules'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _routeRules(List<Map<String, dynamic>> rules) {
    final route = _routeMap;
    route['rules'] = rules;
    _config['route'] = route;
    _notifyChange();
  }

  List<Map<String, dynamic>> get _routeRuleSets {
    final route = _routeMap;
    if (route['rule_set'] is List) {
      return (route['rule_set'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _routeRuleSets(List<Map<String, dynamic>> sets) {
    final route = _routeMap;
    route['rule_set'] = sets;
    _config['route'] = route;
    _notifyChange();
  }

  // --- DNS Helpers ---
  Map<String, dynamic> get _dnsMap {
    if (_config['dns'] is Map) {
      return Map<String, dynamic>.from(_config['dns'] as Map);
    }
    return {};
  }

  List<Map<String, dynamic>> get _dnsServers {
    final dns = _dnsMap;
    if (dns['servers'] is List) {
      return (dns['servers'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _dnsServers(List<Map<String, dynamic>> servers) {
    final dns = _dnsMap;
    dns['servers'] = servers;
    _config['dns'] = dns;
    _notifyChange();
  }

  List<Map<String, dynamic>> get _dnsRules {
    final dns = _dnsMap;
    if (dns['rules'] is List) {
      return (dns['rules'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  set _dnsRules(List<Map<String, dynamic>> rules) {
    final dns = _dnsMap;
    dns['rules'] = rules;
    _config['dns'] = dns;
    _notifyChange();
  }

  // --- Log & General Helpers ---
  Map<String, dynamic> get _logMap {
    if (_config['log'] is Map) {
      return Map<String, dynamic>.from(_config['log'] as Map);
    }
    return {};
  }

  set _logMap(Map<String, dynamic> log) {
    _config['log'] = log;
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final outboundsCount = _outbounds.length;
    final inboundsCount = _inbounds.length;
    final routeRulesCount = _routeRules.length;
    final dnsServersCount = _dnsServers.length;

    return Column(
      children: [
        // Visual Module Tab Bar
        Container(
          height: 48,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1322),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF6366F1),
            indicatorWeight: 3,
            labelColor: const Color(0xFF818CF8),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.flight_takeoff_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('出站 (Outbounds)'),
                    const SizedBox(width: 6),
                    _buildBadge(outboundsCount),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.flight_land_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('入站 (Inbounds)'),
                    const SizedBox(width: 6),
                    _buildBadge(inboundsCount),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.alt_route_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('路由分流 (Route)'),
                    const SizedBox(width: 6),
                    _buildBadge(routeRulesCount),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.dns_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('DNS 配置 (DNS)'),
                    const SizedBox(width: 6),
                    _buildBadge(dnsServersCount),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  children: [
                    Icon(Icons.settings_suggest_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('日志与通用 (General)'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOutboundsTab(),
              _buildInboundsTab(),
              _buildRouteTab(),
              _buildDnsTab(),
              _buildGeneralTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
      ),
    );
  }

  // ==========================================
  // 1. OUTBOUNDS TAB
  // ==========================================
  Widget _buildOutboundsTab() {
    final list = _outbounds;
    final filtered = list.where((ob) {
      final tag = (ob['tag'] ?? '').toString().toLowerCase();
      final type = (ob['type'] ?? '').toString().toLowerCase();
      final server = (ob['server'] ?? '').toString().toLowerCase();

      // Search filter
      if (_outboundSearch.isNotEmpty) {
        final q = _outboundSearch.toLowerCase();
        if (!tag.contains(q) && !type.contains(q) && !server.contains(q)) {
          return false;
        }
      }

      // Category filter
      if (_outboundFilter == 'proxy') {
        return ['vless', 'vmess', 'trojan', 'shadowsocks', 'ss', 'hysteria2', 'hy2', 'tuic', 'wireguard', 'socks', 'http'].contains(type);
      } else if (_outboundFilter == 'group') {
        return ['selector', 'urltest', 'loadbalance'].contains(type);
      } else if (_outboundFilter == 'special') {
        return ['direct', 'block', 'dns'].contains(type);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar: Search + Filter Chips + Add Button
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '搜索出站节点标签...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF818CF8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _outboundSearch = val),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('全部', style: TextStyle(fontSize: 11.5))),
                    ButtonSegment(value: 'proxy', label: Text('代理节点', style: TextStyle(fontSize: 11.5))),
                    ButtonSegment(value: 'group', label: Text('策略组', style: TextStyle(fontSize: 11.5))),
                    ButtonSegment(value: 'special', label: Text('基础分流', style: TextStyle(fontSize: 11.5))),
                  ],
                  selected: {_outboundFilter},
                  onSelectionChanged: (set) => setState(() => _outboundFilter = set.first),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () => _showOutboundEditDialog(null),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('添加出站', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Outbounds Cards List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flight_takeoff_rounded, size: 48, color: const Color(0xFF64748B).withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('暂无匹配的出站配置', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final ob = filtered[i];
                      return _buildOutboundCard(ob);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboundCard(Map<String, dynamic> ob) {
    final tag = (ob['tag'] ?? 'Unnamed').toString();
    final type = (ob['type'] ?? 'unknown').toString().toLowerCase();
    final server = (ob['server'] ?? '').toString();
    final port = ob['server_port'] ?? ob['port'] ?? '';

    Color typeColor = const Color(0xFF38BDF8);
    IconData typeIcon = Icons.flash_on_rounded;

    if (type == 'selector') {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = Icons.tune_rounded;
    } else if (type == 'urltest') {
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.speed_rounded;
    } else if (type == 'direct') {
      typeColor = const Color(0xFF34D399);
      typeIcon = Icons.navigation_rounded;
    } else if (type == 'block') {
      typeColor = const Color(0xFFF43F5E);
      typeIcon = Icons.block_rounded;
    } else if (type == 'dns') {
      typeColor = const Color(0xFFA855F7);
      typeIcon = Icons.dns_rounded;
    }

    final outboundsList = (ob['outbounds'] is List) ? (ob['outbounds'] as List).map((e) => e.toString()).toList() : <String>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // Type Icon & Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: typeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeIcon, size: 13, color: typeColor),
                const SizedBox(width: 4),
                Text(
                  type.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Tag Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ob['default'] != null) ...[
                      const SizedBox(width: 8),
                      Text('默认: ${ob['default']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (server.isNotEmpty)
                  Text(
                    '$server${port.toString().isNotEmpty ? ':$port' : ''}',
                    style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                  )
                else if (outboundsList.isNotEmpty)
                  Text(
                    '包含 ${outboundsList.length} 个子节点: ${outboundsList.take(4).join(', ')}${outboundsList.length > 4 ? '...' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    type == 'direct' ? '直连网络连接' : (type == 'block' ? '阻断拦截流量' : 'DNS 本地/远端解析出站'),
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),

          // Action Buttons
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
            tooltip: '复制节点',
            onPressed: () {
              final newOb = Map<String, dynamic>.from(ob);
              newOb['tag'] = '$tag (Copy)';
              final current = _outbounds;
              current.add(newOb);
              _outbounds = current;
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF818CF8)),
            tooltip: '编辑出站配置',
            onPressed: () => _showOutboundEditDialog(ob),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
            tooltip: '删除出站',
            onPressed: () {
              final current = _outbounds;
              current.removeWhere((item) => item['tag'] == ob['tag']);
              _outbounds = current;
            },
          ),
        ],
      ),
    );
  }

  void _showOutboundEditDialog(Map<String, dynamic>? initial) {
    final isNew = initial == null;
    final data = initial != null ? Map<String, dynamic>.from(initial) : <String, dynamic>{
      'type': 'vless',
      'tag': 'New-Outbound',
      'server': 'example.com',
      'server_port': 443,
      'uuid': '',
    };

    final tagCtrl = TextEditingController(text: (data['tag'] ?? '').toString());
    final serverCtrl = TextEditingController(text: (data['server'] ?? '').toString());
    final portCtrl = TextEditingController(text: (data['server_port'] ?? data['port'] ?? 443).toString());
    final uuidCtrl = TextEditingController(text: (data['uuid'] ?? data['password'] ?? '').toString());
    final sniCtrl = TextEditingController(text: (data['tls'] is Map ? (data['tls'] as Map)['server_name'] ?? '' : '').toString());
    final realityPbkCtrl = TextEditingController(
      text: (data['tls'] is Map && (data['tls'] as Map)['reality'] is Map)
          ? ((data['tls'] as Map)['reality'] as Map)['public_key'] ?? ''
          : '',
    );
    final realitySidCtrl = TextEditingController(
      text: (data['tls'] is Map && (data['tls'] as Map)['reality'] is Map)
          ? ((data['tls'] as Map)['reality'] as Map)['short_id'] ?? ''
          : '',
    );

    String selectedType = (data['type'] ?? 'vless').toString().toLowerCase();
    List<String> selectedGroupOutbounds = (data['outbounds'] is List)
        ? (data['outbounds'] as List).map((e) => e.toString()).toList()
        : <String>[];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(isNew ? Icons.add_circle_outline_rounded : Icons.edit_rounded, color: const Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(isNew ? '添加出站节点 / 策略组' : '编辑出站配置 (${data['tag']})', style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Outbound Protocol / Type
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: '出站协议 / 类型 (Type)'),
                      items: const [
                        DropdownMenuItem(value: 'vless', child: Text('VLESS (Reality / TLS)')),
                        DropdownMenuItem(value: 'vmess', child: Text('VMess')),
                        DropdownMenuItem(value: 'trojan', child: Text('Trojan')),
                        DropdownMenuItem(value: 'shadowsocks', child: Text('Shadowsocks (SS)')),
                        DropdownMenuItem(value: 'hysteria2', child: Text('Hysteria 2 (Hy2)')),
                        DropdownMenuItem(value: 'tuic', child: Text('TUIC')),
                        DropdownMenuItem(value: 'wireguard', child: Text('WireGuard')),
                        DropdownMenuItem(value: 'socks', child: Text('SOCKS5 代理')),
                        DropdownMenuItem(value: 'http', child: Text('HTTP 代理')),
                        DropdownMenuItem(value: 'selector', child: Text('策略组: 节点选择 (Selector)')),
                        DropdownMenuItem(value: 'urltest', child: Text('策略组: 自动优选 (URL-Test)')),
                        DropdownMenuItem(value: 'direct', child: Text('基础: 直连 (Direct)')),
                        DropdownMenuItem(value: 'block', child: Text('基础: 拦截 (Block)')),
                        DropdownMenuItem(value: 'dns', child: Text('基础: DNS 解析出站')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tag
                    TextField(
                      controller: tagCtrl,
                      decoration: const InputDecoration(labelText: '节点标签 (Tag)', hintText: '例如: Hong Kong 01'),
                    ),
                    const SizedBox(height: 12),

                    // Proxy Nodes Configuration
                    if (!['selector', 'urltest', 'direct', 'block', 'dns'].contains(selectedType)) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: serverCtrl,
                              decoration: const InputDecoration(labelText: '服务器地址 (Server)', hintText: 'example.com'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: portCtrl,
                              decoration: const InputDecoration(labelText: '端口 (Port)', hintText: '443'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: uuidCtrl,
                        decoration: InputDecoration(
                          labelText: selectedType == 'shadowsocks' ? '密码 (Password)' : '用户 UUID / 密钥',
                          hintText: 'UUID or Password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sniCtrl,
                        decoration: const InputDecoration(labelText: 'TLS SNI / 域名', hintText: 'example.com'),
                      ),
                      if (selectedType == 'vless') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: realityPbkCtrl,
                          decoration: const InputDecoration(labelText: 'Reality 公钥 (Public Key)', hintText: 'Base64 Public Key'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: realitySidCtrl,
                          decoration: const InputDecoration(labelText: 'Reality Short ID', hintText: 'Short ID Hex'),
                        ),
                      ],
                    ],

                    // Group (Selector / URL-Test) Configuration
                    if (['selector', 'urltest'].contains(selectedType)) ...[
                      const Text('包含的子节点列表 (点击添加/移除):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _allOutboundTags.where((t) => t != tagCtrl.text).map((tagItem) {
                          final isSelected = selectedGroupOutbounds.contains(tagItem);
                          return FilterChip(
                            label: Text(tagItem, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
                            selected: isSelected,
                            selectedColor: const Color(0xFF6366F1),
                            backgroundColor: const Color(0xFF0F172A),
                            onSelected: (checked) {
                              setDialogState(() {
                                if (checked) {
                                  selectedGroupOutbounds.add(tagItem);
                                } else {
                                  selectedGroupOutbounds.remove(tagItem);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  final newTag = tagCtrl.text.trim();
                  if (newTag.isEmpty) return;

                  final updated = Map<String, dynamic>.from(data);
                  updated['type'] = selectedType;
                  updated['tag'] = newTag;

                  if (!['selector', 'urltest', 'direct', 'block', 'dns'].contains(selectedType)) {
                    updated['server'] = serverCtrl.text.trim();
                    updated['server_port'] = int.tryParse(portCtrl.text.trim()) ?? 443;
                    if (selectedType == 'shadowsocks') {
                      updated['password'] = uuidCtrl.text.trim();
                      updated['method'] = updated['method'] ?? '2022-blake3-aes-128-gcm';
                    } else {
                      updated['uuid'] = uuidCtrl.text.trim();
                    }

                    if (sniCtrl.text.trim().isNotEmpty || realityPbkCtrl.text.trim().isNotEmpty) {
                      final tlsMap = Map<String, dynamic>.from(updated['tls'] is Map ? updated['tls'] as Map : {});
                      tlsMap['enabled'] = true;
                      if (sniCtrl.text.trim().isNotEmpty) tlsMap['server_name'] = sniCtrl.text.trim();
                      if (realityPbkCtrl.text.trim().isNotEmpty) {
                        tlsMap['reality'] = {
                          'enabled': true,
                          'public_key': realityPbkCtrl.text.trim(),
                          if (realitySidCtrl.text.trim().isNotEmpty) 'short_id': realitySidCtrl.text.trim(),
                        };
                      }
                      updated['tls'] = tlsMap;
                    }
                  } else if (['selector', 'urltest'].contains(selectedType)) {
                    updated['outbounds'] = selectedGroupOutbounds;
                    if (selectedType == 'urltest') {
                      updated['url'] = updated['url'] ?? 'https://www.gstatic.com/generate_204';
                      updated['interval'] = updated['interval'] ?? '3m';
                    }
                  }

                  final current = _outbounds;
                  if (isNew) {
                    current.add(updated);
                  } else {
                    final idx = current.indexWhere((item) => item['tag'] == initial['tag']);
                    if (idx != -1) current[idx] = updated;
                  }
                  _outbounds = current;
                  Navigator.pop(ctx);
                },
                child: const Text('确定保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 2. INBOUNDS TAB
  // ==========================================
  Widget _buildInboundsTab() {
    final list = _inbounds;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '本地入站监听端口与系统代理劫持配置',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () => _showInboundEditDialog(null),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('添加入站', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flight_land_rounded, size: 48, color: const Color(0xFF64748B).withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('暂无入站监听配置', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final ib = list[i];
                      final tag = (ib['tag'] ?? 'Unnamed').toString();
                      final type = (ib['type'] ?? 'mixed').toString();
                      final listen = (ib['listen'] ?? '127.0.0.1').toString();
                      final port = ib['listen_port'] ?? '';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tag, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                                  const SizedBox(height: 2),
                                  Text(
                                    type == 'tun'
                                        ? '虚拟网卡 TUN 模式 (Stack: ${ib['stack'] ?? 'system'}, Auto Route: ${ib['auto_route'] ?? true})'
                                        : '监听地址: $listen:$port',
                                    style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF818CF8)),
                              tooltip: '编辑入站',
                              onPressed: () => _showInboundEditDialog(ib),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
                              tooltip: '删除入站',
                              onPressed: () {
                                final current = _inbounds;
                                current.removeWhere((item) => item['tag'] == ib['tag']);
                                _inbounds = current;
                              },
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

  void _showInboundEditDialog(Map<String, dynamic>? initial) {
    final isNew = initial == null;
    final data = initial != null ? Map<String, dynamic>.from(initial) : <String, dynamic>{
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': '127.0.0.1',
      'listen_port': 2080,
    };

    final tagCtrl = TextEditingController(text: (data['tag'] ?? '').toString());
    final listenCtrl = TextEditingController(text: (data['listen'] ?? '127.0.0.1').toString());
    final portCtrl = TextEditingController(text: (data['listen_port'] ?? 2080).toString());
    String selectedType = (data['type'] ?? 'mixed').toString().toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isNew ? '添加入站监听' : '编辑入站 (${data['tag']})', style: const TextStyle(fontSize: 16)),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: '入站类型 (Type)'),
                    items: const [
                      DropdownMenuItem(value: 'mixed', child: Text('Mixed (HTTP + SOCKS5)')),
                      DropdownMenuItem(value: 'socks', child: Text('SOCKS5')),
                      DropdownMenuItem(value: 'http', child: Text('HTTP')),
                      DropdownMenuItem(value: 'tun', child: Text('TUN 虚拟网卡')),
                      DropdownMenuItem(value: 'direct', child: Text('Direct (直连透明转发)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '入站标签 (Tag)')),
                  if (selectedType != 'tun') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: listenCtrl, decoration: const InputDecoration(labelText: '监听 IP (Listen)'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: portCtrl, decoration: const InputDecoration(labelText: '端口 (Port)'), keyboardType: TextInputType.number)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  final updated = Map<String, dynamic>.from(data);
                  updated['type'] = selectedType;
                  updated['tag'] = tagCtrl.text.trim();
                  if (selectedType != 'tun') {
                    updated['listen'] = listenCtrl.text.trim();
                    updated['listen_port'] = int.tryParse(portCtrl.text.trim()) ?? 2080;
                  }
                  final current = _inbounds;
                  if (isNew) {
                    current.add(updated);
                  } else {
                    final idx = current.indexWhere((item) => item['tag'] == initial['tag']);
                    if (idx != -1) current[idx] = updated;
                  }
                  _inbounds = current;
                  Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. ROUTE & RULES TAB
  // ==========================================
  Widget _buildRouteTab() {
    final rules = _routeRules;
    final ruleSets = _routeRuleSets;
    final route = _routeMap;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Route Global Bar: Final Outbound & Auto Detect Interface
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF818CF8)),
                  const SizedBox(width: 10),
                  const Text('默认出站 (Final):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: (route['final'] ?? (_allOutboundTags.isNotEmpty ? _allOutboundTags.first : 'direct')).toString(),
                    dropdownColor: const Color(0xFF0F172A),
                    underline: const SizedBox(),
                    items: _allOutboundTags.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final r = _routeMap;
                        r['final'] = val;
                        _config['route'] = r;
                        _notifyChange();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  const Text('自动探测网卡:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  Switch(
                    value: route['auto_detect_interface'] ?? true,
                    activeTrackColor: const Color(0xFF6366F1),
                    onChanged: (val) {
                      final r = _routeMap;
                      r['auto_detect_interface'] = val;
                      _config['route'] = r;
                      _notifyChange();
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    onPressed: () => _showRouteRuleEditDialog(null),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('添加路由规则', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Rules List
          Expanded(
            child: ListView(
              children: [
                if (ruleSets.isNotEmpty) ...[
                  const Text('规则集配置 (Rule-Sets):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ruleSets.map((rs) {
                      final tag = rs['tag']?.toString() ?? 'Unnamed';
                      final type = rs['type']?.toString() ?? 'remote';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text('$tag ($type)', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFF8FAFC))),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                final current = _routeRuleSets;
                                current.removeWhere((item) => item['tag'] == tag);
                                _routeRuleSets = current;
                              },
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFF43F5E)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('分流匹配规则 (Rules):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                const SizedBox(height: 8),
                if (rules.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无路由分流规则', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                    ),
                  )
                else
                  ...rules.asMap().entries.map((e) => _buildRouteRuleCard(e.value, e.key, rules.length)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRuleCard(Map<String, dynamic> rule, int index, int total) {
    final outbound = (rule['outbound'] ?? 'direct').toString();
    final action = (rule['action'] ?? 'route').toString();

    // Collect criteria
    final List<String> criteria = [];
    if (rule['rule_set'] != null) criteria.add('rule_set: ${rule['rule_set']}');
    if (rule['domain_suffix'] != null) criteria.add('domain_suffix: ${rule['domain_suffix']}');
    if (rule['domain'] != null) criteria.add('domain: ${rule['domain']}');
    if (rule['domain_keyword'] != null) criteria.add('domain_keyword: ${rule['domain_keyword']}');
    if (rule['ip_cidr'] != null) criteria.add('ip_cidr: ${rule['ip_cidr']}');
    if (rule['geoip'] != null) criteria.add('geoip: ${rule['geoip']}');
    if (rule['geosite'] != null) criteria.add('geosite: ${rule['geosite']}');
    if (rule['process_name'] != null) criteria.add('process_name: ${rule['process_name']}');
    if (rule['protocol'] != null) criteria.add('protocol: ${rule['protocol']}');
    if (rule['clash_mode'] != null) criteria.add('clash_mode: ${rule['clash_mode']}');
    if (rule['ip_is_private'] == true) criteria.add('ip_is_private: true');

    Color outboundColor = const Color(0xFF6366F1);
    if (outbound.toLowerCase() == 'direct') outboundColor = const Color(0xFF10B981);
    if (outbound.toLowerCase() == 'block') outboundColor = const Color(0xFFF43F5E);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // Order Index Badge
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
          ),
          const SizedBox(width: 10),

          // Criteria Summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: criteria.map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(c, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF38BDF8))),
                    );
                  }).toList(),
                ),
                if (criteria.isEmpty)
                  Text('动作: $action', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Target Outbound Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: outboundColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: outboundColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
                Text(outbound, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: outboundColor)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Move Up / Down
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF94A3B8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: index > 0
                ? () {
                    final current = _routeRules;
                    final item = current.removeAt(index);
                    current.insert(index - 1, item);
                    _routeRules = current;
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward_rounded, size: 15, color: Color(0xFF94A3B8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: index < total - 1
                ? () {
                    final current = _routeRules;
                    final item = current.removeAt(index);
                    current.insert(index + 1, item);
                    _routeRules = current;
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 15, color: Color(0xFF818CF8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _showRouteRuleEditDialog(rule, editIndex: index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFF43F5E)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () {
              final current = _routeRules;
              current.removeAt(index);
              _routeRules = current;
            },
          ),
        ],
      ),
    );
  }

  void _showRouteRuleEditDialog(Map<String, dynamic>? initial, {int? editIndex}) {
    final isNew = initial == null;
    final data = initial != null ? Map<String, dynamic>.from(initial) : <String, dynamic>{
      'action': 'route',
      'outbound': _allOutboundTags.isNotEmpty ? _allOutboundTags.first : 'direct',
    };

    String selectedOutbound = (data['outbound'] ?? 'direct').toString();
    if (!_allOutboundTags.contains(selectedOutbound) && _allOutboundTags.isNotEmpty) {
      selectedOutbound = _allOutboundTags.first;
    }

    String selectedCriterion = 'rule_set';
    if (data['domain_suffix'] != null) selectedCriterion = 'domain_suffix';
    if (data['domain'] != null) selectedCriterion = 'domain';
    if (data['ip_cidr'] != null) selectedCriterion = 'ip_cidr';
    if (data['geoip'] != null) selectedCriterion = 'geoip';
    if (data['geosite'] != null) selectedCriterion = 'geosite';
    if (data['process_name'] != null) selectedCriterion = 'process_name';
    if (data['clash_mode'] != null) selectedCriterion = 'clash_mode';

    final valueCtrl = TextEditingController(
      text: (data[selectedCriterion] is List)
          ? (data[selectedCriterion] as List).join(', ')
          : (data[selectedCriterion] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isNew ? '添加路由分流规则' : '编辑路由规则', style: const TextStyle(fontSize: 16)),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCriterion,
                    decoration: const InputDecoration(labelText: '匹配类型 (Criterion)'),
                    items: const [
                      DropdownMenuItem(value: 'rule_set', child: Text('规则集 (rule_set: geoip-cn 等)')),
                      DropdownMenuItem(value: 'domain_suffix', child: Text('域名后缀 (domain_suffix)')),
                      DropdownMenuItem(value: 'domain', child: Text('精确域名 (domain)')),
                      DropdownMenuItem(value: 'ip_cidr', child: Text('IP 地址段 (ip_cidr)')),
                      DropdownMenuItem(value: 'geosite', child: Text('GeoSite 标签')),
                      DropdownMenuItem(value: 'geoip', child: Text('GeoIP 国家/地区代码')),
                      DropdownMenuItem(value: 'process_name', child: Text('应用进程名称 (process_name)')),
                      DropdownMenuItem(value: 'clash_mode', child: Text('Clash 代理模式 (Direct/Global/Rule)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedCriterion = val;
                          valueCtrl.text = (data[val] is List) ? (data[val] as List).join(', ') : (data[val] ?? '').toString();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueCtrl,
                    decoration: const InputDecoration(
                      labelText: '匹配值 (多个值以逗号分隔)',
                      hintText: '例如: google.com, youtube.com 或 geoip-cn',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOutbound,
                    decoration: const InputDecoration(labelText: '目标出站 (Outbound)'),
                    items: _allOutboundTags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedOutbound = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  final rawVal = valueCtrl.text.trim();
                  final values = rawVal.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                  final updated = <String, dynamic>{
                    'action': 'route',
                    'outbound': selectedOutbound,
                  };
                  if (values.isNotEmpty) {
                    updated[selectedCriterion] = values.length == 1 ? values.first : values;
                  }

                  final current = _routeRules;
                  if (isNew) {
                    current.add(updated);
                  } else if (editIndex != null && editIndex < current.length) {
                    current[editIndex] = updated;
                  }
                  _routeRules = current;
                  Navigator.pop(ctx);
                },
                child: const Text('保存规则'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 4. DNS TAB
  // ==========================================
  Widget _buildDnsTab() {
    final dns = _dnsMap;
    final servers = _dnsServers;
    final rules = _dnsRules;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // DNS Global Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.dns_rounded, size: 18, color: Color(0xFF818CF8)),
                  const SizedBox(width: 10),
                  const Text('解析策略 (Strategy):', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: (dns['strategy'] ?? 'prefer_ipv4').toString(),
                    dropdownColor: const Color(0xFF0F172A),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'prefer_ipv4', child: Text('优先 IPv4 (prefer_ipv4)')),
                      DropdownMenuItem(value: 'prefer_ipv6', child: Text('优先 IPv6 (prefer_ipv6)')),
                      DropdownMenuItem(value: 'ipv4_only', child: Text('仅 IPv4 (ipv4_only)')),
                      DropdownMenuItem(value: 'ipv6_only', child: Text('仅 IPv6 (ipv6_only)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        final d = _dnsMap;
                        d['strategy'] = val;
                        _config['dns'] = d;
                        _notifyChange();
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                    onPressed: () => _showDnsServerEditDialog(null),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('添加 DNS 服务器', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // DNS Servers & Rules List
          Expanded(
            child: ListView(
              children: [
                const Text('DNS 上游解析服务器 (Servers):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                const SizedBox(height: 8),
                if (servers.isEmpty)
                  const Text('暂无 DNS 服务器配置', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                else
                  ...servers.map((s) => _buildDnsServerCard(s)),
                const SizedBox(height: 20),
                const Text('DNS 分流规则 (Rules):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                const SizedBox(height: 8),
                if (rules.isEmpty)
                  const Text('暂无 DNS 分流规则', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                else
                  ...rules.map((r) => _buildDnsRuleCard(r)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsServerCard(Map<String, dynamic> server) {
    final tag = (server['tag'] ?? 'Unnamed').toString();
    final address = (server['address'] ?? '').toString();
    final detour = (server['detour'] ?? 'direct').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
            ),
            child: Text(tag, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFC084FC))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(address, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFFF8FAFC))),
          ),
          Text('出站通道: $detour', style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
            onPressed: () {
              final current = _dnsServers;
              current.removeWhere((item) => item['tag'] == server['tag']);
              _dnsServers = current;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDnsRuleCard(Map<String, dynamic> rule) {
    final server = (rule['server'] ?? '').toString();
    final ruleSet = rule['rule_set']?.toString();
    final domain = rule['domain_suffix']?.toString() ?? rule['domain']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ruleSet != null ? 'rule_set: $ruleSet' : (domain != null ? 'domain: $domain' : rule.toString()),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF38BDF8)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Text('-> $server', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF43F5E)),
            onPressed: () {
              final current = _dnsRules;
              current.remove(rule);
              _dnsRules = current;
            },
          ),
        ],
      ),
    );
  }

  void _showDnsServerEditDialog(Map<String, dynamic>? initial) {
    final tagCtrl = TextEditingController(text: initial?['tag']?.toString() ?? 'remote-dns');
    final addrCtrl = TextEditingController(text: initial?['address']?.toString() ?? 'tls://1.1.1.1');
    String selectedDetour = (initial?['detour'] ?? (_allOutboundTags.isNotEmpty ? _allOutboundTags.first : 'direct')).toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 DNS 服务器', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tagCtrl, decoration: const InputDecoration(labelText: '服务器标签 (Tag)', hintText: '例如: remote-dns')),
              const SizedBox(height: 12),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'DNS 地址 (Address)', hintText: 'tls://1.1.1.1 或 223.5.5.5')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _allOutboundTags.contains(selectedDetour) ? selectedDetour : (_allOutboundTags.isNotEmpty ? _allOutboundTags.first : null),
                decoration: const InputDecoration(labelText: '出站转发 Detour (Outbound)'),
                items: _allOutboundTags.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) selectedDetour = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            onPressed: () {
              final newServer = {
                'tag': tagCtrl.text.trim(),
                'address': addrCtrl.text.trim(),
                'detour': selectedDetour,
              };
              final current = _dnsServers;
              current.add(newServer);
              _dnsServers = current;
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. GENERAL & LOG TAB
  // ==========================================
  Widget _buildGeneralTab() {
    final log = _logMap;
    final clashApi = (_config['experimental'] is Map && (_config['experimental'] as Map)['clash_api'] is Map)
        ? Map<String, dynamic>.from((_config['experimental'] as Map)['clash_api'] as Map)
        : <String, dynamic>{};

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('日志输出设置 (Log):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('日志等级 (Level):', style: TextStyle(fontSize: 13)),
                    DropdownButton<String>(
                      value: (log['level'] ?? 'info').toString(),
                      dropdownColor: const Color(0xFF0F172A),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'trace', child: Text('Trace (最详尽)')),
                        DropdownMenuItem(value: 'debug', child: Text('Debug (调试)')),
                        DropdownMenuItem(value: 'info', child: Text('Info (标准信息)')),
                        DropdownMenuItem(value: 'warn', child: Text('Warn (警告)')),
                        DropdownMenuItem(value: 'error', child: Text('Error (仅错误)')),
                        DropdownMenuItem(value: 'fatal', child: Text('Fatal (严重致命)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          final l = _logMap;
                          l['level'] = val;
                          _logMap = l;
                        }
                      },
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('显示时间戳 (Timestamp):', style: TextStyle(fontSize: 13)),
                    Switch(
                      value: log['timestamp'] ?? true,
                      activeTrackColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        final l = _logMap;
                        l['timestamp'] = val;
                        _logMap = l;
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Clash API 外部控制器 (Clash API):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('控制器监听地址 (external_controller):', style: TextStyle(fontSize: 13)),
                    Text(
                      clashApi['external_controller']?.toString() ?? '127.0.0.1:9090',
                      style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('默认运行模式 (default_mode):', style: TextStyle(fontSize: 13)),
                    Text(
                      clashApi['default_mode']?.toString() ?? 'Rule',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
