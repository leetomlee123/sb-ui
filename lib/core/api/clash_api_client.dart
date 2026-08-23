import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/traffic_data.dart';
import '../models/log_entry.dart';
import '../models/connection_info.dart';

class ClashApiClient {
  final String host;
  final int port;
  final String secret;
  late final Dio _dio;

  ClashApiClient({
    this.host = '127.0.0.1',
    this.port = 9090,
    this.secret = '',
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://$host:$port',
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 5),
        headers: secret.isNotEmpty ? {'Authorization': 'Bearer $secret'} : {},
      ),
    );
  }

  // --- REST APIs ---

  Future<String> getVersion() async {
    try {
      final response = await _dio.get('/version');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          return (data['version'] ?? data['premium'] ?? 'sing-box').toString();
        }
      }
    } catch (_) {}
    return 'sing-box core';
  }

  Future<Map<String, dynamic>> getProxiesRaw() async {
    try {
      final response = await _dio.get('/proxies');
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data['proxies'] ?? {});
      }
    } catch (_) {}
    return {};
  }

  Future<bool> selectProxy(String groupName, String nodeName) async {
    try {
      final encodedGroup = Uri.encodeComponent(groupName);
      final response = await _dio.put(
        '/proxies/$encodedGroup',
        data: {'name': nodeName},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<int?> testDelay(String nodeName, {
    String testUrl = 'https://www.gstatic.com/generate_204',
    int timeout = 4000,
  }) async {
    try {
      final encodedNode = Uri.encodeComponent(nodeName);
      final response = await _dio.get(
        '/proxies/$encodedNode/delay',
        queryParameters: {
          'url': testUrl,
          'timeout': timeout,
        },
      );
      if (response.statusCode == 200 && response.data is Map) {
        return response.data['delay'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<ConnectionsData> getConnectionsData() async {
    try {
      final response = await _dio.get('/connections');
      if (response.statusCode == 200 && response.data is Map) {
        final downloadTotal = response.data['downloadTotal'] as int? ?? 0;
        final uploadTotal = response.data['uploadTotal'] as int? ?? 0;
        final conns = (response.data['connections'] as List<dynamic>?) ?? [];
        final list = conns
            .whereType<Map<String, dynamic>>()
            .map((e) => ActiveConnection.fromJson(e))
            .toList();
        return ConnectionsData(
          downloadTotal: downloadTotal,
          uploadTotal: uploadTotal,
          connections: list,
        );
      }
    } catch (_) {}
    return const ConnectionsData();
  }

  Future<List<ActiveConnection>> getConnections() async {
    final data = await getConnectionsData();
    return data.connections;
  }

  Future<bool> closeConnection(String id) async {
    try {
      final response = await _dio.delete('/connections/$id');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> closeAllConnections() async {
    try {
      final response = await _dio.delete('/connections');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> switchMode(String mode) async {
    try {
      final response = await _dio.patch(
        '/configs',
        data: {'mode': mode},
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- WebSocket Streaming ---

  Stream<TrafficPoint> trafficStream() {
    final authParam = secret.isNotEmpty ? '?token=$secret' : '';
    final uri = Uri.parse('ws://$host:$port/traffic$authParam');
    try {
      final channel = WebSocketChannel.connect(uri);
      return channel.stream.map<TrafficPoint>((data) {
        try {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            return TrafficPoint.fromJson(decoded);
          }
        } catch (_) {}
        return TrafficPoint(up: 0, down: 0);
      }).handleError((_) => TrafficPoint(up: 0, down: 0));
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<LogEntry> logsStream({String level = 'info'}) {
    final authParam = secret.isNotEmpty ? '&token=$secret' : '';
    final uri = Uri.parse('ws://$host:$port/logs?level=$level$authParam');
    try {
      final channel = WebSocketChannel.connect(uri);
      return channel.stream.map<LogEntry>((data) {
        try {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            return LogEntry.fromJson(decoded);
          }
        } catch (_) {}
        return LogEntry.raw(data.toString());
      }).handleError((e) => LogEntry.raw('WebSocket log error: $e', LogLevel.error));
    } catch (e) {
      return Stream.value(LogEntry.raw('Failed to connect log stream: $e', LogLevel.error));
    }
  }

  Stream<MemoryInfo> memoryStream() {
    final authParam = secret.isNotEmpty ? '?token=$secret' : '';
    final uri = Uri.parse('ws://$host:$port/memory$authParam');
    try {
      final channel = WebSocketChannel.connect(uri);
      return channel.stream.map<MemoryInfo>((data) {
        try {
          final decoded = jsonDecode(data.toString());
          if (decoded is Map<String, dynamic>) {
            return MemoryInfo.fromJson(decoded);
          }
        } catch (_) {}
        return MemoryInfo(inuse: 0, oslimit: 0);
      }).handleError((_) => MemoryInfo(inuse: 0, oslimit: 0));
    } catch (_) {
      return const Stream.empty();
    }
  }
}
