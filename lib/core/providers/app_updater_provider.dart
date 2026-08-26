import 'dart:io';
import 'package:desktop_updater/desktop_updater.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import '../services/app_updater_service.dart';
import '../services/core_updater_service.dart';
import '../utils/app_logger.dart';
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
        statusMessage: '正在下载: ${(cState.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
    } else if (cState is UpdateReadyToInstall) {
      AppLogger.info('[AppUpdater] desktop_updater: 更新包已准备就绪');
      state = state.copyWith(
        status: UpdateStatus.installing,
        progress: 1.0,
        statusMessage: '更新下载完成，准备重启',
      );
    } else if (cState is UpdateInstalling) {
      AppLogger.info('[AppUpdater] desktop_updater: 正在安装并调度重启...');
      state = state.copyWith(
        status: UpdateStatus.installing,
        progress: 1.0,
        statusMessage: '正在安装更新...',
      );
    } else if (cState is UpdateFailed) {
      AppLogger.error('[AppUpdater] desktop_updater 运行故障: ${cState.error}');
      // Only transition to error if not currently in a checking fallback sequence
      if (state.status != UpdateStatus.checking) {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: cState.error.toString(),
          statusMessage: '更新失败',
        );
      }
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
    return '1.2.21';
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
    final currentVer = await getCurrentVersion();
    AppLogger.info('[AppUpdater] 开始检查应用更新 (当前版本: v$currentVer)...');

    state = state.copyWith(
      status: UpdateStatus.checking,
      errorMessage: null,
      statusMessage: '正在检查更新...',
    );

    String? lastError;

    // 1. Try official desktop_updater controller check first
    if (_controller != null) {
      try {
        final res = await _controller!.checkForUpdates();
        if (res is ManualUpdateCheckAvailable) {
          AppLogger.info('[AppUpdater] 发现新版本: v${res.descriptor.version} (via desktop_updater)');
          state = state.copyWith(
            status: UpdateStatus.available,
            currentVersion: currentVer,
            statusMessage: '发现新版本 v${res.descriptor.version}',
          );
          return;
        } else if (res is ManualUpdateCheckUpToDate) {
          AppLogger.info('[AppUpdater] 当前已是最新版本 (v$currentVer)');
          state = state.copyWith(
            status: UpdateStatus.idle,
            currentVersion: currentVer,
            statusMessage: manual ? '当前已是最新版本' : null,
          );
          return;
        } else if (res is ManualUpdateCheckFailed) {
          lastError = res.error.toString();
          AppLogger.warn('[AppUpdater] desktop_updater 检查失败: $lastError，正在尝试 GitHub 接口回退...');
        }
      } catch (e) {
        lastError = e.toString();
        AppLogger.warn('[AppUpdater] desktop_updater 检查异常: $e，正在尝试 GitHub 接口回退...');
      }
    }

    // 2. Fallback to GitHub Releases API
    try {
      final latest = await _updaterService.checkLatestRelease();
      if (latest == null) {
        if (lastError != null) {
          final errText = '检查更新失败: $lastError';
          AppLogger.error('[AppUpdater] $errText');
          state = state.copyWith(
            status: UpdateStatus.error,
            currentVersion: currentVer,
            errorMessage: errText,
            statusMessage: '检查更新失败',
          );
          return;
        }
        AppLogger.info('[AppUpdater] 未检测到新版本发布');
        state = state.copyWith(
          status: UpdateStatus.idle,
          latestRelease: null,
          currentVersion: currentVer,
          statusMessage: manual ? '当前已是最新版本' : null,
        );
        return;
      }

      final hasUpdate = isNewerVersion(latest.version, currentVer);
      if (hasUpdate) {
        AppLogger.info('[AppUpdater] 发现新版本: ${latest.tagName} (发布时间: ${latest.publishedAt})');
        state = state.copyWith(
          status: UpdateStatus.available,
          latestRelease: latest,
          currentVersion: currentVer,
          statusMessage: '发现新版本 ${latest.tagName}',
        );
      } else {
        AppLogger.info('[AppUpdater] 当前版本 v$currentVer 已是最新版本');
        state = state.copyWith(
          status: UpdateStatus.idle,
          latestRelease: latest,
          currentVersion: currentVer,
          statusMessage: manual ? '当前已是最新版本' : null,
        );
      }
    } catch (e) {
      final errText = '检查更新失败: $e';
      AppLogger.error('[AppUpdater] $errText');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: errText,
        statusMessage: '检查更新失败',
      );
    }
  }

  Future<bool> applyUpdate() async {
    _syncProxy();
    AppLogger.info('[AppUpdater] 用户触发应用更新...');

    // 1. If desktop_updater controller has an active update, use official desktop_updater flow
    if (_controller != null && _controller!.state is UpdateAvailable) {
      try {
        AppLogger.info('[AppUpdater] 使用 desktop_updater 开始下载更新...');
        state = state.copyWith(
          status: UpdateStatus.downloading,
          progress: 0.0,
          statusMessage: '正在通过 desktop_updater 下载更新...',
        );
        await _controller!.downloadUpdate();

        AppLogger.info('[AppUpdater] 更新下载完成，停止 sing-box 并调度重启...');
        state = state.copyWith(
          status: UpdateStatus.installing,
          statusMessage: '正在准备重启应用...',
        );

        try {
          await _ref.read(coreProvider.notifier).stopCore();
        } catch (_) {}

        final hook = appShutdownHook;
        if (hook != null) await hook();

        await _controller!.restartApp();
        return true;
      } catch (e) {
        AppLogger.error('[AppUpdater] desktop_updater 更新过程异常: $e');
        // Continue to fallback if desktop_updater controller fails
      }
    }

    // 2. Direct release bundle self-update
    final release = state.latestRelease;
    if (release == null || release.downloadUrl.isEmpty) {
      AppLogger.error('[AppUpdater] 无可用下载地址');
      return false;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: 0.0,
      statusMessage: '开始下载更新包...',
      errorMessage: null,
    );

    try {
      AppLogger.info('[AppUpdater] 开始下载便携更新包: ${release.downloadUrl}');
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

      AppLogger.info('[AppUpdater] 更新包已解压至暂存目录: $stagingDir');
      state = state.copyWith(
        status: UpdateStatus.installing,
        statusMessage: '准备重启并完成自替换...',
      );

      final exePath = (await _updaterService.getExecutablePath()) ?? Platform.resolvedExecutable;
      final appDir = File(exePath).parent.path;
      final exeName = p.basename(exePath);

      AppLogger.info('[AppUpdater] 启动后台更新进程: $exeName -> $appDir');
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
      final errText = '更新失败: $e';
      AppLogger.error('[AppUpdater] $errText');
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: errText,
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
