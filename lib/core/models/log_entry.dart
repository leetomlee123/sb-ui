enum LogLevel {
  trace,
  debug,
  info,
  warn,
  error;

  static LogLevel fromString(String str) {
    switch (str.toLowerCase()) {
      case 'trace':
        return LogLevel.trace;
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warn':
      case 'warning':
        return LogLevel.warn;
      case 'error':
      case 'fatal':
      case 'panic':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }

  String get nameStr {
    switch (this) {
      case LogLevel.trace:
        return 'TRACE';
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.fromString(json['type'] as String? ?? 'info'),
      message: json['payload'] as String? ?? '',
    );
  }

  factory LogEntry.raw(String text, [LogLevel level = LogLevel.info]) {
    return LogEntry(
      level: level,
      message: text,
    );
  }
}
