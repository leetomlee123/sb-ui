import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/core_updater_service.dart';
import '../utils/version_utils.dart';
import 'core_provider.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  installing,
  success,
  error,
}

class CoreUpdaterState {
  final UpdateStatus status;
  final RemoteReleaseInfo? latestRelease;
  final String? currentVersion;
  final double progress;
  final String statusMessage;
  final String? errorMessage;

  CoreUpdaterState({
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

  CoreUpdaterState copyWith({
    UpdateStatus? status,
    RemoteReleaseInfo? latestRelease,
    String? currentVersion,
    double? progress,
    String? statusMessage,
    String? errorMessage,
  }) {
    return CoreUpdaterState(
      status: status ?? this.status,
      latestRelease: latestRelease ?? this.latestRelease,
      currentVersion: currentVersion ?? this.currentVersion,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
    );
  }
}

class CoreUpdaterNotifier extends StateNotifier<CoreUpdaterState> {
  final Ref _ref;
  final CoreUpdaterService _updaterService = CoreUpdaterService();

  CoreUpdaterNotifier(this._ref) : super(CoreUpdaterState());

  Future<void> checkForUpdates({String? customBinaryPath}) async {
    state = state.copyWith(
      status: UpdateStatus.checking,
      statusMessage: 'Checking for latest sing-box release...',
      errorMessage: null,
    );

    // 1. Get current installed version
    String? currentVer;
    try {
      final processMgr = _ref.read(coreProvider.notifier).processManager;
      final binary = await processMgr.findSingboxBinary(customPath: customBinaryPath);
      if (binary != null) {
        final res = await Process.run(binary, ['version']);
        final line = res.stdout.toString().split('\n').firstWhere(
          (l) => l.contains('sing-box version'),
          orElse: () => '',
        );
        if (line.isNotEmpty) {
          final match = RegExp(r'sing-box version ([\d\.\-\w]+)').firstMatch(line);
          if (match != null) {
            currentVer = match.group(1);
          }
        }
      }
    } catch (_) {}

    // 2. Fetch latest release from GitHub
    final latest = await _updaterService.checkLatestRelease();
    if (latest == null) {
      state = state.copyWith(
        status: UpdateStatus.error,
        currentVersion: currentVer,
        errorMessage: 'Failed to connect to GitHub releases.',
      );
      return;
    }

    final hasNewVersion = currentVer == null || isNewerVersion(latest.version, currentVer);

    state = state.copyWith(
      status: hasNewVersion ? UpdateStatus.available : UpdateStatus.upToDate,
      latestRelease: latest,
      currentVersion: currentVer,
      statusMessage: hasNewVersion
          ? 'New version ${latest.tagName} is available'
          : 'Core is up to date ($currentVer)',
    );
  }

  Future<bool> startUpdate() async {
    final release = state.latestRelease;
    if (release == null) return false;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: 0.0,
      statusMessage: 'Starting download...',
      errorMessage: null,
    );

    final coreNotifier = _ref.read(coreProvider.notifier);
    final wasRunning = _ref.read(coreProvider).isRunning;

    try {
      // NOTE: Do NOT stop core during download so that network/proxy continues to run smoothly!
      await _updaterService.downloadAndInstall(
        downloadUrl: release.downloadUrl,
        onProgress: (progress, status) {
          state = state.copyWith(
            progress: progress,
            statusMessage: status,
            status: progress >= 0.92 ? UpdateStatus.installing : UpdateStatus.downloading,
          );
        },
        onBeforeInstall: () async {
          // Stop core ONLY right before replacing the binary file
          if (wasRunning) {
            state = state.copyWith(statusMessage: 'Applying update: stopping core temporarily...');
            await coreNotifier.stopCore();
          }
        },
      );

      state = state.copyWith(
        status: UpdateStatus.success,
        currentVersion: release.version,
        statusMessage: 'Successfully updated sing-box to ${release.tagName}',
      );

      // Restart core if it was running previously
      if (wasRunning) {
        state = state.copyWith(statusMessage: 'Restarting sing-box core with new version...');
        await coreNotifier.startCore();
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: 'Update failed: $e',
      );
      // If core was stopped right before install failure, resume it
      if (wasRunning && !_ref.read(coreProvider).isRunning) {
        await coreNotifier.startCore();
      }
      return false;
    }
  }
}

final coreUpdaterProvider =
    StateNotifierProvider<CoreUpdaterNotifier, CoreUpdaterState>((ref) {
  return CoreUpdaterNotifier(ref);
});
