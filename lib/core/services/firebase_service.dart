import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../utils/app_logger.dart';

/// Unified Firebase & Telemetry Service for Singular.
/// Supports native FlutterFire initialization and graceful cross-platform fallback.
class FirebaseService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

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
      AppLogger.info('[Firebase] 核心服务初始化成功 (Project: ${options.projectId})');
    } catch (e, st) {
      AppLogger.info('[Firebase] 运行于本地兼容模式 (${e.toString()})');
      if (kDebugMode) {
        debugPrint('[Firebase Debug Init] $e\n$st');
      }
    }
  }

  /// Logs user analytics and app telemetry events.
  static Future<void> logEvent(
    String name, [
    Map<String, dynamic>? parameters,
  ]) async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      final measurementId = options.measurementId;
      final apiKey = options.apiKey;

      // Log locally for diagnostics
      AppLogger.debug('[Firebase Event] $name: ${parameters ?? {}}');

      // If measurement ID and API key are configured (non-placeholder), send GA4/Firebase Measurement Protocol payload
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
                'timestamp_micros': DateTime.now().microsecondsSinceEpoch,
                ...?parameters,
              },
            },
          ],
        };
        await _dio.post(url, data: jsonEncode(payload));
      }
    } catch (e) {
      AppLogger.debug('[Firebase Event Error] $name: $e');
    }
  }

  /// Reports non-fatal errors or exception telemetry.
  static Future<void> logError(
    Object error, [
    StackTrace? stackTrace,
    String? reason,
  ]) async {
    AppLogger.error('[Firebase Error Reported] $error (Reason: $reason)');
    await logEvent('app_exception', {
      'error': error.toString().substring(0, error.toString().length > 100 ? 100 : error.toString().length),
      'reason': ?reason,
    });
  }
}
