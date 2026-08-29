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
      expect(DefaultFirebaseOptions.windows.projectId, 'singular-app');
      expect(DefaultFirebaseOptions.linux.projectId, 'singular-app');
      expect(DefaultFirebaseOptions.macos.projectId, 'singular-app');
    });

    test('FirebaseService.init handles test environment without crashing', () async {
      await FirebaseService.init();
      // Should not throw even in headless mock/test environments
    });

    test('FirebaseService.logEvent and logError execute without exceptions', () async {
      await FirebaseService.logEvent('test_event', {'param_key': 'param_value'});
      await FirebaseService.logError(Exception('Test error'), StackTrace.current, 'unit_test');
    });
  });
}
