import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import '../services/app_updater_service.dart';
import '../services/core_updater_service.dart';
import '../utils/version_utils.dart';
import 'core_provider.dart';
import 'core_updater_provider.dart';
import 'settings_provider.dart';

/// Assigned by main.dart at startup; performs graceful shutdown
/// (stop core -> destroy tray/window -> exit). Invoked right before the
/// detached self-swap script takes over during applyUpdate().
Future<void> Function()? appShutdownHook;

class AppUpdaterState {
  final UpdateStatus status;
  final RemoteReleaseInfo? latestRelease;
  final String? currentVersion;
  final double progress;
  final String statusMessage;
  final String? errorMessage;

  const AppUpdaterState({
    this.status = UpdateStatus.idle,
    this.latestRelease,
    this.currentVersion,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
  });

  bool get isBusy =>
      status == UpdateStatus.checking ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.installing;

  bool get hasUpdate =>
      status == UpdateStatus.available && latestRelease != null;

  AppUpdaterState copyWith({
    UpdateStatus? status,
    RemoteReleaseInfo? latestRelease,
    String? currentVersion,
    double? progress,
    String? statusMessage,
    String? errorMessage,
  }) {
    return AppUpdaterState(
      status: status ?? this.status,
      latestRelease: latestRelease ?? this.latestRelease,
      currentVersion: currentVersion ?? this.currentVersion,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
    );
  }
}

class AppUpdaterNotifier extends StateNotifier<AppUpdaterState> {
  final AppUpdaterService _updaterService;
  final Ref _ref;

  AppUpdaterNotifier(this._ref, {AppUpdaterService? updaterService})
      : _updaterService = updaterService ?? AppUpdaterService(),
        super(const AppUpdaterState()) {
    init();
  }

  Future<void> init() async {
    final ver = await getCurrentVersion();
    state = state.copyWith(currentVersion: ver);
  }

  Future<String> getCurrentVersion() async {
    try {
      final desktopVer = await _updaterService.getCurrentVersion();
      if (desktopVer != null && desktopVer.isNotEmpty && desktopVer.contains('.')) {
        return normalizeSemver(desktopVer);
      }
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty && info.version != '0.0.0') {
        return normalizeSemver(info.version);
      }
    } catch (_) {}
    return '1.2.15';
  }

  void _syncProxy() {
    final isCoreRunning = _ref.read(coreProvider).isRunning;
    final mixedPort = _ref.read(settingsProvider).mixedPort;
    _updaterService.setProxyPort(isCoreRunning ? mixedPort : null);
  }

  Future<void> checkForUpdates({bool manual = false}) async {
    if (state.status == UpdateStatus.checking ||
        state.status == UpdateStatus.downloading ||
        state.status == UpdateStatus.installing) {
      return;
    }

    _syncProxy();

    state = state.copyWith(
      status: UpdateStatus.checking,
      errorMessage: null,
    );

    try {
      final currentVer = await getCurrentVersion();
      final latest = await _updaterService.checkLatestRelease();

      if (latest == null) {
        state = state.copyWith(
          status: UpdateStatus.idle,
          latestRelease: null,
          currentVersion: currentVer,
          statusMessage: manual ? 'Currently on the latest version' : null,
        );
        return;
      }

      final hasUpdate = isNewerVersion(latest.version, currentVer);

      state = state.copyWith(
        status: hasUpdate ? UpdateStatus.available : UpdateStatus.idle,
        latestRelease: latest,
        currentVersion: currentVer,
        statusMessage: hasUpdate
            ? 'New version ${latest.tagName} is available'
            : (manual ? 'Currently on the latest version' : null),
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Check failed: $e',
      );
    }
  }

  Future<bool> applyUpdate() async {
    final release = state.latestRelease;
    if (release == null || release.downloadUrl.isEmpty) return false;

    _syncProxy();

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Starting download...',
      errorMessage: null,
    );

    try {
      final stagingDir = await _updaterService.downloadAndPrepare(
        downloadUrl: release.downloadUrl,
        sha256SumsUrl: release.sha256SumsUrl,
        onProgress: (progress, status) {
          state = state.copyWith(
            progress: progress,
            statusMessage: status,
            status: progress >= 0.95 ? UpdateStatus.installing : UpdateStatus.downloading,
          );
        },
      );

      state = state.copyWith(
        status: UpdateStatus.installing,
        statusMessage: 'Preparing to restart...',
      );

      final exePath = (await _updaterService.getExecutablePath()) ?? Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;
      final exeName = p.basename(exePath);

      // Launch background self-updater detached from this process
      await _updaterService.prepareAndLaunchUpdate(
        stagingPath: stagingDir,
        appDir: appDir,
        exeName: exeName,
      );

      // Stop sing-box core cleanly to release TUN handles and port bindings
      try {
        await _ref.read(coreProvider.notifier).stopCore();
      } catch (_) {}

      final hook = appShutdownHook;
      if (hook != null) {
        await hook();
      } else {
        exit(0);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Update failed: $e',
      );
      return false;
    }
  }
}

final appUpdaterProvider =
    StateNotifierProvider<AppUpdaterNotifier, AppUpdaterState>((ref) {
  return AppUpdaterNotifier(ref);
});
