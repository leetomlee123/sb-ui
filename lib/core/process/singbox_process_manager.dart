import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/log_entry.dart';
import '../services/storage_service.dart';
import '../services/win_tun_service.dart';

enum CoreStatus {
  stopped,
  starting,
  waitingUac,
  running,
  error;

  String get displayName {
    switch (this) {
      case CoreStatus.stopped:
        return 'Stopped';
      case CoreStatus.starting:
        return 'Starting...';
      case CoreStatus.waitingUac:
        return 'Waiting for UAC...';
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

  // Watchdog crash recovery state
  bool _intentionalStop = false;
  int _consecutiveCrashes = 0;
  String? _lastConfigPath;
  String? _lastCustomBinaryPath;
  bool _lastRequireElevated = false;
  Timer? _crashResetTimer;

  // Resolved binary path cache: avoids re-running the expensive candidate
  // scan (which spawns processes) on every lookup.
  String? _cachedBinaryPath;

  CoreStatus get status => _status;
  Stream<CoreStatus> get statusStream => _statusController.stream;
  Stream<LogEntry> get outputStream => _outputController.stream;
  DateTime? get startedAt => _startedAt;
  int? get elevatedPid => _elevatedPid;

  /// True when we spawned the core ourselves and mirror its stdout.
  /// When false (elevated TUN process), logs must come from the Clash API WS.
  bool get hasStdoutCapture => _process != null;

  void _updateStatus(CoreStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<String?> findSingboxBinary({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      final file = File(customPath);
      if (await file.exists()) return customPath;
    }

    if (_cachedBinaryPath != null) {
      // Cheap existence re-check guards against the binary disappearing
      // mid-session (e.g. after an update failure).
      if (await File(_cachedBinaryPath!).exists()) {
        return _cachedBinaryPath!;
      }
      _cachedBinaryPath = null;
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
        // Pre-filter path-like candidates with a cheap stat: spawning a
        // process just to learn a binary is missing is very slow. Bare
        // names ('sing-box') must still go through PATH resolution.
        final looksLikePath = candidate.contains('/') || candidate.contains(r'\');
        if (looksLikePath && !await File(candidate).exists()) continue;

        final result = await Process.run(candidate, ['version']);
        if (result.exitCode == 0) {
          _cachedBinaryPath = candidate;
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
      return await WinTunService.isCurrentProcessElevated();
    }
    return false;
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
      if (result.exitCode == 0) {
        _outputController.add(LogEntry(level: LogLevel.info, message: 'Config validation passed.'));
        return true;
      } else {
        final errText = result.stderr.toString().trim();
        final outText = result.stdout.toString().trim();
        final combined = errText.isNotEmpty ? errText : outText;
        _outputController.add(LogEntry(
          level: LogLevel.error,
          message: 'Config check failed (exit code ${result.exitCode}): $combined',
        ));
        return false;
      }
    } catch (e) {
      _outputController.add(LogEntry(level: LogLevel.error, message: 'Failed to run config check: $e'));
      return false;
    }
  }

  Future<bool> start({
    required String configPath,
    String? customBinaryPath,
    bool requireElevated = false,
  }) async {
    if (_status == CoreStatus.running) {
      await stop();
    }

    _intentionalStop = false;
    _lastConfigPath = configPath;
    _lastCustomBinaryPath = customBinaryPath;
    _lastRequireElevated = requireElevated;

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

      // If TUN mode requested and Flutter is non-elevated on Windows, trigger native UAC elevation
      if (requireElevated && !alreadyAdmin && Platform.isWindows) {
        _updateStatus(CoreStatus.waitingUac);
        _outputController.add(LogEntry(
          level: LogLevel.info,
          message: '正在请求 Windows UAC 管理员权限以启动 TUN 虚拟网卡...',
        ));

        final res = await WinTunService.startElevated(
          binaryPath: binary,
          configPath: configPath,
          workingDir: configParentDir,
        );

        if (res.isSuccess) {
          _elevatedPid = res.pid;
          _startedAt = DateTime.now();
          _updateStatus(CoreStatus.running);
          _outputController.add(LogEntry(
            level: LogLevel.info,
            message: 'sing-box TUN 核心已通过管理员权限成功启动 (PID: ${res.pid})',
          ));
          return true;
        } else if (res.isCancelled) {
          _outputController.add(LogEntry(
            level: LogLevel.warn,
            message: 'TUN 开启失败：用户取消了管理员授权 (UAC)',
          ));
          _updateStatus(CoreStatus.stopped);
          return false;
        } else {
          _outputController.add(LogEntry(
            level: LogLevel.error,
            message: 'TUN 模式提权启动失败: ${res.message}',
          ));
          _updateStatus(CoreStatus.error);
          return false;
        }
      }

      // Normal process start (Standard Proxy or non-Windows / already Admin)
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

      // Reset crash counter after 30s of healthy operation
      _crashResetTimer?.cancel();
      _crashResetTimer = Timer(const Duration(seconds: 30), () {
        _consecutiveCrashes = 0;
      });

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

      _process!.exitCode.then((code) async {
        _outputController.add(LogEntry(
          level: code == 0 ? LogLevel.info : LogLevel.error,
          message: 'sing-box process exited with code $code',
        ));
        _process = null;
        _startedAt = null;

        // Auto-restart Watchdog if unexpected termination occurs
        if (!_intentionalStop && code != 0 && _lastConfigPath != null) {
          if (_consecutiveCrashes < 3) {
            _consecutiveCrashes++;
            _outputController.add(LogEntry(
              level: LogLevel.warn,
              message: '[Watchdog] Core exited unexpectedly (code $code). Auto-recovering in 1.5s (Attempt $_consecutiveCrashes/3)...',
            ));
            await Future.delayed(const Duration(milliseconds: 1500));
            if (!_intentionalStop) {
              await start(
                configPath: _lastConfigPath!,
                customBinaryPath: _lastCustomBinaryPath,
                requireElevated: _lastRequireElevated,
              );
              return;
            }
          } else {
            _outputController.add(LogEntry(
              level: LogLevel.error,
              message: '[Watchdog] Consecutive crash limit reached (3). Stopping auto-restart.',
            ));
          }
        }

        if (_status == CoreStatus.running) {
          _updateStatus(code == 0 ? CoreStatus.stopped : CoreStatus.error);
        }
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
    _intentionalStop = true;
    _consecutiveCrashes = 0;
    _crashResetTimer?.cancel();

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

    if (Platform.isWindows) {
      try {
        await WinTunService.stopElevated();
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
    _crashResetTimer?.cancel();
    _statusController.close();
    _outputController.close();
  }
}
