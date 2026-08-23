import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';
import 'status_badge.dart';

class AppTitleBar extends ConsumerWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(coreProvider);
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo & Title
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text(
                'sing-box UI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: coreState.status),
            ],
          ),

          // Draggable window area
          Expanded(
            child: isDesktop
                ? GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      windowManager.startDragging();
                    },
                    onDoubleTap: () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    child: Container(),
                  )
                : Container(),
          ),

          // Window control buttons
          if (isDesktop)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  tooltip: 'Minimize',
                  splashRadius: 18,
                  onPressed: () async {
                    await windowManager.minimize();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.crop_square, size: 16),
                  tooltip: 'Maximize',
                  splashRadius: 18,
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close',
                  splashRadius: 18,
                  hoverColor: Colors.red.withValues(alpha: 0.2),
                  onPressed: () async {
                    final settings = ref.read(settingsProvider);
                    if (settings.closeToTray) {
                      await windowManager.hide();
                    } else {
                      await windowManager.close();
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
