import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'app/theme.dart';
import 'core/i18n/translations.dart';
import 'core/models/app_settings.dart';
import 'core/providers/app_updater_provider.dart';
import 'core/providers/core_provider.dart';
import 'core/providers/geo_updater_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/storage_provider.dart';
import 'core/services/app_updater_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/system_proxy_manager.dart';
import 'core/utils/app_logger.dart';
import 'features/shell/main_shell_view.dart';
import 'shared/widgets/close_confirm_dialog.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  final dartStartEpochMs = DateTime.now().millisecondsSinceEpoch;
  final appStartStopwatch = Stopwatch()..start();

  int? nativeStartEpochMs;
  for (final arg in args) {
    if (arg.startsWith('--native-start-epoch-ms=')) {
      nativeStartEpochMs = int.tryParse(arg.substring('--native-start-epoch-ms='.length));
    }
  }

  int? nativePreDartMs;
  if (nativeStartEpochMs != null) {
    final diff = dartStartEpochMs - nativeStartEpochMs;
    if (diff >= 0) {
      nativePreDartMs = diff;
      AppLogger.info(
        '[Native Startup] C++ 原生引擎与 Dart 运行时底层加载耗时: ${diff}ms',
      );
    }
  }

  AppLogger.info('[App Startup] 应用程序初始化启动...');

  runZonedGuarded(() async {
    final initStopwatch = Stopwatch()..start();
    WidgetsFlutterBinding.ensureInitialized();

    // Query and output fine-grained native embedder stage breakdown on Windows
    if (Platform.isWindows) {
      unawaited(() async {
        try {
          const channel = MethodChannel('com.example.sb_ui/tun_process');
          final timings = await channel.invokeMapMethod<String, dynamic>('getNativeStartupTimings');
          if (timings != null) {
            final comInit = timings['comInitMs'] ?? 0;
            final winCreate = timings['windowCreateMs'] ?? 0;
            final engineInit = timings['engineInitMs'] ?? 0;
            final pluginsTotal = timings['pluginsTotalMs'] ?? 0;
            final p1 = timings['desktopUpdaterMs'] ?? 0;
            final p2 = timings['trayManagerMs'] ?? 0;
            final p3 = timings['windowManagerMs'] ?? 0;
            final p4 = timings['tunBridgeMs'] ?? 0;
            final childContent = timings['childContentMs'] ?? 0;
            final accounted = (comInit as int) + (winCreate as int) + (engineInit as int) + (pluginsTotal as int) + (childContent as int);
            final dispatch = (nativePreDartMs != null && nativePreDartMs > accounted)
                ? (nativePreDartMs - accounted)
                : 0;

            AppLogger.info('[Native Startup] ├── 1. 基础环境与 COM 初始化: ${comInit}ms');
            AppLogger.info('[Native Startup] ├── 2. Win32 宿主窗口建立 (CreateWindowEx): ${winCreate}ms');
            AppLogger.info('[Native Startup] ├── 3. FlutterEngine / Dart AOT 快照载入 (VM & GPU): ${engineInit}ms');
            AppLogger.info('[Native Startup] ├── 4. Native 插件注册 (总计: ${pluginsTotal}ms):');
            AppLogger.info('[Native Startup] │   ├── desktop_updater: ${p1}ms | tray: ${p2}ms | window: ${p3}ms | tun: ${p4}ms');
            AppLogger.info('[Native Startup] └── 5. 视图绑定与消息循环调度至 Dart main(): ${dispatch}ms');
          }
        } catch (_) {}
      }());
    }

    // 1. Flutter framework & root isolate unhandled error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppLogger.error('[FlutterError] ${details.exceptionAsString()}');
      FirebaseService.recordException(details.exception, stackTrace: details.stack, reason: 'flutter_framework');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('[PlatformDispatcher] Unhandled isolate error: $error\n$stack');
      FirebaseService.recordException(error, stackTrace: stack, reason: 'platform_dispatcher', fatal: true);
      return true;
    };

    // 2. Parallel Fast Boot: initialize storage & window manager concurrently
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final results = await Future.wait([
      StorageService.init(),
      if (isDesktop) windowManager.ensureInitialized(),
    ]);

    final storageService = results[0] as StorageService;
    final initialSettings = storageService.loadSettings();
    initStopwatch.stop();

    AppLogger.info(
      '[App Startup] 核心基础存储与窗口系统初始化完成 (耗时: ${initStopwatch.elapsedMilliseconds}ms)',
    );

    // 3. Kick off window configuration on desktop (hide native frame & native caption buttons)
    if (isDesktop) {
      final windowStopwatch = Stopwatch()..start();
      unawaited(() async {
        try {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: false,
          );
          await windowManager.setPreventClose(true);
          if (initialSettings.startMinimized) {
            await windowManager.hide();
          }
        } catch (_) {}
        windowStopwatch.stop();
        AppLogger.info(
          '[App Startup] 桌面无边框窗口配置就绪 (耗时: ${windowStopwatch.elapsedMilliseconds}ms)',
        );
      }());
    }

    // 4. Mount App immediately (zero background I/O or pre-frame overhead)
    runApp(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
          settingsProvider.overrideWith((ref) => SettingsNotifier(
                ref.watch(storageServiceProvider),
                initial: initialSettings,
              )),
        ],
        child: SingboxApp(
          appStartStopwatch: appStartStopwatch,
          nativeStartEpochMs: nativeStartEpochMs,
        ),
      ),
    );
  }, (error, stackTrace) {
    AppLogger.error('[Unhandled Exception Shield] $error\n$stackTrace');
    FirebaseService.recordException(error, stackTrace: stackTrace, reason: 'unhandled_zone', fatal: true);
  });
}

