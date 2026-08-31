import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../process/singbox_process_manager.dart';

enum ConfigIssueSeverity {
  error,
  warning,
  info,
}

class ConfigIssue {
  final ConfigIssueSeverity severity;
  final String message;
  final int? line;
  final int? column;
  final int? offset;
  final String? suggestion;

  const ConfigIssue({
    required this.severity,
    required this.message,
    this.line,
    this.column,
    this.offset,
    this.suggestion,
  });

  bool get isError => severity == ConfigIssueSeverity.error;
  bool get isWarning => severity == ConfigIssueSeverity.warning;

  @override
  String toString() {
    final loc = line != null ? ' [行 $line${column != null ? ', 列 $column' : ''}]' : '';
    return '${severity.name.toUpperCase()}$loc: $message';
  }
}

class ConfigValidationResult {
  final bool isValid;
  final List<ConfigIssue> issues;
  final String? kernelOutput;
  final Duration checkDuration;

  const ConfigValidationResult({
    required this.isValid,
    required this.issues,
    this.kernelOutput,
    this.checkDuration = Duration.zero,
  });

  bool get hasErrors => issues.any((i) => i.isError);
  bool get hasWarnings => issues.any((i) => i.isWarning);
  List<ConfigIssue> get errors => issues.where((i) => i.isError).toList();
  List<ConfigIssue> get warnings => issues.where((i) => i.isWarning).toList();

  String get summary {
    if (isValid && issues.isEmpty) {
      return '配置结构完整，校验通过';
    }
    final errCount = errors.length;
    final warnCount = warnings.length;
    final parts = <String>[];
    if (errCount > 0) parts.add('$errCount 项错误');
    if (warnCount > 0) parts.add('$warnCount 项警告');
    return parts.join(', ');
  }
}

class SingboxConfigValidator {
  static const Set<String> _validInboundTypes = {
    'mixed',
    'socks',
    'http',
    'tun',
    'tproxy',
    'redirect',
    'direct',
    'shadowsocks',
    'vmess',
    'vless',
    'trojan',
    'hysteria2',
    'tuic',
    'wireguard',
  };

  static const Set<String> _validOutboundTypes = {
    'direct',
    'block',
    'dns',
    'selector',
    'urltest',
    'loadbalance',
    'shadowsocks',
    'vmess',
    'vless',
    'trojan',
    'hysteria2',
    'hy2',
    'tuic',
    'wireguard',
    'socks',
    'http',
    'ssh',
    'tor',
  };

  static const Set<String> _builtInOutboundTags = {
    'direct',
    'block',
    'bypass',
    'dns-out',
    'dns',
  };

  /// Synchronous fast static and semantic linter (runs as user types).
  static ConfigValidationResult lint(String content) {
    final issues = <ConfigIssue>[];
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      issues.add(const ConfigIssue(
        severity: ConfigIssueSeverity.error,
        message: '配置内容不能为空',
      ));
      return ConfigValidationResult(isValid: false, issues: issues);
    }

