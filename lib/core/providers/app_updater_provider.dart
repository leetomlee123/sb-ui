import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  AppUpdaterState({
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
  final Ref _ref;
  final AppUpdaterService _updaterService = AppUpdaterService();

  AppUpdaterNotifier(this._ref) : super(AppUpdaterState(currentVersion: '1.2.14')) {
    _initCurrentVersion();
  }

  Future<void> _initCurrentVersion() async {
    final ver = await _resolveCurrentVersion();
    state = state.copyWith(currentVersion: ver);
  }

  Future<String> _resolveCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty && info.version.contains('.')) {
        return normalizeSemver(info.version);
      }
      final desktopVer = await _updaterService.getCurrentVersion();
      if (desktopVer != null && desktopVer.isNotEmpty && desktopVer.contains('.')) {
        return normalizeSemver(desktopVer);
      }
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

  /// Checks GitHub Releases of the app itself against the running version.
  Future<void> checkForUpdates() async {
    _syncProxy();
    state = state.copyWith(
      status: UpdateStatus.checking,
      statusMessage: 'Checking for latest release...',
      errorMessage: null,
    );

    // 1. Resolve the running app version
    final currentVer = await _resolveCurrentVersion();

    // 2. Fetch the latest release from GitHub.
    final latest = await _updaterService.checkLatestRelease();
    if (latest == null) {
      state = state.copyWith(
        status: UpdateStatus.error,
        currentVersion: currentVer,
        errorMessage: 'Failed to connect to GitHub releases.',
      );
      return;
    }

    final hasNewVersion = isNewerVersion(latest.version, currentVer);

    state = state.copyWith(
      status: hasNewVersion ? UpdateStatus.available : UpdateStatus.upToDate,
      latestRelease: latest,
      currentVersion: currentVer,
      statusMessage: hasNewVersion
          ? 'New version ${latest.tagName} is available'
          : 'App is up to date ($currentVer)',
    );
  }

  /// Downloads, verifies and stages the new bundle, then hands over to a
  /// detached batch script that swaps files after this process exits.
  Future<bool> applyUpdate() async {
    _syncProxy();
    final release = state.latestRelease;
    if (release == null) return false;

    if (!Platform.isWindows) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'In-app update is not supported on this platform yet.',
      );
      return false;
    }

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

      // Hand over to desktop_updater native plugin for atomic installation & restart
      await _updaterService.installNativeUpdate(
        stagingPath: stagingDir,
        version: release.version,
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
