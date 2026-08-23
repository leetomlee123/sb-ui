import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/i18n/translations.dart';
import '../../core/providers/core_provider.dart';
import '../../core/providers/settings_provider.dart';

class CloseConfirmDialog extends ConsumerStatefulWidget {
  const CloseConfirmDialog({super.key});

  @override
  ConsumerState<CloseConfirmDialog> createState() => _CloseConfirmDialogState();
}

class _CloseConfirmDialogState extends ConsumerState<CloseConfirmDialog> {
  bool _closeToTray = true;
  bool _rememberChoice = true;

  Future<void> _handleConfirm() async {
    Navigator.of(context).pop();

    // 1. Save user preference
    await ref.read(settingsProvider.notifier).setCloseToTrayPreference(
          closeToTray: _closeToTray,
          rememberChoice: _rememberChoice,
        );

    // 2. Perform action
    if (_closeToTray) {
      await windowManager.hide();
    } else {
      try {
        await ref.read(coreProvider.notifier).stopCore();
      } catch (_) {}
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(translationsProvider);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFF818CF8), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            tr.closeDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Option 1: Minimize to Tray (Recommended)
            InkWell(
              onTap: () => setState(() => _closeToTray = true),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _closeToTray
                        ? const Color(0xFF818CF8)
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: _closeToTray ? 1.5 : 1,
                  ),
                  color: _closeToTray
                      ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      _closeToTray ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: _closeToTray ? const Color(0xFF818CF8) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.closeActionMinimize,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr.closeActionMinimizeDesc,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Option 2: Exit Program
            InkWell(
              onTap: () => setState(() => _closeToTray = false),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !_closeToTray
                        ? const Color(0xFFF43F5E)
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: !_closeToTray ? 1.5 : 1,
                  ),
                  color: !_closeToTray
                      ? const Color(0xFFF43F5E).withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      !_closeToTray ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: !_closeToTray ? const Color(0xFFF43F5E) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.closeActionExit,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr.closeActionExitDesc,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Remember Choice Checkbox
            CheckboxListTile(
              value: _rememberChoice,
              onChanged: (val) => setState(() => _rememberChoice = val ?? true),
              title: Text(
                tr.rememberChoice,
                style: const TextStyle(fontSize: 12),
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr.cancel),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: Text(tr.confirm),
        ),
      ],
    );
  }
}