/// Asynchronous non-blocking maintenance tasks performed in background strictly after the first frame has rendered.
Future<void> _runBackgroundStartupTasks(StorageService storageService) async {
  final bgStopwatch = Stopwatch()..start();

  // 0. Initialize Firebase & log startup telemetry
  try {
    await FirebaseService.init();
    await FirebaseService.logEvent('app_startup_completed');
  } catch (_) {}

  // 1. Clear any orphan system proxy left by abnormal previous shutdowns.
  //    Only spawns PowerShell when the dirty flag says a proxy of ours may
  //    still be applied — skips it entirely on normal launches.
  if (storageService.isSystemProxyDirty()) {
    try {
      final cleared = await SystemProxyManager.clearProxy();
      if (cleared) await storageService.setSystemProxyDirty(false);
    } catch (_) {}
  }

  // 2. Ensure bundled SRS rules exist on disk
  try {
    await StorageService.ensureBundledRulesExtracted();
  } catch (_) {}

  // 3. Clean up leftover rollback .old files or stale update staging dirs
  try {
    await AppUpdaterService.cleanupOnStartup();
  } catch (_) {}

  bgStopwatch.stop();
  AppLogger.info(
    '[App Startup] 后台启动自检与维护任务完成 (耗时: ${bgStopwatch.elapsedMilliseconds}ms)',
  );
}

class SingboxApp extends ConsumerStatefulWidget {
  final Stopwatch? appStartStopwatch;
  final int? nativeStartEpochMs;
  const SingboxApp({super.key, this.appStartStopwatch, this.nativeStartEpochMs});

  @override
  ConsumerState<SingboxApp> createState() => _SingboxAppState();
}

