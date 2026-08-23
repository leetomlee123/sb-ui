import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/core/services/app_updater_service.dart';
import 'package:sb_ui/core/utils/version_utils.dart';

void main() {
  group('isNewerVersion', () {
    test('detects newer versions', () {
      expect(isNewerVersion('1.1.8', '1.1.7'), isTrue);
      expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('v1.1.8', '1.1.7'), isTrue);
    });

    test('rejects equal or older versions', () {
      expect(isNewerVersion('1.1.7', '1.1.7'), isFalse);
      expect(isNewerVersion('1.1.6', '1.1.7'), isFalse);
      expect(isNewerVersion('v1.1.7', '1.1.7'), isFalse);
    });

    test('handles differing segment counts', () {
      expect(isNewerVersion('1.2', '1.1.9'), isTrue);
      // '1.1' and '1.1.0' are semantically equal — not newer.
      expect(isNewerVersion('1.1', '1.1.0'), isFalse);
      expect(isNewerVersion('1.1.0', '1.1'), isTrue);
      expect(isNewerVersion('1.1.7', '1.2'), isFalse);
    });

    test('ignores pre-release suffixes on numeric segments', () {
      expect(isNewerVersion('1.2.0-alpha', '1.1.9'), isTrue);
      expect(isNewerVersion('1.1.7-rc1', '1.1.7'), isFalse);
    });
  });

  group('AppUpdaterService.writeSwapScript', () {
    late Directory stagingDir;

    setUp(() async {
      stagingDir = await Directory.systemTemp.createTemp('sb_ui_update_test');
    });

    tearDown(() async {
      try {
        await stagingDir.delete(recursive: true);
      } catch (_) {}
    });

    test('writes script with quoted paths, poll loop, rollback safety', () async {
      final service = AppUpdaterService();
      final scriptPath = await service.writeSwapScript(
        stagingDir: r'C:\Temp\stage one',
        appDir: r'C:\Apps\sb ui',
        exeName: 'sb_ui.exe',
      );

      final script = await File(scriptPath).readAsString();

      expect(scriptPath, endsWith(r'stage one\sb_ui_self_update.bat'));
      expect(script, contains(r'set "APP_DIR=C:\Apps\sb ui"'));
      expect(script, contains(r'set "SRC_DIR=C:\Temp\stage one"'));
      expect(script, contains(r'tasklist /FI "IMAGENAME eq %EXE_NAME%"'));
      // Poll loop must not rely on `timeout` (fails without a console).
      expect(script, isNot(contains('timeout /t')));
      expect(script, contains('ping -n 2 127.0.0.1'));
      // Rollback copy only removed after the new exe landed.
      expect(script, contains('.old'));
      expect(script, contains('xcopy /e /y /i'));
      // Staging dir cleanup + self delete.
      expect(script, contains(r'rd /s /q "%SRC_DIR%"'));
      expect(script, contains(r'del /f /q "%~f0"'));
    });
  });
}
