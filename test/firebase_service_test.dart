import 'package:flutter_test/flutter_test.dart';
import 'package:singular/core/services/firebase_service.dart';
import 'package:singular/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseService and DefaultFirebaseOptions tests', () {
    test('DefaultFirebaseOptions provides platform options safely', () {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, isNotEmpty);
      expect(options.apiKey, isNotEmpty);
      expect(options.appId, isNotEmpty);
      expect(DefaultFirebaseOptions.windows.projectId, 'singular-6cc8b');
      expect(DefaultFirebaseOptions.linux.projectId, 'singular-6cc8b');
      expect(DefaultFirebaseOptions.macos.projectId, 'singular-6cc8b');
    });

    test('FirebaseService.init handles test environment without crashing', () async {
      await FirebaseService.init();
      // Should not throw even in headless mock/test environments
    });

    test('FirebaseService.logEvent, recordException and domain telemetry execute smoothly', () async {
      await FirebaseService.logEvent('test_event', {'param_key': 'param_value'});
      await FirebaseService.logError(Exception('Test error'), StackTrace.current, 'unit_test');
      await FirebaseService.recordException(
        Exception('Fatal test crash'),
        stackTrace: StackTrace.current,
        reason: 'unit_test_crash',
        fatal: true,
      );
      await FirebaseService.logAppStartup(launchTimeMs: 120, nativeLoadMs: 30);
      await FirebaseService.logCoreAction(
        action: 'start',
        routingMode: 'rule',
        tunEnabled: true,
        profileName: 'My Profile',
      );
      await FirebaseService.logSpeedTest(
        totalNodes: 20,
        testedNodes: 20,
        successCount: 18,
        averageLatencyMs: 85,
      );
      await FirebaseService.logProfileOperation(
        action: 'add',
        format: 'remote',
        nodeCount: 50,
      );
      await FirebaseService.logFeatureToggle(
        feature: 'system_proxy',
        enabled: true,
      );
    });
  });
}
