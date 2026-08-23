import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/log_entry.dart';
import 'core_provider.dart';

class LogsState {
  final List<LogEntry> logs;
  final LogLevel filterLevel;
  final String searchQuery;
  final bool isPaused;

  LogsState({
    this.logs = const [],
    this.filterLevel = LogLevel.trace,
    this.searchQuery = '',
    this.isPaused = false,
  });

  List<LogEntry> get filteredLogs {
    return logs.where((entry) {
      if (entry.level.index < filterLevel.index) return false;
      if (searchQuery.isNotEmpty && !entry.message.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  LogsState copyWith({
    List<LogEntry>? logs,
    LogLevel? filterLevel,
    String? searchQuery,
    bool? isPaused,
  }) {
    return LogsState(
      logs: logs ?? this.logs,
      filterLevel: filterLevel ?? this.filterLevel,
      searchQuery: searchQuery ?? this.searchQuery,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

class LogsNotifier extends StateNotifier<LogsState> {
  final Ref _ref;
  StreamSubscription<LogEntry>? _wsLogSub;
  StreamSubscription<LogEntry>? _processOutputSub;

  final List<LogEntry> _logBuffer = [];
  Timer? _flushTimer;

  LogsNotifier(this._ref) : super(LogsState()) {
    // Listen to process output
    final processMgr = _ref.read(coreProvider.notifier).processManager;
    _processOutputSub = processMgr.outputStream.listen((entry) {
      _addLog(entry);
    });

    // Listen to core state to attach WS logs
    _ref.listen<CoreState>(coreProvider, (prev, next) {
      if (next.isRunning && (prev == null || !prev.isRunning)) {
        _startWsLogs();
      } else if (!next.isRunning) {
        _stopWsLogs();
      }
    });
  }

  void _startWsLogs() {
    _wsLogSub?.cancel();
    final client = _ref.read(clashApiClientProvider);
    if (client != null) {
      _wsLogSub = client.logsStream(level: 'info').listen((entry) {
        _addLog(entry);
      });
    }
  }

  void _stopWsLogs() {
    _wsLogSub?.cancel();
    _wsLogSub = null;
  }

  void _addLog(LogEntry entry) {
    if (state.isPaused) return;
    _logBuffer.add(entry);

    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(const Duration(milliseconds: 250), _flushLogs);
    }
  }

  void _flushLogs() {
    if (_logBuffer.isEmpty) return;
    final List<LogEntry> toAdd = List.from(_logBuffer);
    _logBuffer.clear();

    final updated = [...state.logs, ...toAdd];
    if (updated.length > 500) {
      updated.removeRange(0, updated.length - 500);
    }
    state = state.copyWith(logs: updated);
  }

  void setFilterLevel(LogLevel level) {
    state = state.copyWith(filterLevel: level);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  void clearLogs() {
    _logBuffer.clear();
    state = state.copyWith(logs: []);
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _wsLogSub?.cancel();
    _processOutputSub?.cancel();
    super.dispose();
  }
}

final logsProvider = StateNotifierProvider<LogsNotifier, LogsState>((ref) {
  return LogsNotifier(ref);
});
