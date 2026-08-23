import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import '../services/app_updater_service.dart';
import '../services/core_updater_service.dart';
import '../utils/version_utils.dart';
import 'core_updater_provider.dart';

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
  final AppUpdaterService _updaterService = AppUpdaterService();

  AppUpdaterNotifier() : super(AppUpdaterState());

  /// Checks GitHub Releases of the app itself against the running version.
  Future<void> checkForUpdates() async {
    state = state.copyWith(
      status: UpdateStatus.checking,
      statusMessage: 'Checking for latest release...',
      errorMessage: null,
    );

    // 1. Resolve the running app version from the executable metadata.
    String currentVer;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVer = info.version;
    } catch (_) {
      currentVer = '0.0.0';
    }

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

      final exePath = Platform.resolvedExecutable;
      final scriptPath = await _updaterService.writeSwapScript(
        stagingDir: stagingDir,
        appDir: File(exePath).parent.path,
        exeName: p.basename(exePath),
      );

      // Hand control to the script; it waits for this process to exit,
      // swaps the files, deletes the rollback copy and relaunches the app.
      await _updaterService.launchDetached(scriptPath);

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
  return AppUpdaterNotifier();
});