class _SingboxAppState extends ConsumerState<SingboxApp> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    // Graceful-shutdown primitive shared with the self-updater.
    appShutdownHook = _exitApplication;

    // Defer all maintenance IO and tray registration until after the first frame has rendered on screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.appStartStopwatch != null && widget.appStartStopwatch!.isRunning) {
        widget.appStartStopwatch!.stop();
        final dartRenderMs = widget.appStartStopwatch!.elapsedMilliseconds;
        AppLogger.info(
          '[App Startup] Dart 业务层首帧渲染完成 (耗时: ${dartRenderMs}ms)',
        );

        if (widget.nativeStartEpochMs != null) {
          final totalPhysicalMs = DateTime.now().millisecondsSinceEpoch - widget.nativeStartEpochMs!;
          AppLogger.info(
            '[App Startup] 从双击 EXE 到首帧呈现实时物理总耗时: ${totalPhysicalMs}ms',
          );
          FirebaseService.logAppStartup(launchTimeMs: totalPhysicalMs, nativeLoadMs: dartRenderMs);
        } else {
          AppLogger.info(
            '[App Startup] 应用首帧渲染完成，总冷启动耗时: ${dartRenderMs}ms',
          );
          FirebaseService.logAppStartup(launchTimeMs: dartRenderMs);
        }
      }
      unawaited(_runBackgroundStartupTasks(ref.read(storageServiceProvider)));
      unawaited(_initTray());
      _scheduleSilentUpdateCheck();
      _scheduleSilentRulesetUpdate();
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final iconPath = Platform.isWindows
            ? 'assets/icons/app_icon.ico'
            : 'assets/icons/app_icon.png';

        try {
          await Future.wait([
            trayManager.setIcon(iconPath),
            trayManager.setToolTip('Singular'),
          ]);
        } catch (_) {}

        await _updateTrayMenu();
      }
    } catch (_) {}
  }

  Future<void> _updateTrayMenu() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final tr = ref.read(translationsProvider);
        final settings = ref.read(settingsProvider);
        final isRunning = ref.read(coreProvider).isRunning;
        final routingMode = settings.routingMode;

        final menu = Menu(
          items: [
            MenuItem(
              key: 'show_window',
              label: tr.trayOpen,
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'toggle_core',
              label: isRunning ? (tr.isZh ? '断开连接 (停止核心)' : 'Disconnect') : (tr.isZh ? '启动连接' : 'Connect'),
            ),
            MenuItem(
              key: 'restart_core',
              label: tr.restartCore,
              disabled: !isRunning,
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'mode_rule',
              label: '${routingMode == RoutingMode.rule ? "✓ " : "   "}${tr.modeRule}',
            ),
            MenuItem(
              key: 'mode_global',
              label: '${routingMode == RoutingMode.global ? "✓ " : "   "}${tr.modeGlobal}',
            ),
            MenuItem(
              key: 'mode_direct',
              label: '${routingMode == RoutingMode.direct ? "✓ " : "   "}${tr.modeDirect}',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'exit_app',
              label: tr.trayQuit,
            ),
          ],
        );
        await trayManager.setContextMenu(menu);
      }
    } catch (_) {}
  }

  /// Silent background check for app updates, kept off the startup path.
  void _scheduleSilentUpdateCheck() {
    Future.delayed(const Duration(seconds: 8), () async {
      if (!mounted) return;
      try {
        if (!ref.read(settingsProvider).autoCheckAppUpdates) return;
        await ref.read(appUpdaterProvider.notifier).checkForUpdates();
      } catch (_) {}
    });
  }

  /// Silent background update for GeoIP / GeoSite Rule-Sets (.srs), kept off the startup critical path.
  void _scheduleSilentRulesetUpdate() {
    Future.delayed(const Duration(seconds: 12), () async {
      if (!mounted) return;
      try {
        if (!ref.read(settingsProvider).autoUpdateRuleset) return;
        AppLogger.info('[Ruleset] 启动后自动检查并更新 GeoIP / GeoSite 规则集...');
        await ref.read(geoUpdaterProvider.notifier).updateAllAssets(silent: true);
      } catch (e) {
        AppLogger.warn('[Ruleset] 后台自动更新规则集异常: $e');
      }
    });
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'toggle_core':
        ref.read(coreProvider.notifier).toggleCore();
        break;
      case 'restart_core':
        ref.read(coreProvider.notifier).restartCore();
        break;
      case 'mode_rule':
        await ref.read(settingsProvider.notifier).setRoutingMode(RoutingMode.rule);
        _updateTrayMenu();
        break;
      case 'mode_global':
        await ref.read(settingsProvider.notifier).setRoutingMode(RoutingMode.global);
        _updateTrayMenu();
        break;
      case 'mode_direct':
        await ref.read(settingsProvider.notifier).setRoutingMode(RoutingMode.direct);
        _updateTrayMenu();
        break;
      case 'exit_app':
        await _exitApplication();
        break;
    }
  }

  @override
  void onWindowClose() async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasAskedCloseToTray) {
      await windowManager.show();
      await windowManager.focus();
      if (!mounted) return;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await showDialog(
          context: ctx,
          barrierDismissible: false,
          builder: (dialogCtx) => const CloseConfirmDialog(),
        );
      }
      return;
    }

    if (settings.closeToTray) {
      await windowManager.hide();
    } else {
      await _exitApplication();
    }
  }

  Future<void> _exitApplication() async {
    try {
      await ref.read(coreProvider.notifier).stopCore().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => false,
      );
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    ThemeMode themeMode = ThemeMode.dark;
    if (settings.themeMode == 'light') {
      themeMode = ThemeMode.light;
    } else if (settings.themeMode == 'system') {
      themeMode = ThemeMode.system;
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Singular',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShellView(),
    );
  }
}
