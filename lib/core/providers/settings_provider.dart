import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/autostart_service.dart';
import '../services/storage_service.dart';
import 'storage_provider.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(_storage.loadSettings());

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _storage.saveSettings(newSettings);
  }

  Future<void> updateMixedPort(int port) async {
    await updateSettings(state.copyWith(mixedPort: port));
  }

  Future<void> updateClashApiPort(int port) async {
    await updateSettings(state.copyWith(clashApiPort: port));
  }

  Future<void> updateClashApiSecret(String secret) async {
    await updateSettings(state.copyWith(clashApiSecret: secret));
  }

  Future<void> toggleSystemProxy(bool enabled) async {
    await updateSettings(state.copyWith(systemProxyEnabled: enabled));
  }

  Future<void> toggleTunMode(bool enabled) async {
    await updateSettings(state.copyWith(tunModeEnabled: enabled));
  }

  Future<void> setRoutingMode(RoutingMode mode) async {
    await updateSettings(state.copyWith(routingMode: mode));
  }

  Future<void> setThemeMode(String mode) async {
    await updateSettings(state.copyWith(themeMode: mode));
  }

  Future<void> setLanguage(String language) async {
    await updateSettings(state.copyWith(language: language));
  }

  Future<void> setCustomSingboxPath(String path) async {
    await updateSettings(state.copyWith(customSingboxPath: path));
  }

  Future<void> setDns({required String remoteDns, required String directDns}) async {
    await updateSettings(state.copyWith(remoteDns: remoteDns, directDns: directDns));
  }

  Future<void> toggleAllowLan(bool allow) async {
    await updateSettings(state.copyWith(allowLan: allow));
  }

  Future<void> toggleAutoStart(bool enabled) async {
    await AutoStartService.setAutoStart(enabled);
    await updateSettings(state.copyWith(autoStart: enabled));
  }

  Future<void> toggleStartMinimized(bool enabled) async {
    await updateSettings(state.copyWith(startMinimized: enabled));
  }

  Future<void> toggleCloseToTray(bool enabled) async {
    await updateSettings(state.copyWith(closeToTray: enabled));
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage);
});
