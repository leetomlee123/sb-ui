import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/engine/config_generator.dart';
import '../../core/engine/mixin_engine.dart';
import '../../core/engine/script_engine.dart';
import '../../core/models/profile.dart';
import '../../core/providers/profiles_provider.dart';
import '../../core/providers/settings_provider.dart';

class MixinScriptDialog extends ConsumerStatefulWidget {
  const MixinScriptDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const MixinScriptDialog(),
    );
  }

  @override
  ConsumerState<MixinScriptDialog> createState() => _MixinScriptDialogState();
}

class _MixinScriptDialogState extends ConsumerState<MixinScriptDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _mixinController;
  late TextEditingController _scriptController;

  late bool _mixinEnabled;
  late bool _scriptEnabled;

  // Dry-run test state
  bool _isRunningTest = false;
  List<String> _testLogs = [];
  Duration _testDuration = Duration.zero;
  String _testOutputJson = '';
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final settings = ref.read(settingsProvider);

    _mixinEnabled = settings.mixinEnabled;
    _scriptEnabled = settings.scriptEnabled;

    _mixinController = TextEditingController(text: settings.mixinContent);
    _scriptController = TextEditingController(text: settings.scriptContent);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mixinController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final current = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).updateSettings(
      current.copyWith(
        mixinEnabled: _mixinEnabled,
        mixinContent: _mixinController.text,
        scriptEnabled: _scriptEnabled,
        scriptContent: _scriptController.text,
      ),
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('混入与预处理脚本配置已保存'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _runDryRunTest() {
    setState(() {
      _isRunningTest = true;
      _testLogs = [];
      _testOutputJson = '';
    });

    final stopwatch = Stopwatch()..start();
    final logs = <String>[];

    try {
      final profilesState = ref.read(profilesProvider);
      final activeProfile = profilesState.profiles.firstWhere(
        (p) => p.id == _selectedProfileId,
        orElse: () => profilesState.activeProfile ?? (profilesState.profiles.isNotEmpty
            ? profilesState.profiles.first
            : Profile(
                id: 'sample',
                name: '内置示例配置',
                type: ProfileType.local,
                updatedAt: DateTime.now(),
                rawConfig: '',
              )),
      );

      logs.add('准备测试基底配置: [${activeProfile.name}]');

      // 1. Generate base config
      final settings = ref.read(settingsProvider);
      final baseConfig = ConfigGenerator.generate(
        settings: settings.copyWith(
          mixinEnabled: false,
          scriptEnabled: false,
        ),
        parsedOutbounds: [
          {'type': 'direct', 'tag': 'direct'},
          {'type': 'block', 'tag': 'block'},
          {'type': 'shadowsocks', 'tag': '🇭🇰 香港 01 [优质BGP]', 'server': 'hk01.example.com', 'server_port': 8388, 'method': 'aes-128-gcm', 'password': 'pass'},
          {'type': 'vless', 'tag': '🇯🇵 日本 01 [专线]', 'server': 'jp01.example.com', 'server_port': 443, 'uuid': '00000000-0000-0000-0000-000000000000'},
          {'type': 'vmess', 'tag': '🇺🇸 美国 01 [官网公告/剩余流量100G]', 'server': 'us01.example.com', 'server_port': 443, 'uuid': '00000000-0000-0000-0000-000000000000'},
        ],
      );

      Map<String, dynamic> current = baseConfig;

      // 2. Test Mixin
      if (_mixinEnabled) {
        logs.add('--- 执行混入 (Mixin) ---');
        final mixinRes = MixinEngine.apply(current, _mixinController.text);
        logs.addAll(mixinRes.logs);
        if (!mixinRes.success) {
          throw Exception(mixinRes.error ?? '混入合并失败');
        }
        current = mixinRes.config;
      } else {
        logs.add('混入 (Mixin) 未启用，跳过');
      }

      // 3. Test Script
      if (_scriptEnabled) {
        logs.add('--- 执行预处理脚本 (Script) ---');
        final scriptRes = ScriptEngine.execute(
          current,
          _scriptController.text,
          profileName: activeProfile.name,
        );
        logs.addAll(scriptRes.logs);
        if (!scriptRes.success) {
          throw Exception(scriptRes.error ?? '脚本执行失败');
        }
        current = scriptRes.outputConfig;
      } else {
        logs.add('预处理脚本 (Script) 未启用，跳过');
      }

      stopwatch.stop();
      setState(() {
        _isRunningTest = false;
        _testLogs = logs;
        _testDuration = stopwatch.elapsed;
        _testOutputJson = const JsonEncoder.withIndent('  ').convert(current);
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _isRunningTest = false;
        _testLogs = logs..add('测试终止: $e');
        _testDuration = stopwatch.elapsed;
      });
    }
  }

  void _loadMixinTemplate(String key) {
    switch (key) {
      case 'dns':
        _mixinController.text = '''# 声明式 DNS 混入 (NextDNS / 自定义 DoH)
dns:
  servers:
    - tag: custom-doh
      address: https://dns.nextdns.io/xxxxxx
      detour: proxy
    - tag: ali-dns
      address: 223.5.5.5
      detour: direct
  rules:
    - domain_suffix:
        - steamserver.net
        - bilibili.com
      server: ali-dns
''';
        break;
      case 'rules':
        _mixinController.text = '''# 优先分流规则混入 (置顶匹配)
route:
  rules:
    - domain_suffix:
        - openai.com
        - anthropic.com
        - copilot.microsoft.com
      outbound: proxy
    - ip_cidr:
        - 10.0.0.0/8
        - 192.168.0.0/16
      outbound: direct
''';
        break;
      case 'nic':
        _mixinController.text = '''# 物理网卡 / Wi-Fi 出口绑定混入
outbounds:
  - type: direct
    tag: 办公室网卡直连
    bind_interface: Wi-Fi
  - type: direct
    tag: USB有线直连
    bind_interface: eth0
''';
        break;
      case 'tun':
        _mixinController.text = '''# TUN 虚拟网卡堆栈覆盖
inbounds:
  - type: tun
    tag: tun-in
    stack: system
    auto_route: true
    strict_route: true
''';
        break;
    }
  }

  void _loadScriptTemplate(String key) {
    switch (key) {
      case 'cleaner':
        _scriptController.text = r'''function main(config, profileName) {
  console.log("执行节点清洗脚本:", profileName);
  const invalidKeywords = ["官网", "剩余", "流量", "重置", "到期", "公告", "群", "http", "aff"];
  if (Array.isArray(config.outbounds)) {
    config.outbounds = config.outbounds.filter(node => {
      if (node.type === "selector" || node.type === "urltest" || node.type === "direct") return true;
      const tag = node.tag || "";
      for (const kw of invalidKeywords) {
        if (tag.toLowerCase().includes(kw)) {
          console.log("移除无用节点:", tag);
          return false;
        }
      }
      return true;
    });
  }
  return config;
}
''';
        break;
      case 'whitelist':
        _scriptController.text = r'''function main(config, profileName) {
  console.log("执行白名单注入脚本");
  if (config.route && Array.isArray(config.route.rules)) {
    config.route.rules.unshift({
      domain_suffix: ["oa.internal", "local.corp", "company.com"],
      outbound: "direct"
    });
    console.log("注入内部域名直连");
  }
  return config;
}
''';
        break;
      case 'fallback':
        _scriptController.text = r'''function main(config, profileName) {
  console.log("自动注入 URL-Test 低延迟故障转移组");
  if (Array.isArray(config.outbounds)) {
    const nodeTags = config.outbounds
      .filter(n => n.type !== "selector" && n.type !== "urltest" && n.type !== "direct" && n.type !== "block")
      .map(n => n.tag);

    if (nodeTags.length > 0) {
      config.outbounds.unshift({
        type: "urltest",
        tag: "⚡ 自动低延迟切换",
        outbounds: nodeTags,
        url: "https://www.gstatic.com/generate_204",
        interval: "3m"
      });
      console.log("已注入自动测速优选组");
    }
  }
  return config;
}
''';
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dialogBg = isDark ? const Color(0xFF070A12) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0E1424) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final codeEditorBg = isDark ? const Color(0xFF080C16) : Colors.white;

    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.95).clamp(650.0, 1150.0);
    final dialogHeight = (size.height * 0.90).clamp(500.0, 850.0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Top Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0E1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF818CF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '混入与预处理脚本 (Mixin & Scripts)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '支持声明式 YAML/JSON 全局配置混入与 JavaScript 动态编排预处理',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // TabBar Row
            Container(
              color: isDark ? const Color(0xFF070A12) : const Color(0xFFF1F5F9),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: textSecondary,
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.extension_rounded, size: 16), text: '全局混入 (Mixin)'),
                  Tab(icon: Icon(Icons.code_rounded, size: 16), text: '预处理脚本 (Script)'),
                  Tab(icon: Icon(Icons.play_circle_outline_rounded, size: 16), text: '实时测试 (Dry Run)'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Mixin
                  _buildMixinTab(cardBg, borderCol, textPrimary, textSecondary, codeEditorBg),
                  // Tab 2: Script
                  _buildScriptTab(cardBg, borderCol, textPrimary, textSecondary, codeEditorBg),
                  // Tab 3: Dry-Run Test
                  _buildDryRunTab(cardBg, borderCol, textPrimary, textSecondary, codeEditorBg),
                ],
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0E1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '混入和脚本将在每次启动内核或切换节点时自动执行',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('保存配置', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMixinTab(Color cardBg, Color borderCol, Color textPrimary, Color textSecondary, Color codeEditorBg) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Switch(
                  value: _mixinEnabled,
                  activeTrackColor: const Color(0xFF6366F1),
                  onChanged: (val) => setState(() => _mixinEnabled = val),
                ),
                const SizedBox(width: 8),
                Text(
                  _mixinEnabled ? '混入引擎已启用 (Active)' : '混入引擎已关闭 (Disabled)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _mixinEnabled ? const Color(0xFF10B981) : textSecondary),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '载入常用混入模板',
                  onSelected: _loadMixinTemplate,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'dns', child: Text('🌐 自定义 NextDNS / DoH 解析')),
                    PopupMenuItem(value: 'rules', child: Text('🛡️ AI 智能与内网直连分流规则')),
                    PopupMenuItem(value: 'nic', child: Text('📶 物理网卡 / Wi-Fi 出口绑定')),
                    PopupMenuItem(value: 'tun', child: Text('🎛️ TUN 虚拟网卡堆栈覆盖')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dashboard_customize_rounded, size: 14, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text('载入混入模板', style: TextStyle(fontSize: 12, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF818CF8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: '复制混入代码',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _mixinController.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('混入代码已复制到剪贴板')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Code Editor
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: codeEditorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              child: TextField(
                controller: _mixinController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: '# 在此输入 YAML 或 JSON 格式的全局混入配置...',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptTab(Color cardBg, Color borderCol, Color textPrimary, Color textSecondary, Color codeEditorBg) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                Switch(
                  value: _scriptEnabled,
                  activeTrackColor: const Color(0xFF6366F1),
                  onChanged: (val) => setState(() => _scriptEnabled = val),
                ),
                const SizedBox(width: 8),
                Text(
                  _scriptEnabled ? '脚本预处理已启用 (Active)' : '脚本预处理已关闭 (Disabled)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _scriptEnabled ? const Color(0xFF10B981) : textSecondary),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: '载入常用脚本模板',
                  onSelected: _loadScriptTemplate,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'cleaner', child: Text('🧹 广告/无效节点自动过滤清洗')),
                    PopupMenuItem(value: 'whitelist', child: Text('🏢 公司内网与服务直连白名单')),
                    PopupMenuItem(value: 'fallback', child: Text('⚡ 自动测速与低延迟故障转移组')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.javascript_rounded, size: 16, color: Color(0xFF818CF8)),
                        SizedBox(width: 6),
                        Text('载入脚本模板', style: TextStyle(fontSize: 12, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                        Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF818CF8)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: '复制脚本代码',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _scriptController.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('脚本代码已复制到剪贴板')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Code Editor
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: codeEditorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              child: TextField(
                controller: _scriptController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: '// 在此编写 JavaScript 预处理函数 main(config, profileName) { return config; }',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDryRunTab(Color cardBg, Color borderCol, Color textPrimary, Color textSecondary, Color codeEditorBg) {
    final profiles = ref.watch(profilesProvider).profiles;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded, size: 18, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text('测试目标订阅/配置:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedProfileId ?? (profiles.isNotEmpty ? profiles.first.id : null),
                  dropdownColor: cardBg,
                  underline: const SizedBox(),
                  items: profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: TextStyle(fontSize: 12.5, color: textPrimary)))).toList(),
                  onChanged: (val) => setState(() => _selectedProfileId = val),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _isRunningTest ? null : _runDryRunTest,
                  icon: _isRunningTest
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(_isRunningTest ? '执行中...' : '运行测试 (Dry Run)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Result Viewport (Logs on Left/Top, Transformed Output on Right/Bottom)
          Expanded(
            child: Row(
              children: [
                // Execution Logs Panel
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: codeEditorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF818CF8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '执行日志 (Console)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_testDuration > Duration.zero)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${_testDuration.inMilliseconds}ms', style: const TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontFamily: 'monospace')),
                              ),
                          ],
                        ),
                        const Divider(height: 16),
                        Expanded(
                          child: _testLogs.isEmpty
                              ? Center(
                                  child: Text('点击上方“运行测试”验证混入与脚本', style: TextStyle(fontSize: 12, color: textSecondary)),
                                )
                              : ListView.separated(
                                  itemCount: _testLogs.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                                  itemBuilder: (ctx, i) {
                                    final log = _testLogs[i];
                                    final isError = log.contains('异常') || log.contains('错误') || log.contains('失败');
                                    return Text(
                                      log,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11.5,
                                        color: isError ? const Color(0xFFF43F5E) : (log.startsWith('[Console]') ? const Color(0xFF38BDF8) : textPrimary),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Output JSON Preview Panel
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: codeEditorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.data_object_rounded, size: 16, color: Color(0xFF34D399)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '配置预览 (JSON Output)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_testOutputJson.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 15),
                                tooltip: '复制生成的 JSON',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _testOutputJson));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制生成的 JSON 配置')));
                                },
                              ),
                          ],
                        ),
                        const Divider(height: 16),
                        Expanded(
                          child: _testOutputJson.isEmpty
                              ? Center(
                                  child: Text('暂无测试输出', style: TextStyle(fontSize: 12, color: textSecondary)),
                                )
                              : SingleChildScrollView(
                                  child: SelectableText(
                                    _testOutputJson,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
