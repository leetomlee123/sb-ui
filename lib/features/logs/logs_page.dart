import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/log_entry.dart';
import '../../core/providers/logs_provider.dart';
import 'package:intl/intl.dart';

class LogsPage extends ConsumerStatefulWidget {
  final bool isVisible;
  const LogsPage({super.key, this.isVisible = true});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Follow the tail only when the user is already near the bottom and the
  /// page is visible. Uses jumpTo instead of animateTo: a restarted animation
  /// on every log flush keeps the frame pipeline permanently busy.
  void _followTail() {
    if (!widget.isVisible || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 60;
    if (!isNearBottom) return;
    if (position.pixels < position.maxScrollExtent) {
      _scrollController.jumpTo(position.maxScrollExtent);
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.trace:
        return const Color(0xFF94A3B8);
      case LogLevel.debug:
        return const Color(0xFF38BDF8);
      case LogLevel.info:
        return const Color(0xFF10B981);
      case LogLevel.warn:
        return const Color(0xFFF59E0B);
      case LogLevel.error:
        return const Color(0xFFF43F5E);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final logsState = ref.watch(logsProvider);
    final tr = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logs = logsState.filteredLogs;

    // Trigger auto scroll after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _followTail());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls toolbar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.logStream,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr.logStreamDesc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Level dropdown selector
              _buildLevelSelector(context, logsState.filterLevel, tr, isDark),

              const SizedBox(width: 12),

              // Search field
              SizedBox(
                width: 180,
                height: 38,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: tr.searchLogs,
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: (val) {
                    ref.read(logsProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Pause / Resume
              IconButton(
                icon: Icon(
                  logsState.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: logsState.isPaused ? const Color(0xFF10B981) : null,
                ),
                tooltip: logsState.isPaused ? tr.resumeLogs : tr.pauseLogs,
                onPressed: () {
                  ref.read(logsProvider.notifier).togglePause();
                },
              ),

              // Copy All
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: tr.copyAll,
                onPressed: () {
                  final text = logs.map((l) => '[${l.level.nameStr}] ${l.message}').join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr.logsCopied)),
                  );
                },
              ),

              // Clear
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                tooltip: tr.clearLogs,
                onPressed: () {
                  ref.read(logsProvider.notifier).clearLogs();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Logs OLED Console Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF060910),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        tr.noLogsYet,
                        style: TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                    )
                  : SelectionArea(
                      // One shared selection controller for all lines is far
                      // cheaper than a SelectableText per row.
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final entry = logs[index];
                          return _buildLogLine(entry, index + 1);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector(
    BuildContext context,
    LogLevel currentLevel,
    Translations tr,
    bool isDark,
  ) {
    final currentColor = _getLevelColor(currentLevel);

    return PopupMenuButton<LogLevel>(
      initialValue: currentLevel,
      tooltip: tr.levelPrefix.replaceAll(':', '').trim(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      color: isDark ? const Color(0xFF0E1424) : Colors.white,
      elevation: 8,
      onSelected: (level) {
        ref.read(logsProvider.notifier).setFilterLevel(level);
      },
      itemBuilder: (context) => LogLevel.values.map((level) {
        final color = _getLevelColor(level);
        final isSelected = level == currentLevel;

        return PopupMenuItem<LogLevel>(
          value: level,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                level.nameStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_rounded, size: 14, color: color),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E1424) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${tr.levelPrefix}${currentLevel.nameStr}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(LogEntry entry, int lineNumber) {
    final levelColor = _getLevelColor(entry.level);
    final timeStr = _timeFormat.format(entry.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${lineNumber.toString().padLeft(4, "0")} ',
              style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: '$timeStr ',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: '[${entry.level.nameStr}] '.padRight(8),
              style: TextStyle(color: levelColor, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: entry.message,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
