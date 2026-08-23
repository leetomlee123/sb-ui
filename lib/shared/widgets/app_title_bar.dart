import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/i18n/translations.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';
import 'status_badge.dart';

class AppTitleBar extends ConsumerWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select only the status enum so the per-second uptime tick (new CoreState
    // object) doesn't rebuild the title bar every second.
    final status = ref.watch(coreProvider.select((s) => s.status));
    final tr = ref.watch(translationsProvider);
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080C16) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand & Status
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text(
                'sing-box',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DESKTOP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF818CF8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: status),
            ],
          ),

          // Window Drag Area
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

          // Window Controls
          if (isDesktop)
            Row(
              children: [
                _buildWindowButton(
                  icon: Icons.remove_rounded,
                  size: 16,
                  tooltip: tr.minimize,
                  onTap: () => windowManager.minimize(),
                ),
                const SizedBox(width: 4),
                _buildWindowButton(
                  icon: Icons.crop_square_rounded,
                  size: 14,
                  tooltip: tr.maximize,
                  onTap: () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
                    }
                  },
                ),
                const SizedBox(width: 4),
                _buildWindowButton(
                  icon: Icons.close_rounded,
                  size: 16,
                  tooltip: tr.close,
                  hoverColor: const Color(0xFFF43F5E).withValues(alpha: 0.2),
                  onTap: () async {
                    final settings = ref.read(settingsProvider);
                    if (settings.closeToTray) {
                      await windowManager.hide();
                    } else {
                      await ref.read(coreProvider.notifier).stopCore();
                      exit(0);
                    }
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required double size,
    required String tooltip,
    required VoidCallback onTap,
    Color? hoverColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: const Color(0xFF94A3B8)),
      ),
    );
  }
}
