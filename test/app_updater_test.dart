import 'dart:io';
import 'package:desktop_updater/desktop_updater.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singular/core/services/app_updater_service.dart';
import 'package:singular/core/services/json_file_update_recovery_store.dart';
import 'package:singular/core/utils/version_utils.dart';

void main() {
  group('isNewerVersion', () {
    test('detects newer versions', () {
      expect(isNewerVersion('1.1.8', '1.1.7'), isTrue);
      expect(isNewerVersion('1.2.0', '1.1.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(isNewerVersion('v1.1.8', '1.1.7'), isTrue);
      expect(isNewerVersion('1.2.11', '1.2.10+30'), isTrue);
      expect(isNewerVersion('1.2.11', '30'), isTrue);
      expect(isNewerVersion('v1.2.11', 'v30'), isTrue);
    });

    test('rejects equal or older versions', () {
      expect(isNewerVersion('1.1.7', '1.1.7'), isFalse);
      expect(isNewerVersion('1.1.6', '1.1.7'), isFalse);
      expect(isNewerVersion('v1.1.7', '1.1.7'), isFalse);
      expect(isNewerVersion('1.2.11', '1.2.11+31'), isFalse);
      expect(isNewerVersion('1.2.11', '1.2.11'), isFalse);
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

    test('normalizeSemver cleans build metadata and v prefixes', () {
      expect(normalizeSemver('v1.2.10+30'), '1.2.10');
      expect(normalizeSemver('1.2.11+31'), '1.2.11');
      expect(normalizeSemver('v1.2.11'), '1.2.11');
      expect(normalizeSemver('30'), '30');
    });
  });

  group('AppUpdaterService', () {
    test('instantiates and provides DesktopUpdater facade', () {
      final service = AppUpdaterService();
      expect(service.desktopUpdater, isNotNull);
    });
  });

  group('JsonFileUpdateRecoveryStore', () {
    late Directory tempDir;
    late File recoveryFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_store_test');
      recoveryFile = File('${tempDir.path}/pending-install-stable.json');
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('writes, reads, and clears pending install marker', () async {
      final store = JsonFileUpdateRecoveryStore(recoveryFile);
      expect(await store.readPendingInstall(channel: 'stable'), isNull);

      final marker = UpdateInstallRecoveryMarker.pendingV3(
        createdAt: DateTime.now().toUtc(),
        packageVersion: '3.1.6',
        platform: 'windows',
        channel: 'stable',
        appVersion: '1.2.9',
        updateVersion: '1.3.0',
        updateBuildNumber: 30,
        expectedPackageId: 'sb_ui',
        stagingPath: tempDir.path,
        stageProvenanceSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        diagnosticsText: 'test diagnostics',
        transactionId: '00000000-0000-4000-8000-000000000001',
      );

      await store.writePendingInstall(marker);
      final read = await store.readPendingInstall(channel: 'stable');
      expect(read, isNotNull);
      expect(read!.updateVersion, '1.3.0');
      expect(read.expectedPackageId, 'sb_ui');
      expect(read.transactionId, '00000000-0000-4000-8000-000000000001');

      // Channel mismatch should return null
      expect(await store.readPendingInstall(channel: 'beta'), isNull);

      await store.clearPendingInstall(channel: 'stable');
      expect(await store.readPendingInstall(channel: 'stable'), isNull);
    });
  });
}
