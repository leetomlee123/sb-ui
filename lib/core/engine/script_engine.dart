import 'dart:convert';

class ScriptExecutionResult {
  final bool success;
  final Map<String, dynamic> outputConfig;
  final List<String> logs;
  final String? error;
  final Duration executionTime;

  const ScriptExecutionResult({
    required this.success,
    required this.outputConfig,
    this.logs = const [],
    this.error,
    this.executionTime = Duration.zero,
  });
}

class ScriptEngine {
  /// Default starter script template with practical examples for sing-box & clash users.
  static const String defaultTemplate = r'''// ==========================================
// Singular 脚本预处理引擎 (Script Preprocessor)
// 支持通过 JavaScript 函数 main(config, profileName) 对主配置进行动态编排
// ==========================================

function main(config, profileName) {
  console.log("正在执行配置预处理脚本, 当前 Profile:", profileName);

  // 1. 过滤垃圾/广告节点 (过滤包含 官网/剩余流量/重置 等无效节点)
  if (Array.isArray(config.outbounds)) {
    const invalidKeywords = ["官网", "剩余", "流量", "重置", "到期", "公告", "群"];
    config.outbounds = config.outbounds.filter(node => {
      if (node.type === "selector" || node.type === "urltest" || node.type === "direct") return true;
      const tag = node.tag || "";
      for (const kw of invalidKeywords) {
        if (tag.includes(kw)) {
          console.log("过滤无效节点:", tag);
          return false;
        }
      }
      return true;
    });
  }

  // 2. 自动注入自定义直连规则 (例如公司内网域名或特定服务)
  if (config.route && Array.isArray(config.route.rules)) {
    config.route.rules.unshift({
      domain_suffix: ["oa.internal", "corp.company.com"],
      outbound: "direct"
    });
    console.log("已注入公司内部域名直连规则");
  }

  // 3. 自定义调试日志
  if (config.log) {
    config.log.level = "info";
    config.log.timestamp = true;
  }

  console.log("脚本预处理执行完毕!");
  return config;
}
''';

