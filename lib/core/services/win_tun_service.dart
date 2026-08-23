import 'dart:io';
import 'package:flutter/services.dart';

class WinTunStartResult {
  final bool isSuccess;
  final bool isCancelled;
  final int errorCode;
  final String? error;
  final String message;
  final int? pid;

  const WinTunStartResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.errorCode = 0,
    this.error,
    required this.message,
    this.pid,
  });

  factory WinTunStartResult.fromMap(Map<dynamic, dynamic> map) {
    return WinTunStartResult(
      isSuccess: map['success'] as bool? ?? false,
      isCancelled: map['cancelled'] as bool? ?? false,
      errorCode: (map['errorCode'] as num?)?.toInt() ?? 0,
      error: map['error'] as String?,
      message: map['message'] as String? ?? '',
      pid: (map['pid'] as num?)?.toInt(),
    );
  }
}

class WinTunService {
  static const MethodChannel _channel = MethodChannel('com.example.sb_ui/tun_process');

  static bool get isSupported => Platform.isWindows;

  static Future<bool> isCurrentProcessElevated() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isCurrentProcessElevated');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<WinTunStartResult> startElevated({
    required String binaryPath,
    required String configPath,
    required String workingDir,
  }) async {
    if (!Platform.isWindows) {
      return const WinTunStartResult(
        isSuccess: false,
        message: 'Native Win32 elevation is only supported on Windows',
      );
    }

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startSingBoxAsAdmin',
        {
          'binaryPath': binaryPath,
          'configPath': configPath,
          'workingDir': workingDir,
        },
      );
      if (res != null) {
        return WinTunStartResult.fromMap(res);
      }
    } on PlatformException catch (e) {
      return WinTunStartResult(
        isSuccess: false,
        error: e.code,
        message: e.message ?? 'Platform error during elevation',
      );
    } catch (e) {
      return WinTunStartResult(
        isSuccess: false,
        message: 'Exception starting elevated sing-box: $e',
      );
    }

    return const WinTunStartResult(
      isSuccess: false,
      message: 'Unknown failure starting elevated process',
    );
  }

  static Future<bool> stopElevated() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopSingBox');
      return (res?['success'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSingBoxRunning() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('isSingBoxRunning');
      return (res?['running'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
