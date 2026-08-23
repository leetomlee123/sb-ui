import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'app/theme.dart';
import 'core/providers/core_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/storage_provider.dart';
import 'core/services/storage_service.dart';
import 'features/shell/main_shell_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent storage
  final storageService = await StorageService.init();

  // Desktop window & tray setup
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
        title: 'sing-box Desktop',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
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
}

class SingboxApp extends ConsumerStatefulWidget {
  const SingboxApp({super.key});

  @override
  ConsumerState<SingboxApp> createState() => _SingboxAppState();
}

class _SingboxAppState extends ConsumerState<SingboxApp> with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Set context menu for tray
        final menu = Menu(
          items: [
            MenuItem(
              key: 'show_window',
              label: 'Show sing-box',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'toggle_core',
              label: 'Toggle Connection',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'exit_app',
              label: 'Quit',
            ),
          ],
        );
        await trayManager.setContextMenu(menu);
      }
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        windowManager.show();
        windowManager.focus();
        break;
      case 'toggle_core':
        ref.read(coreProvider.notifier).toggleCore();
        break;
      case 'exit_app':
        ref.read(coreProvider.notifier).stopCore();
        exit(0);
    }
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
      title: 'sing-box UI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShellView(),
    );
  }
}
