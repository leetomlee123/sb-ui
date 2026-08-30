import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

class MixinResult {
  final bool success;
  final Map<String, dynamic> config;
  final String? error;
  final List<String> logs;

  const MixinResult({
    required this.success,
    required this.config,
    this.error,
    this.logs = const [],
  });
}

class MixinEngine {
  /// Default starter mixin template with clear examples for sing-box & clash users.
  static const String defaultTemplate = '''# ==========================================
# Singular 全局混入配置 (Mixin Configuration)
# 支持 YAML 或 JSON 格式，在内核启动前与主配置深度合并
# ==========================================

# 1. 自定义 DNS 上游配置 (合并并优先匹配)
# dns:
#   servers:
#     - tag: custom-nextdns
#       address: https://dns.nextdns.io/xxxxxx
#       detour: proxy
#   rules:
#     - domain_suffix:
#         - mycompany.internal
#       server: local-dns

# 2. 自定义出站节点或物理网卡出口绑定
# outbounds:
#   - type: direct
#     tag: 移动5G热点直连
#     bind_interface: Wi-Fi 2

# 3. 优先分流规则 (自动置于路由规则最顶部优先匹配)
# route:
#   rules:
#     - domain_suffix:
#         - openai.com
#         - anthropic.com
#       outbound: proxy
#     - ip_cidr:
#         - 192.168.1.0/24
#       outbound: direct
''';

  /// Converts a YAML node / map recursively to standard Dart `Map<String, dynamic>`.
  static dynamic _convertYamlNode(dynamic node) {
    if (node is YamlMap) {
      final Map<String, dynamic> result = {};
      for (final entry in node.entries) {
        result[entry.key.toString()] = _convertYamlNode(entry.value);
      }
      return result;
    } else if (node is YamlList) {
      return node.map((e) => _convertYamlNode(e)).toList();
    }
    return node;
  }

  /// Deep merges `source` map into `target` map.
  static Map<String, dynamic> deepMerge(
    Map<String, dynamic> target,
    Map<String, dynamic> source, {
    List<String>? logs,
  }) {
    final Map<String, dynamic> result = Map<String, dynamic>.from(target);

    for (final key in source.keys) {
      final sourceVal = source[key];
      final targetVal = result[key];

      if (sourceVal is Map && targetVal is Map) {
        result[key] = deepMerge(
          Map<String, dynamic>.from(targetVal),
          Map<String, dynamic>.from(sourceVal),
          logs: logs,
        );
      } else if (sourceVal is List && targetVal is List) {
        result[key] = _mergeLists(
          key,
          List<dynamic>.from(targetVal),
          List<dynamic>.from(sourceVal),
          logs: logs,
        );
      } else {
        result[key] = sourceVal;
        logs?.add('覆盖属性 [$key]: $sourceVal');
      }
    }

    return result;
  }

  /// Merges lists with smart tag deduplication and rule prepending.
  static List<dynamic> _mergeLists(
    String parentKey,
    List<dynamic> targetList,
    List<dynamic> sourceList, {
    List<String>? logs,
  }) {
    // If it's routing rules or DNS rules, user mixin rules should be PREPENDED to have top matching priority
    final isRuleList = parentKey == 'rules';

    if (isRuleList) {
      logs?.add('注入前置规则: ${sourceList.length} 条优先规则插入到 [$parentKey]');
      return [...sourceList, ...targetList];
    }

    // For outbounds, inbounds, or DNS servers with 'tag', merge by tag
    final bool hasTaggedItems = sourceList.any((e) => e is Map && e.containsKey('tag'));

    if (hasTaggedItems) {
      final List<dynamic> merged = List<dynamic>.from(targetList);

      for (final srcItem in sourceList) {
        if (srcItem is Map && srcItem.containsKey('tag')) {
          final srcTag = srcItem['tag']?.toString();
          final existingIdx = merged.indexWhere(
            (item) => item is Map && item['tag']?.toString() == srcTag,
          );

          if (existingIdx != -1) {
            // Override or deep merge existing item
            merged[existingIdx] = deepMerge(
              Map<String, dynamic>.from(merged[existingIdx] as Map),
              Map<String, dynamic>.from(srcItem),
              logs: logs,
            );
            logs?.add('合并已有标签项 [$srcTag] 到 [$parentKey]');
          } else {
            // Append new item
            merged.add(srcItem);
            logs?.add('追加新标签项 [$srcTag] 到 [$parentKey]');
          }
        } else {
          if (!merged.contains(srcItem)) {
            merged.add(srcItem);
          }
        }
      }
      return merged;
    }

    // For plain lists, append unique items
    final List<dynamic> combined = List<dynamic>.from(targetList);
    for (final item in sourceList) {
      if (!combined.contains(item)) {
        combined.add(item);
      }
    }
    return combined;
  }

  /// Parses YAML or JSON content into a Map.
  static Map<String, dynamic>? parseContent(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      // First attempt JSON
      if (trimmed.startsWith('{')) {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    try {
      // Fallback to YAML
      final yamlDoc = loadYaml(trimmed);
      if (yamlDoc is YamlMap || yamlDoc is Map) {
        final converted = _convertYamlNode(yamlDoc);
        if (converted is Map<String, dynamic>) return converted;
        if (converted is Map) return Map<String, dynamic>.from(converted);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[MixinEngine] Failed to parse mixin YAML/JSON: $e');
      }
      rethrow;
    }

    return null;
  }

  /// Applies the mixin content to the base configuration map.
  static MixinResult apply(Map<String, dynamic> baseConfig, String mixinRaw) {
    final logs = <String>[];

    try {
      final parsedMixin = parseContent(mixinRaw);
      if (parsedMixin == null || parsedMixin.isEmpty) {
        return MixinResult(
          success: true,
          config: baseConfig,
          logs: ['混入内容为空，未做任何更改'],
        );
      }

      final merged = deepMerge(baseConfig, parsedMixin, logs: logs);
      logs.add('混入合并成功，共处理 ${parsedMixin.keys.length} 个顶级模块');

      return MixinResult(
        success: true,
        config: merged,
        logs: logs,
      );
    } catch (e) {
      return MixinResult(
        success: false,
        config: baseConfig,
        error: '混入解析错误: $e',
        logs: logs..add('错误: $e'),
      );
    }
  }
}
