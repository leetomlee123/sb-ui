import 'dart:async';
import 'dart:collection';
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
    // Fast path: no filtering needed, avoid copying the whole buffer.
    if (filterLevel == LogLevel.trace && searchQuery.isEmpty) return logs;
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

  final ListQueue<LogEntry> _logsQueue = ListQueue<LogEntry>(500);
  final List<LogEntry> _incomingBuffer = [];
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
    // Standard mode already mirrors core logs via stdout; subscribing to the WS
    // as well duplicates every line. Only use the WS when stdout is unavailable
    // (elevated TUN process we didn't spawn ourselves).
    if (_ref.read(coreProvider.notifier).processManager.hasStdoutCapture) return;
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
    _incomingBuffer.add(entry);

    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(const Duration(milliseconds: 500), _flushLogs);
    }
  }

  void _flushLogs() {
    if (_incomingBuffer.isEmpty) return;
    for (final e in _incomingBuffer) {
      if (_logsQueue.length >= 500) {
        _logsQueue.removeFirst();
      }
      _logsQueue.addLast(e);
    }
    _incomingBuffer.clear();

    state = state.copyWith(logs: _logsQueue.toList(growable: false));
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
    _incomingBuffer.clear();
    _logsQueue.clear();
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