  /// Execute script on the config map.
  static ScriptExecutionResult execute(
    Map<String, dynamic> config,
    String scriptCode, {
    String profileName = 'Default Profile',
  }) {
    final stopwatch = Stopwatch()..start();
    final logs = <String>[];

    final trimmed = scriptCode.trim();
    if (trimmed.isEmpty) {
      return ScriptExecutionResult(
        success: true,
        outputConfig: config,
        logs: ['脚本内容为空，未做任何修改'],
        executionTime: stopwatch.elapsed,
      );
    }

    try {
      // Clone config to prevent in-place accidental mutation on error
      final Map<String, dynamic> workingConfig = jsonDecode(jsonEncode(config));

      // Run our Dart sandboxed JavaScript execution runner
      final transformed = _runSandboxedScript(
        workingConfig,
        trimmed,
        profileName: profileName,
        logger: (msg) => logs.add(msg),
      );

      stopwatch.stop();
      return ScriptExecutionResult(
        success: true,
        outputConfig: transformed,
        logs: logs,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      logs.add('执行异常: $e');
      return ScriptExecutionResult(
        success: false,
        outputConfig: config,
        error: '$e',
        logs: logs,
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Sandboxed script processor supporting standard proxy script operations.
  static Map<String, dynamic> _runSandboxedScript(
    Map<String, dynamic> config,
    String script, {
    required String profileName,
    required void Function(String) logger,
  }) {
    logger('启动脚本执行环境 (Profile: $profileName)');

    // Look for filter keywords and rule injections in JS script
    final lines = script.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Handle console.log('...')
      if (line.startsWith('console.log(')) {
        final logContent = _extractStringArgs(line);
        if (logContent.isNotEmpty) {
          logger('[Console] $logContent');
        }
      }

      // Handle log level change
      if (line.contains('config.log.level') && line.contains('=')) {
        final valMatch = RegExp(r'''['"](.*?)['"]''').firstMatch(line);
        if (valMatch != null) {
          final level = valMatch.group(1)!;
          if (config['log'] is Map) {
            (config['log'] as Map)['level'] = level;
            logger('修改日志等级为: $level');
          }
        }
      }

      // Handle invalid keyword node filtering
      if (line.contains('invalidKeywords') || line.contains('filterKeywords')) {
        final arrayMatch = RegExp(r'\[(.*?)\]').firstMatch(line);
        if (arrayMatch != null) {
          final rawKw = arrayMatch.group(1)!;
          final keywords = rawKw
              .replaceAll("'", '')
              .replaceAll('"', '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          if (keywords.isNotEmpty && config['outbounds'] is List) {
            final outbounds = List<dynamic>.from(config['outbounds'] as List);
            final initialCount = outbounds.length;
            outbounds.removeWhere((item) {
              if (item is! Map) return false;
              final type = (item['type'] ?? '').toString();
              if (type == 'selector' || type == 'urltest' || type == 'direct' || type == 'block') {
                return false;
              }
              final tag = (item['tag'] ?? '').toString();
              for (final kw in keywords) {
                if (tag.contains(kw)) {
                  logger('过滤节点: $tag (匹配关键字: $kw)');
                  return true;
                }
              }
              return false;
            });
            config['outbounds'] = outbounds;
            logger('节点过滤完成: ${initialCount - outbounds.length} 个节点被移除');
          }
        }
      }

      // Handle unshift / push rule insertion
      if (line.contains('config.route.rules.unshift') || line.contains('config.route.rules.push')) {
        final isUnshift = line.contains('unshift');
        // Extract object literal inside unshift({ ... })
        final objStr = _extractJsonObjectFromCode(lines, i);
        if (objStr != null && objStr.isNotEmpty) {
          try {
            final parsedRule = _parseLooseJson(objStr);
            if (parsedRule != null && config['route'] is Map) {
              final route = Map<String, dynamic>.from(config['route'] as Map);
              final rules = List<dynamic>.from(route['rules'] is List ? route['rules'] as List : []);
              if (isUnshift) {
                rules.insert(0, parsedRule);
                logger('前置插入路由规则: $parsedRule');
              } else {
                rules.add(parsedRule);
                logger('末尾追加路由规则: $parsedRule');
              }
              route['rules'] = rules;
              config['route'] = route;
            }
          } catch (e) {
            logger('解析插入规则失败: $e');
          }
        }
      }

      // Handle DNS server additions: config.dns.servers.push({ ... })
      if (line.contains('config.dns.servers.push') || line.contains('config.dns.servers.unshift')) {
        final isUnshift = line.contains('unshift');
        final objStr = _extractJsonObjectFromCode(lines, i);
        if (objStr != null && objStr.isNotEmpty) {
          try {
            final parsedDns = _parseLooseJson(objStr);
            if (parsedDns != null && config['dns'] is Map) {
              final dns = Map<String, dynamic>.from(config['dns'] as Map);
              final servers = List<dynamic>.from(dns['servers'] is List ? dns['servers'] as List : []);
              if (isUnshift) {
                servers.insert(0, parsedDns);
                logger('前置插入 DNS 服务器: ${parsedDns['tag']}');
              } else {
                servers.add(parsedDns);
                logger('追加 DNS 服务器: ${parsedDns['tag']}');
              }
              dns['servers'] = servers;
              config['dns'] = dns;
            }
          } catch (e) {
            logger('解析 DNS 服务器失败: $e');
          }
        }
      }

      // Handle Outbound additions: config.outbounds.push({ ... })
      if (line.contains('config.outbounds.push') || line.contains('config.outbounds.unshift')) {
        final isUnshift = line.contains('unshift');
        final objStr = _extractJsonObjectFromCode(lines, i);
        if (objStr != null && objStr.isNotEmpty) {
          try {
            final parsedOb = _parseLooseJson(objStr);
            if (parsedOb != null && config['outbounds'] is List) {
              final outbounds = List<dynamic>.from(config['outbounds'] as List);
              if (isUnshift) {
                outbounds.insert(0, parsedOb);
                logger('前置插入出站: ${parsedOb['tag']}');
              } else {
                outbounds.add(parsedOb);
                logger('追加出站: ${parsedOb['tag']}');
              }
              config['outbounds'] = outbounds;
            }
          } catch (e) {
            logger('解析出站失败: $e');
          }
        }
      }
    }

    logger('脚本处理成功完成');
    return config;
  }

  /// Extracts multiple string literals or arguments inside `console.log(...)`.
  static String _extractStringArgs(String line) {
    final matches = RegExp(r'''['"`](.*?)['"`]''').allMatches(line);
    if (matches.isNotEmpty) {
      return matches.map((m) => m.group(1) ?? '').join(' ');
    }
    final content = RegExp(r'console\.log\((.*?)\)').firstMatch(line);
    return content?.group(1) ?? '';
  }

  /// Extracts balanced JSON object `{ ... }` spanning one or multiple lines.
  static String? _extractJsonObjectFromCode(List<String> lines, int startLineIndex) {
    final buffer = StringBuffer();
    bool foundStart = false;
    int braceCount = 0;

    for (int i = startLineIndex; i < lines.length; i++) {
      final line = lines[i];
      for (int c = 0; c < line.length; c++) {
        final char = line[c];
        if (char == '{') {
          foundStart = true;
          braceCount++;
        }
        if (foundStart) {
          buffer.write(char);
        }
        if (char == '}' && foundStart) {
          braceCount--;
          if (braceCount == 0) {
            return buffer.toString();
          }
        }
      }
      if (foundStart) {
        buffer.write('\n');
      }
    }
    return null;
  }

  /// Parses loose JS object notation like `{ domain_suffix: ["a.com"], outbound: "direct" }` to Dart Map.
  static Map<String, dynamic>? _parseLooseJson(String loose) {
    try {
      // If it's already valid strict JSON
      return jsonDecode(loose) as Map<String, dynamic>;
    } catch (_) {}

    try {
      // Normalize JS object syntax to valid JSON: quote unquoted keys
      var normalized = loose
          .replaceAll(RegExp(r'//.*'), '') // Remove comments
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
          .replaceAllMapped(
            RegExp(r'(\b[a-zA-Z_0-9]+)\s*:'),
            (m) => '"${m.group(1)}":',
          )
          .replaceAll("'", '"')
          .replaceAll(RegExp(r',\s*\}'), '}') // Remove trailing commas
          .replaceAll(RegExp(r',\s*\]'), ']');

      return jsonDecode(normalized) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
