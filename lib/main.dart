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

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Flutter framework error handler (prevent UI termination)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // 2. Clear any stale orphan system proxy on app startup
    try {
      await SystemProxyManager.clearProxy();
    } catch (_) {}

    // 3. Initialize persistent storage & ensure offline rule sets are extracted
    final storageService = await StorageService.init();
    await StorageService.ensureBundledRulesExtracted();
    final initialSettings = storageService.loadSettings();

    // 3.5 Clean up leftovers from a previous self-update (rollback .old
    // binary and stale temp staging dirs).
    try {
      await AppUpdaterService.cleanupOnStartup();
    } catch (_) {}

    // 4. Desktop window & tray setup
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.ensureInitialized();

        const windowOptions = WindowOptions(
          size: Size(1020, 680),
          minimumSize: Size(820, 560),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
          title: 'Singular',
        );

        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.setPreventClose(true);
          if (!initialSettings.startMinimized) {
            await windowManager.show();
            await windowManager.focus();
          }
        });
      } catch (_) {}
    }

    runApp(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const SingboxApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('[Unhandled Exception Shield] $error\n$stackTrace');
  });
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
    _initTray();
    _scheduleSilentUpdateCheck();
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
          await trayManager.setToolTip('sing-box Desktop');
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
      title: 'Singular',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShellView(),
    );
  }
}
