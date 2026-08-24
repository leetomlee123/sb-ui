import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'app/theme.dart';
import 'core/i18n/translations.dart';
import 'core/providers/app_updater_provider.dart';
import 'core/providers/core_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/storage_provider.dart';
import 'core/services/app_updater_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/system_proxy_manager.dart';
import 'features/shell/main_shell_view.dart';
import 'shared/widgets/close_confirm_dialog.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Flutter framework error handler (prevent UI termination)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // 2. Parallel Fast Boot: initialize storage & window manager concurrently
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final results = await Future.wait([
      StorageService.init(),
      if (isDesktop) windowManager.ensureInitialized(),
    ]);

    final storageService = results[0] as StorageService;
    final initialSettings = storageService.loadSettings();

    // 3. Kick off window display instantly on desktop
    if (isDesktop) {
      const windowOptions = WindowOptions(
        size: Size(1020, 680),
        minimumSize: Size(820, 560),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Singular',
      );

      unawaited(windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true);
        if (!initialSettings.startMinimized) {
          await windowManager.show();
          await windowManager.focus();
        }
      }));
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
        child: const SingboxApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('[Unhandled Exception Shield] $error\n$stackTrace');
  });
}

/// Asynchronous non-blocking maintenance tasks performed in background strictly after the first frame has rendered.
Future<void> _runBackgroundStartupTasks(StorageService storageService) async {
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
}

class SingboxApp extends ConsumerStatefulWidget {
  const SingboxApp({super.key});

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
      unawaited(_runBackgroundStartupTasks(ref.read(storageServiceProvider)));
      unawaited(_initTray());
      _scheduleSilentUpdateCheck();
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
        final tr = ref.read(translationsProvider);
        final iconPath = Platform.isWindows
            ? 'assets/icons/app_icon.ico'
            : 'assets/icons/app_icon.png';

        try {
          await trayManager.setIcon(iconPath);
          await trayManager.setToolTip('Singular');
        } catch (_) {}

        final menu = Menu(
          items: [
            MenuItem(
              key: 'show_window',
              label: tr.trayOpen,
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'toggle_core',
              label: tr.trayToggle,
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
