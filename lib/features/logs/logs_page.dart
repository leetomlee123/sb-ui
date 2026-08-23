import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/translations.dart';
import '../../core/models/log_entry.dart';
import '../../core/providers/logs_provider.dart';
import 'package:intl/intl.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  final bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(logsProvider);
    final tr = ref.watch(translationsProvider);
    final logs = logsState.filteredLogs;

    // Trigger auto scroll after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

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

              // Level dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1424),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: DropdownButton<LogLevel>(
                  value: logsState.filterLevel,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF0E1424),
                  items: LogLevel.values.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text('${tr.levelPrefix}${level.nameStr}', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(logsProvider.notifier).setFilterLevel(val);
                    }
                  },
                ),
              ),

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
                        style: const TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace'),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final entry = logs[index];
                        return _buildLogLine(entry, index + 1);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogLine(LogEntry entry, int lineNumber) {
    Color levelColor;
    switch (entry.level) {
      case LogLevel.trace:
        levelColor = const Color(0xFF94A3B8);
        break;
      case LogLevel.debug:
        levelColor = const Color(0xFF38BDF8);
        break;
      case LogLevel.info:
        levelColor = const Color(0xFF10B981);
        break;
      case LogLevel.warn:
        levelColor = const Color(0xFFF59E0B);
        break;
      case LogLevel.error:
        levelColor = const Color(0xFFF43F5E);
        break;
    }

    final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: SelectableText.rich(
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
