import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/log_entry.dart';

enum CoreStatus {
  stopped,
  starting,
  running,
  error;

  String get displayName {
    switch (this) {
      case CoreStatus.stopped:
        return 'Stopped';
      case CoreStatus.starting:
        return 'Starting...';
      case CoreStatus.running:
        return 'Running';
      case CoreStatus.error:
        return 'Error';
    }
  }
}

class SingboxProcessManager {
  Process? _process;
  CoreStatus _status = CoreStatus.stopped;
  final _statusController = StreamController<CoreStatus>.broadcast();
  final _outputController = StreamController<LogEntry>.broadcast();
  DateTime? _startedAt;

  CoreStatus get status => _status;
  Stream<CoreStatus> get statusStream => _statusController.stream;
  Stream<LogEntry> get outputStream => _outputController.stream;
  DateTime? get startedAt => _startedAt;

  void _updateStatus(CoreStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<String?> findSingboxBinary({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      final file = File(customPath);
      if (await file.exists()) return customPath;
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidatePaths = [
      // Bundled sidecars
      p.join(exeDir, 'data', 'core', Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
      p.join(exeDir, '..', 'Resources', 'core', 'sing-box'),
      p.join(exeDir, Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
      p.join(Directory.current.path, 'core', Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
      // System default locations
      '/usr/local/bin/sing-box',
      '/usr/bin/sing-box',
      '/opt/sing-box/sing-box',
      'sing-box',
      'sing-box.exe',
      r'C:\Program Files\sing-box\sing-box.exe',
    ];

    for (final candidate in candidatePaths) {
      try {
        final result = await Process.run(candidate, ['version']);
        if (result.exitCode == 0) {
          return candidate;
        }
      } catch (_) {}
    }

    return null;
  }

  static const Map<String, String> _coreEnvironment = {
    'ENABLE_DEPRECATED_LEGACY_DNS_SERVERS': 'true',
    'ENABLE_DEPRECATED_OUTBOUND_DNS_RULE_ITEM': 'true',
    'ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER': 'true',
  };

  Future<bool> checkConfig(String binaryPath, String configPath) async {
    try {
      final result = await Process.run(
        binaryPath,
        ['check', '-c', configPath],
        environment: _coreEnvironment,
      );
      if (result.exitCode != 0) {
        _outputController.add(LogEntry(
          level: LogLevel.error,
          message: 'Config check failed:\n${result.stderr}',
        ));
        return false;
      }
      return true;
    } catch (e) {
      _outputController.add(LogEntry(
        level: LogLevel.error,
        message: 'Failed to verify config: $e',
      ));
      return false;
    }
  }

  Future<bool> start({
    required String configPath,
    String? customBinaryPath,
  }) async {
    if (_status == CoreStatus.running || _status == CoreStatus.starting) {
      return true;
    }

    _updateStatus(CoreStatus.starting);
    _outputController.add(LogEntry(level: LogLevel.info, message: 'Finding sing-box binary...'));

    final binary = await findSingboxBinary(customPath: customBinaryPath);
    if (binary == null) {
      _outputController.add(LogEntry(
        level: LogLevel.error,
        message: 'sing-box binary not found. Please specify the binary path in Settings.',
      ));
      _updateStatus(CoreStatus.error);
      return false;
    }

    _outputController.add(LogEntry(level: LogLevel.info, message: 'Validating config file at $configPath...'));
    final valid = await checkConfig(binary, configPath);
    if (!valid) {
      _updateStatus(CoreStatus.error);
      return false;
    }

    try {
      _outputController.add(LogEntry(level: LogLevel.info, message: 'Launching sing-box process...'));
      _process = await Process.start(
        binary,
        ['run', '-c', configPath],
        mode: ProcessStartMode.normal,
        environment: _coreEnvironment,
      );

      _startedAt = DateTime.now();
      _updateStatus(CoreStatus.running);

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add(LogEntry(level: LogLevel.info, message: line));
      });

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add(LogEntry(level: LogLevel.warn, message: line));
      });

      _process!.exitCode.then((code) {
        _outputController.add(LogEntry(
          level: code == 0 ? LogLevel.info : LogLevel.error,
          message: 'sing-box process exited with code $code',
        ));
        _process = null;
        _startedAt = null;
        _updateStatus(CoreStatus.stopped);
      });

      return true;
    } catch (e) {
      _outputController.add(LogEntry(
        level: LogLevel.error,
        message: 'Failed to launch sing-box: $e',
      ));
      _updateStatus(CoreStatus.error);
      return false;
    }
  }

  Future<void> stop() async {
    if (_process == null) {
      _updateStatus(CoreStatus.stopped);
      return;
    }

    try {
      _outputController.add(LogEntry(level: LogLevel.info, message: 'Stopping sing-box process...'));
      _process!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      if (_process != null) {
        _process!.kill(ProcessSignal.sigkill);
      }
    } catch (_) {}
    _process = null;
    _startedAt = null;
    _updateStatus(CoreStatus.stopped);
  }

  Future<bool> restart({
    required String configPath,
    String? customBinaryPath,
  }) async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 300));
    return await start(configPath: configPath, customBinaryPath: customBinaryPath);
  }

  void dispose() {
    stop();
    _statusController.close();
    _outputController.close();
  }
}
