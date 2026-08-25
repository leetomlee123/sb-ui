import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';

/// Central application logger providing a unified event stream and memory buffer
/// for app-level diagnostics (such as startup timing) and process logs.
class AppLogger {
  static final StreamController<LogEntry> _controller = StreamController<LogEntry>.broadcast();
  static final List<LogEntry> _history = [];
  static const int maxHistory = 500;

  /// Broadcast stream of incoming log entries.
  static Stream<LogEntry> get stream => _controller.stream;

  /// Current in-memory history of log entries.
  static List<LogEntry> get history => List.unmodifiable(_history);

  /// Records a log message, outputs to debug console, and broadcasts to listeners.
  static void log(String message, {LogLevel level = LogLevel.info, DateTime? timestamp}) {
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: timestamp ?? DateTime.now(),
    );
    _append(entry);
  }

  static void info(String message) => log(message, level: LogLevel.info);
  static void warn(String message) => log(message, level: LogLevel.warn);
  static void error(String message) => log(message, level: LogLevel.error);
  static void debug(String message) => log(message, level: LogLevel.debug);
  static void trace(String message) => log(message, level: LogLevel.trace);

  /// Directly appends a pre-built LogEntry to the logger.
  static void addEntry(LogEntry entry) {
    _append(entry);
  }

  static void _append(LogEntry entry) {
    debugPrint('[${entry.level.nameStr}] ${entry.message}');
    if (_history.length >= maxHistory) {
      _history.removeAt(0);
    }
    _history.add(entry);
    _controller.add(entry);
  }

  /// Clears the logger history buffer.
  static void clear() {
    _history.clear();
  }
}
