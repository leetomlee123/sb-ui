import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/process/singbox_process_manager.dart';

class StatusBadge extends ConsumerWidget {
  final CoreStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(translationsProvider);
    Color color;
    Color bgColor;
    String text;

    switch (status) {
      case CoreStatus.running:
        color = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
        text = tr.running;
        break;
      case CoreStatus.starting:
        color = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        text = tr.starting;
        break;
      case CoreStatus.error:
        color = const Color(0xFFF43F5E);
        bgColor = const Color(0xFFF43F5E).withValues(alpha: 0.12);
        text = tr.error;
        break;
      case CoreStatus.stopped:
        color = const Color(0xFF94A3B8);
        bgColor = const Color(0xFF94A3B8).withValues(alpha: 0.1);
        text = tr.stopped;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: status == CoreStatus.running
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.8),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
