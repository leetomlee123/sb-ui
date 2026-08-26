import 'package:flutter_test/flutter_test.dart';
import 'package:singular/core/models/log_entry.dart';
import 'package:singular/core/utils/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clear();
  });

  test('AppLogger records and buffers history correctly', () {
    expect(AppLogger.history.isEmpty, isTrue);

    AppLogger.info('[App Startup] Initialization started');
    AppLogger.warn('[App Startup] Warning message');
    AppLogger.error('[App Startup] Error message');

    expect(AppLogger.history.length, 3);
    expect(AppLogger.history[0].level, LogLevel.info);
    expect(AppLogger.history[0].message, '[App Startup] Initialization started');
    expect(AppLogger.history[1].level, LogLevel.warn);
    expect(AppLogger.history[2].level, LogLevel.error);
  });

  test('AppLogger emits entries to stream in real-time', () async {
    final emitted = <LogEntry>[];
    final sub = AppLogger.stream.listen((entry) {
      emitted.add(entry);
    });

    AppLogger.info('Live log 1');
    AppLogger.debug('Live log 2');

    await Future.delayed(const Duration(milliseconds: 20));
    expect(emitted.length, 2);
    expect(emitted[0].message, 'Live log 1');
    expect(emitted[1].message, 'Live log 2');

    await sub.cancel();
  });

  test('AppLogger caps history at maxHistory limit', () {
    for (int i = 0; i < AppLogger.maxHistory + 50; i++) {
      AppLogger.info('Log entry $i');
    }

    expect(AppLogger.history.length, AppLogger.maxHistory);
    expect(AppLogger.history.last.message, 'Log entry ${AppLogger.maxHistory + 49}');
  });
}
