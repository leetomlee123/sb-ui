import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/log_entry.dart';
import '../services/storage_service.dart';

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
  int? _elevatedPid;
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
    final configDir = (await StorageService.getAppConfigDir()).path;
    final candidatePaths = [
      // Bundled / updated sidecars
      p.join(exeDir, 'data', 'core', Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
      p.join(configDir, Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
      p.join(exeDir, 'config', Platform.isWindows ? 'sing-box.exe' : 'sing-box'),
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
    'ENABLE_DEPRECATED_GEO_IP_FIELDS': 'true',
    'ENABLE_DEPRECATED_SPECIAL_RULE_FIELDS': 'true',
    'ENABLE_DEPRECATED_GLOBAL_CLIENT': 'true',
  };

  static Future<bool> isElevated() async {
    if (Platform.isWindows) {
      try {
        final res = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
        ]);
        return res.stdout.toString().trim().toLowerCase() == 'true';
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      try {
        final res = await Process.run('id', ['-u']);
        return res.stdout.toString().trim() == '0';
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<bool> checkConfig(String binaryPath, String configPath) async {
    try {
      final configParentDir = File(configPath).parent.path;
      final result = await Process.run(
        binaryPath,
        ['check', '-c', configPath],
        workingDirectory: configParentDir,
        environment: _coreEnvironment,
      );
      if (result.exitCode != 0) {
        _outputController.add(LogEntry(
          level: LogLevel.error,
          message: 'Config check failed:\n${result.stderr}\n${result.stdout}',
        ));
        return false;
      }
      return true;
    } catch (e) {
      _outputController.add(LogEntry(
        level: LogLevel.error,
        message: 'Error during config check: $e',
      ));
      return false;
    }
  }

  Future<bool> start({
    required String configPath,
    String? customBinaryPath,
    bool requireElevated = false,
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
      final configParentDir = File(configPath).parent.path;
      // Clean up any stale cache.db files to prevent DB lock contention
      try {
        final cacheDb = File(p.join(configParentDir, 'cache.db'));
        if (await cacheDb.exists()) await cacheDb.delete();
        final cacheWal = File(p.join(configParentDir, 'cache.db-wal'));
        if (await cacheWal.exists()) await cacheWal.delete();
      } catch (_) {}

      final alreadyAdmin = await isElevated();

      // If TUN mode requested and not yet elevated on Windows, request UAC elevation
      if (requireElevated && !alreadyAdmin && Platform.isWindows) {
        _outputController.add(LogEntry(
          level: LogLevel.info,
          message: 'Requesting Administrator privileges for TUN mode...',
        ));

        final psScript = '''
\$process = Start-Process -FilePath '$binary' -ArgumentList 'run', '-c', '$configPath' -WorkingDirectory '$configParentDir' -Verb RunAs -WindowStyle Hidden -PassThru
\$process.Id
''';
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
        if (result.exitCode == 0) {
          final pidStr = result.stdout.toString().trim();
          _elevatedPid = int.tryParse(pidStr);
          _startedAt = DateTime.now();
          _updateStatus(CoreStatus.running);
          _outputController.add(LogEntry(
            level: LogLevel.info,
            message: 'sing-box TUN service started with Administrator privileges (PID: $_elevatedPid)',
          ));
          return true;
        } else {
          _outputController.add(LogEntry(
            level: LogLevel.error,
            message: 'Administrator authorization was cancelled or failed: ${result.stderr}',
          ));
          _updateStatus(CoreStatus.error);
          return false;
        }
      }

      // Normal process start
      _outputController.add(LogEntry(level: LogLevel.info, message: 'Launching sing-box process...'));
      _process = await Process.start(
        binary,
        ['run', '-c', configPath],
        mode: ProcessStartMode.normal,
        workingDirectory: configParentDir,
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
    _outputController.add(LogEntry(level: LogLevel.info, message: 'Stopping sing-box process...'));

    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 300));
        if (_process != null) {
          _process!.kill(ProcessSignal.sigkill);
        }
      } catch (_) {}
      _process = null;
    }

    if (_elevatedPid != null || Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe', '/T']);
      } catch (_) {}
      _elevatedPid = null;
    }

    _startedAt = null;
    _updateStatus(CoreStatus.stopped);
  }

  Future<bool> restart({
    required String configPath,
    String? customBinaryPath,
    bool requireElevated = false,
  }) async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 400));
    return await start(
      configPath: configPath,
      customBinaryPath: customBinaryPath,
      requireElevated: requireElevated,
    );
  }

  void dispose() {
    stop();
    _statusController.close();
    _outputController.close();
  }
}