    // 1. JSON Format & Syntax Validation
    Map<String, dynamic> config;
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        issues.add(const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message: '配置根节点必须是 JSON Object 对象 (键值对字典)',
          line: 1,
          column: 1,
        ));
        return ConfigValidationResult(isValid: false, issues: issues);
      }
      config = Map<String, dynamic>.from(decoded);
    } on FormatException catch (e) {
      final offset = e.offset ?? 0;
      final textBefore = content.substring(0, min(offset, content.length));
      final lines = textBefore.split('\n');
      final line = lines.length;
      final col = lines.last.length + 1;

      issues.add(ConfigIssue(
        severity: ConfigIssueSeverity.error,
        message: 'JSON 语法解析错误: ${e.message}',
        line: line,
        column: col,
        offset: offset,
        suggestion: '请检查标点符号、闭合括号或缺少逗号',
      ));
      return ConfigValidationResult(isValid: false, issues: issues);
    } catch (e) {
      issues.add(ConfigIssue(
        severity: ConfigIssueSeverity.error,
        message: '解析异常: $e',
      ));
      return ConfigValidationResult(isValid: false, issues: issues);
    }

    // 2. Semantic Checks: Outbounds & Duplicate Tags
    final outboundTags = <String>{};
    final List<Map<String, dynamic>> outboundsList = [];

    if (config['outbounds'] != null) {
      if (config['outbounds'] is! List) {
        issues.add(const ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message: '`outbounds` 字段必须是数组列表 (Array)',
        ));
      } else {
        final outbounds = config['outbounds'] as List;
        for (int i = 0; i < outbounds.length; i++) {
          final ob = outbounds[i];
          if (ob is! Map) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.error,
              message: '`outbounds[$i]` 必须是 Object 节点对象',
            ));
            continue;
          }
          final map = Map<String, dynamic>.from(ob);
          outboundsList.add(map);

          final tag = map['tag']?.toString().trim();
          final type = map['type']?.toString().trim().toLowerCase();

          if (tag == null || tag.isEmpty) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.error,
              message: '`outbounds[$i]` 缺少必需字段 `tag` (出站标签名)',
              suggestion: '为出站节点指定一个唯一的标签名称',
            ));
          } else {
            if (outboundTags.contains(tag)) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '检测到重复的出站标签名称: `$tag`',
                suggestion: '请确保每个出站节点的 tag 唯一',
              ));
            } else {
              outboundTags.add(tag);
            }
          }

          if (type == null || type.isEmpty) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.error,
              message: '出站节点 `${tag ?? "[$i]"}` 缺少 `type` 协议类型',
            ));
          } else if (!_validOutboundTypes.contains(type)) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.warning,
              message: '出站节点 `$tag` 使用了非标准或未知的协议类型 `$type`',
            ));
          }

          // Port & Server checks for proxy nodes
          if (type != null && !['selector', 'urltest', 'loadbalance', 'direct', 'block', 'dns'].contains(type)) {
            final server = map['server']?.toString().trim();
            final port = map['server_port'];

            if (server == null || server.isEmpty) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '节点 `$tag` 缺少服务器地址 `server`',
              ));
            }

            if (port == null) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '节点 `$tag` 缺少服务器端口 `server_port`',
              ));
            } else if (port is! int || port < 1 || port > 65535) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '节点 `$tag` 的服务器端口无效: `$port` (有效范围 1-65535)',
              ));
            }
          }
        }
      }
    } else {
      issues.add(const ConfigIssue(
        severity: ConfigIssueSeverity.warning,
        message: '配置中未找到 `outbounds` 出站列表',
        suggestion: '建议至少包含一个 direct 出站',
      ));
    }

    // 3. Check Selector & URL-Test Outbound Reference Integrity
    final allKnownOutbounds = {...outboundTags, ..._builtInOutboundTags};
    for (final ob in outboundsList) {
      final type = ob['type']?.toString().toLowerCase();
      final tag = ob['tag']?.toString() ?? 'Unnamed';

      if (type == 'selector' || type == 'urltest' || type == 'loadbalance') {
        final subOutbounds = ob['outbounds'];
        if (subOutbounds == null || subOutbounds is! List || subOutbounds.isEmpty) {
          issues.add(ConfigIssue(
            severity: ConfigIssueSeverity.error,
            message: '出站分组 `$tag` 的 `outbounds` 子节点列表不能为空',
          ));
        } else {
          for (final sub in subOutbounds) {
            final subTag = sub?.toString();
            if (subTag != null && !allKnownOutbounds.contains(subTag)) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '出站分组 `$tag` 中引用的子节点 `$subTag` 未在 outbounds 列表中定义',
                suggestion: '请在 outbounds 中添加 `$subTag` 或从该分组中移除',
              ));
            }
          }
        }
      }

      // Detour reference
      final detour = ob['detour']?.toString();
      if (detour != null && detour.isNotEmpty && !allKnownOutbounds.contains(detour)) {
        issues.add(ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message: '出站节点 `$tag` 的 detour 引用的出站 `$detour` 不存在',
        ));
      }
    }

    // 4. Inbounds Checks
    final inboundTags = <String>{};
    if (config['inbounds'] != null && config['inbounds'] is List) {
      final inbounds = config['inbounds'] as List;
      for (int i = 0; i < inbounds.length; i++) {
        final ib = inbounds[i];
        if (ib is! Map) continue;
        final tag = ib['tag']?.toString().trim();
        final type = ib['type']?.toString().trim().toLowerCase();

        if (tag != null && tag.isNotEmpty) {
          if (inboundTags.contains(tag)) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.error,
              message: '检测到重复的入站标签名称: `$tag`',
            ));
          } else {
            inboundTags.add(tag);
          }
        }

        if (type != null && !_validInboundTypes.contains(type)) {
          issues.add(ConfigIssue(
            severity: ConfigIssueSeverity.warning,
            message: '入站 `${tag ?? "[$i]"}` 使用了非标准入站类型 `$type`',
          ));
        }

        final listenPort = ib['listen_port'];
        if (listenPort != null && (listenPort is! int || listenPort < 1 || listenPort > 65535)) {
          issues.add(ConfigIssue(
            severity: ConfigIssueSeverity.error,
            message: '入站 `${tag ?? "[$i]"}` 的监听端口无效: `$listenPort`',
          ));
        }
      }
    }

    // 5. DNS Checks
    final dnsServerTags = <String>{'fakeip-dns'};
    if (config['dns'] != null && config['dns'] is Map) {
      final dns = config['dns'] as Map;
      if (dns['servers'] is List) {
        final servers = dns['servers'] as List;
        for (final s in servers) {
          if (s is! Map) continue;
          final sTag = s['tag']?.toString().trim();
          if (sTag != null && sTag.isNotEmpty) {
            dnsServerTags.add(sTag);
          }

          final detour = s['detour']?.toString();
          if (detour != null && detour.isNotEmpty && !allKnownOutbounds.contains(detour)) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.warning,
              message: 'DNS 服务器 `${sTag ?? "unnamed"}` 的 detour 出站 `$detour` 未在 outbounds 中定义',
            ));
          }
        }
      }

      final finalDns = dns['final']?.toString();
      if (finalDns != null && finalDns.isNotEmpty && !dnsServerTags.contains(finalDns)) {
        issues.add(ConfigIssue(
          severity: ConfigIssueSeverity.warning,
          message: '`dns.final` 指定的解析服务器 `$finalDns` 未在 `dns.servers` 中定义',
        ));
      }

      if (dns['rules'] is List) {
        final rules = dns['rules'] as List;
        for (int r = 0; r < rules.length; r++) {
          final rule = rules[r];
          if (rule is! Map) continue;
          final targetServer = rule['server']?.toString();
          if (targetServer != null && !dnsServerTags.contains(targetServer)) {
            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.warning,
              message: 'DNS 规则 `dns.rules[$r]` 指向的服务器 `$targetServer` 未在 `dns.servers` 中定义',
            ));
          }
        }
      }
    }

    // 6. Route Checks
    if (config['route'] != null && config['route'] is Map) {
      final route = config['route'] as Map;
      final finalOutbound = route['final']?.toString();
      if (finalOutbound != null && finalOutbound.isNotEmpty && !allKnownOutbounds.contains(finalOutbound)) {
        issues.add(ConfigIssue(
          severity: ConfigIssueSeverity.error,
          message: '默认路由 `route.final` 指定的出站 `$finalOutbound` 不存在于 outbounds 中',
          suggestion: '请修改 `route.final` 为已存在的出站节点 (如 direct 或 proxy)',
        ));
      }

      if (route['rules'] is List) {
        final rules = route['rules'] as List;
        for (int r = 0; r < rules.length; r++) {
          final rule = rules[r];
          if (rule is! Map) continue;
          final outbound = rule['outbound']?.toString();
          final action = rule['action']?.toString();

          if (action == null || action == 'route') {
            if (outbound != null && !allKnownOutbounds.contains(outbound)) {
              issues.add(ConfigIssue(
                severity: ConfigIssueSeverity.error,
                message: '路由规则 `route.rules[$r]` 指定的出站 `$outbound` 不存在于 outbounds 中',
              ));
            }
          }
        }
      }
    }

    return ConfigValidationResult(
      isValid: !issues.any((i) => i.isError),
      issues: issues,
    );
  }

  /// Full Deep Validator combining Dart semantic linting and native `sing-box check` dry-run.
  static Future<ConfigValidationResult> validateFull(
    String content, {
    String? customBinaryPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Run Dart Semantic Linter first
    final lintRes = lint(content);
    if (!lintRes.isValid) {
      stopwatch.stop();
      return ConfigValidationResult(
        isValid: false,
        issues: lintRes.issues,
        checkDuration: stopwatch.elapsed,
      );
    }

    final issues = List<ConfigIssue>.from(lintRes.issues);
    String? kernelOutput;

    // 2. Locate sing-box binary for native kernel dry-run
    try {
      final processMgr = SingboxProcessManager();
      final binary = await processMgr
          .findSingboxBinary(customPath: customBinaryPath)
          .timeout(const Duration(milliseconds: 300), onTimeout: () => null);

      if (binary != null) {
        final tempDir = await getTemporaryDirectory();
        final tempConfigFile = File(p.join(tempDir.path, 'sb_check_${DateTime.now().millisecondsSinceEpoch}.json'));
        await tempConfigFile.writeAsString(content);

        try {
          final runResult = await Process.run(
            binary,
            ['check', '-c', tempConfigFile.path],
          ).timeout(const Duration(seconds: 2));
          final stdoutStr = runResult.stdout.toString().trim();
          final stderrStr = runResult.stderr.toString().trim();
          kernelOutput = [stdoutStr, stderrStr].where((s) => s.isNotEmpty).join('\n');

          if (runResult.exitCode != 0) {
            // Extract error message from sing-box output
            final errorMsg = stderrStr.isNotEmpty ? stderrStr : (stdoutStr.isNotEmpty ? stdoutStr : 'sing-box check failed with exit code ${runResult.exitCode}');
            
            // Try to extract line number if sing-box output contains line info
            int? errLine;
            final lineMatch = RegExp(r'line\s+(\d+)').firstMatch(errorMsg) ?? RegExp(r':(\d+):\d+:').firstMatch(errorMsg);
            if (lineMatch != null) {
              errLine = int.tryParse(lineMatch.group(1)!);
            }

            issues.add(ConfigIssue(
              severity: ConfigIssueSeverity.error,
              message: 'sing-box 内核校验失败: $errorMsg',
              line: errLine,
              suggestion: '请根据内核报错信息检查参数字段或协议配置',
            ));
          }
        } finally {
          if (await tempConfigFile.exists()) {
            await tempConfigFile.delete().catchError((_) => tempConfigFile);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SingboxConfigValidator] sing-box check execution error: $e');
      }
    }

    stopwatch.stop();
    return ConfigValidationResult(
      isValid: !issues.any((i) => i.isError),
      issues: issues,
      kernelOutput: kernelOutput,
      checkDuration: stopwatch.elapsed,
    );
  }
}
