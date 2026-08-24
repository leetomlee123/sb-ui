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
      stagingDir = await Directory.systemTemp.createTemp('singular_update_test');
    });

    tearDown(() async {
      try {
        await stagingDir.delete(recursive: true);
      } catch (_) {}
    });

    test('writes script with quoted paths, poll loop, rollback safety', () async {
      final service = AppUpdaterService();
      final scriptPath = await service.writeSwapScript(
        stagingDir: stagingDir.path,
        appDir: r'C:\Apps\singular app',
        exeName: 'singular.exe',
      );

      final script = await File(scriptPath).readAsString();

      expect(scriptPath, endsWith('singular_self_update.ps1'));
      expect(script, contains(r'$appDir = "C:\Apps\singular app"'));
      expect(script, contains(stagingDir.path));
      expect(script, contains('Get-Process -Id \$targetPid'));
      expect(script, contains('Stop-Process -Id \$targetPid'));
      expect(script, contains('.old'));
      expect(script, contains('Copy-Item'));
      expect(script, contains('Start-Process'));
      expect(script, contains('Remove-Item'));
    });
  });
}
