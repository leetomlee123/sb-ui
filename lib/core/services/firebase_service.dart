import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../utils/app_logger.dart';

/// Unified Firebase Analytics & Crash Reporting Service for Singular.
/// Operates seamlessly and silently in the background with cross-platform REST & native fallback.
class FirebaseService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static final DateTime _startTime = DateTime.now();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// Initializes Firebase asynchronously during app startup.
  static Future<void> init() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: options);
      _isInitialized = true;
      AppLogger.info('[Firebase] 核心服务就绪 (Project: ${options.projectId})');
    } catch (e, st) {
      AppLogger.info('[Firebase] 运行于本地兼容模式 (${e.toString()})');
      if (kDebugMode) {
        debugPrint('[Firebase Debug Init] $e\n$st');
      }
    }
  }

  /// Sends a raw custom analytics event.
  static Future<void> logEvent(
    String name, [
    Map<String, dynamic>? parameters,
  ]) async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final measurementId = options.measurementId;
      final apiKey = options.apiKey;

      AppLogger.debug('[Firebase Analytics] $name: ${parameters ?? {}}');

      if (measurementId != null &&
          measurementId.startsWith('G-') &&
          !apiKey.contains('Placeholder')) {
        final url =
            'https://www.google-analytics.com/mp/collect?measurement_id=$measurementId&api_secret=$apiKey';
        final payload = {
          'client_id': 'singular_${Platform.operatingSystem}_${Platform.localHostname.hashCode.abs()}',
          'events': [
            {
              'name': name,
              'params': {
                'platform': Platform.operatingSystem,
                'os_version': Platform.operatingSystemVersion,
                'app_uptime_sec': DateTime.now().difference(_startTime).inSeconds,
                'timestamp_micros': DateTime.now().microsecondsSinceEpoch,
                ...?parameters,
              },
            },
          ],
        };
        await _dio.post(url, data: jsonEncode(payload));
      }
    } catch (e) {
      AppLogger.debug('[Firebase Analytics Error] $name: $e');
    }
  }

  /// Records an unhandled or non-fatal exception and sends a crash telemetry report.
  static Future<void> recordException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    try {
      final errorStr = exception.toString();
      final traceSnippet = stackTrace != null
          ? stackTrace.toString().split('\n').take(8).join(' | ')
          : '';

      AppLogger.error('[Firebase Crash Shield] ${fatal ? "FATAL" : "NON-FATAL"}: $errorStr (Reason: $reason)');

      await logEvent(fatal ? 'app_crash' : 'app_exception', {
        'error_type': exception.runtimeType.toString(),
        'error_message': errorStr.length > 200 ? errorStr.substring(0, 200) : errorStr,
        'stack_trace': traceSnippet.length > 300 ? traceSnippet.substring(0, 300) : traceSnippet,
        'fatal': fatal ? 1 : 0,
        'reason': reason,
      });
    } catch (_) {}
  }

  /// Convenience wrapper for non-fatal exception reporting.
  static Future<void> logError(
    Object error, [
    StackTrace? stackTrace,
    String? reason,
  ]) async {
    await recordException(
      error,
      stackTrace: stackTrace,
      reason: reason,
      fatal: false,
    );
  }

  // --- Domain Specific Telemetry Trackers ---

  /// Logs application startup metrics.
  static Future<void> logAppStartup({
    required int launchTimeMs,
    int? nativeLoadMs,
  }) async {
    await logEvent('app_startup', {
      'launch_time_ms': launchTimeMs,
      'native_load_ms': nativeLoadMs,
    });
  }

  /// Logs sing-box core lifecycle actions.
  static Future<void> logCoreAction({
    required String action, // 'start', 'stop', 'restart', 'fail'
    String? routingMode,
    bool? tunEnabled,
    String? profileName,
    String? failureReason,
  }) async {
    await logEvent('core_$action', {
      'routing_mode': routingMode,
      'tun_enabled': tunEnabled != null ? (tunEnabled ? 1 : 0) : null,
      'profile_name': profileName,
      'failure_reason': failureReason,
    });
  }

  /// Logs speed test metrics.
  static Future<void> logSpeedTest({
    required int totalNodes,
    required int testedNodes,
    required int successCount,
    required int averageLatencyMs,
  }) async {
    await logEvent('speed_test_completed', {
      'total_nodes': totalNodes,
      'tested_nodes': testedNodes,
      'success_count': successCount,
      'avg_latency_ms': averageLatencyMs,
    });
  }

  /// Logs subscription / profile operations.
  static Future<void> logProfileOperation({
    required String action, // 'add', 'update', 'delete', 'switch'
    required String format, // 'sing-box', 'clash', 'uri-list'
    int? nodeCount,
  }) async {
    await logEvent('profile_$action', {
      'format': format,
      'node_count': nodeCount,
    });
  }

  /// Logs system proxy / TUN mode toggling.
  static Future<void> logFeatureToggle({
    required String feature, // 'system_proxy', 'tun_mode', 'fake_ip', 'ad_block'
    required bool enabled,
  }) async {
    await logEvent('feature_toggled', {
      'feature': feature,
      'enabled': enabled ? 1 : 0,
    });
  }
}
