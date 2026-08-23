import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/profile.dart';

class StorageService {
  static const String _keySettings = 'app_settings';
  static const String _keyProfiles = 'app_profiles';
  static const String _keyActiveProfileId = 'active_profile_id';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Settings ---

  AppSettings loadSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return AppSettings.fromJson(decoded);
        }
      } catch (_) {}
    }
    return const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final jsonStr = jsonEncode(settings.toJson());
    await _prefs.setString(_keySettings, jsonStr);
  }

  // --- Profiles ---

  List<Profile> loadProfiles() {
    final raw = _prefs.getString(_keyProfiles);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => Profile.fromJson(e))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final list = profiles.map((p) => p.toJson()).toList();
    await _prefs.setString(_keyProfiles, jsonEncode(list));
  }

  String? getActiveProfileId() {
    return _prefs.getString(_keyActiveProfileId);
  }

  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyActiveProfileId);
    } else {
      await _prefs.setString(_keyActiveProfileId, id);
    }
  }

  // --- App Directory for runtime configs ---

  static Future<Directory> getAppConfigDir() async {
    final baseDir = await getApplicationSupportDirectory();
    final configDir = Directory('${baseDir.path}/sing-box');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir;
  }
}
