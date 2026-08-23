import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/clash_api_client.dart';
import '../engine/config_generator.dart';
import '../engine/profile_parser.dart';
import '../process/singbox_process_manager.dart';
import '../services/storage_service.dart';
import '../services/system_proxy_manager.dart';
import 'profiles_provider.dart';
import 'settings_provider.dart';

class CoreState {
  final CoreStatus status;
  final String? activeProfileName;
  final String? errorMessage;
  final Duration uptime;

  CoreState({
    required this.status,
    this.activeProfileName,
    this.errorMessage,
    this.uptime = Duration.zero,
  });

  bool get isRunning => status == CoreStatus.running;

  CoreState copyWith({
    CoreStatus? status,
    String? activeProfileName,
    String? errorMessage,
    Duration? uptime,
  }) {
    return CoreState(
      status: status ?? this.status,
      activeProfileName: activeProfileName ?? this.activeProfileName,
      errorMessage: errorMessage,
      uptime: uptime ?? this.uptime,
    );
  }
}

class CoreNotifier extends StateNotifier<CoreState> {
  final Ref _ref;
  final SingboxProcessManager _processManager = SingboxProcessManager();
  StreamSubscription<CoreStatus>? _statusSub;
  Timer? _uptimeTimer;
  ClashApiClient? _apiClient;

  CoreNotifier(this._ref) : super(CoreState(status: CoreStatus.stopped)) {
    _statusSub = _processManager.statusStream.listen((status) {
      state = state.copyWith(status: status);
      if (status == CoreStatus.running) {
        _startUptimeTimer();
      } else {
        _stopUptimeTimer();
      }
    });
  }

  SingboxProcessManager get processManager => _processManager;
  ClashApiClient? get apiClient => _apiClient;

  void _startUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _processManager.startedAt;
      if (started != null) {
        state = state.copyWith(uptime: DateTime.now().difference(started));
      }
    });
  }

  void _stopUptimeTimer() {
    _uptimeTimer?.cancel();
    _uptimeTimer = null;
    state = state.copyWith(uptime: Duration.zero);
  }

  Future<bool> startCore() async {
    final profilesState = _ref.read(profilesProvider);
    final settings = _ref.read(settingsProvider);
    final activeProfile = profilesState.activeProfile;

    if (activeProfile == null || activeProfile.rawConfig.isEmpty) {
      state = state.copyWith(
        status: CoreStatus.error,
        errorMessage: 'No active profile found. Please add or select a profile first.',
      );
      return false;
    }

    try {
      final parseResult = ProfileParser.parse(activeProfile.rawConfig);
      final configJson = ConfigGenerator.generate(
        settings: settings,
        parsedOutbounds: parseResult.outbounds,
      );

      final configDir = await StorageService.getAppConfigDir();
      final configFile = File('${configDir.path}/config.json');
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(configJson),
      );

      // Create Clash API client
      _apiClient = ClashApiClient(
        host: '127.0.0.1',
        port: settings.clashApiPort,
        secret: settings.clashApiSecret,
      );

      final success = await _processManager.start(
        configPath: configFile.path,
        customBinaryPath: settings.customSingboxPath.isNotEmpty ? settings.customSingboxPath : null,
      );

      if (success) {
        state = state.copyWith(
          status: CoreStatus.running,
          activeProfileName: activeProfile.name,
          errorMessage: null,
        );

        // Configure system proxy if enabled
        if (settings.systemProxyEnabled) {
          await SystemProxyManager.setProxy(
            host: '127.0.0.1',
            port: settings.mixedPort,
          );
        }
      } else {
        state = state.copyWith(
          status: CoreStatus.error,
          errorMessage: 'Failed to start sing-box core.',
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(
        status: CoreStatus.error,
        errorMessage: 'Error generating configuration: $e',
      );
      return false;
    }
  }

  Future<void> stopCore() async {
    // Clear system proxy
    await SystemProxyManager.clearProxy();
    await _processManager.stop();
    _apiClient = null;
    state = state.copyWith(status: CoreStatus.stopped, errorMessage: null);
  }

  Future<bool> restartCore() async {
    await stopCore();
    await Future.delayed(const Duration(milliseconds: 300));
    return await startCore();
  }

  Future<void> toggleCore() async {
    if (state.isRunning) {
      await stopCore();
    } else {
      await startCore();
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _uptimeTimer?.cancel();
    _processManager.dispose();
    super.dispose();
  }
}

final coreProvider = StateNotifierProvider<CoreNotifier, CoreState>((ref) {
  return CoreNotifier(ref);
});

final clashApiClientProvider = Provider<ClashApiClient?>((ref) {
  final coreNotifier = ref.watch(coreProvider.notifier);
  ref.watch(coreProvider.select((s) => s.status));
  return coreNotifier.apiClient;
});
