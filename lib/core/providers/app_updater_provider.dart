import 'dart:io';
import 'package:desktop_updater/desktop_updater.dart';
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
  DesktopUpdaterController? _controller;

  AppUpdaterNotifier(this._ref, {AppUpdaterService? updaterService})
      : _updaterService = updaterService ?? AppUpdaterService(),
        super(const AppUpdaterState()) {
    init();
  }

  DesktopUpdaterController? get controller => _controller;

  Future<void> init() async {
    final ver = await getCurrentVersion();
    state = state.copyWith(currentVersion: ver);

    try {
      _controller = await AppUpdaterService.createDesktopUpdaterController();
      _controller?.addListener(_onControllerStateChanged);
    } catch (_) {}
  }

  void _onControllerStateChanged() {
    final c = _controller;
    if (c == null) return;
    final cState = c.state;

    if (cState is UpdateDownloading) {
      final total = cState.totalBytes;
      final progress = total > 0 ? (cState.receivedBytes / total).clamp(0.0, 1.0) : 0.0;
      state = state.copyWith(
        status: UpdateStatus.downloading,
        progress: progress,
        statusMessage: 'Downloading: ${(cState.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
    } else if (cState is UpdateReadyToInstall) {
      state = state.copyWith(
        status: UpdateStatus.installing,
        progress: 1.0,
        statusMessage: 'Ready to restart',
      );
    } else if (cState is UpdateInstalling) {
      state = state.copyWith(
        status: UpdateStatus.installing,
        progress: 1.0,
        statusMessage: 'Installing update...',
      );
    } else if (cState is UpdateFailed) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: cState.error.toString(),
      );
    }
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
    return '1.2.17';
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

      // 1. Try official desktop_updater controller check first
      if (_controller != null) {
        try {
          final res = await _controller!.checkForUpdates();
          if (res is ManualUpdateCheckAvailable) {
            state = state.copyWith(
              status: UpdateStatus.available,
              currentVersion: currentVer,
              statusMessage: 'New version ${res.descriptor.version} is available',
            );
            return;
          } else if (res is ManualUpdateCheckUpToDate) {
            state = state.copyWith(
              status: UpdateStatus.idle,
              currentVersion: currentVer,
              statusMessage: manual ? 'Currently on the latest version' : null,
            );
            return;
          }
        } catch (_) {}
      }

      // 2. Fallback to GitHub Releases API
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
    _syncProxy();

    // 1. If desktop_updater controller has an active update, use official desktop_updater flow
    if (_controller != null && _controller!.state is UpdateAvailable) {
      try {
        state = state.copyWith(
          status: UpdateStatus.downloading,
          progress: 0.0,
          statusMessage: 'Downloading update via desktop_updater...',
        );
        await _controller!.downloadUpdate();

        state = state.copyWith(
          status: UpdateStatus.installing,
          statusMessage: 'Restarting application...',
        );

        try {
          await _ref.read(coreProvider.notifier).stopCore();
        } catch (_) {}

        final hook = appShutdownHook;
        if (hook != null) await hook();

        await _controller!.restartApp();
        return true;
      } catch (_) {
        // Continue to fallback if desktop_updater controller fails
      }
    }

    // 2. Direct release bundle self-update
    final release = state.latestRelease;
    if (release == null || release.downloadUrl.isEmpty) return false;

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

  @override
  void dispose() {
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    super.dispose();
  }
}

final appUpdaterProvider =
    StateNotifierProvider<AppUpdaterNotifier, AppUpdaterState>((ref) {
  return AppUpdaterNotifier(ref);
});
