import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
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
    // 1. Try local portable ./config directory next to executable
    try {
      final appExeDir = File(Platform.resolvedExecutable).parent.path;
      final localConfigDir = Directory('$appExeDir/config');
      if (!await localConfigDir.exists()) {
        await localConfigDir.create(recursive: true);
      }
      // Verify write permission
      final testFile = File('${localConfigDir.path}/.test_write');
      await testFile.writeAsString('1');
      await testFile.delete();
      return localConfigDir;
    } catch (_) {}

    // 2. Fallback to user application support directory
    try {
      final baseDir = await getApplicationSupportDirectory();
      final fallbackConfigDir = Directory('${baseDir.path}/config');
      if (!await fallbackConfigDir.exists()) {
        await fallbackConfigDir.create(recursive: true);
      }
      return fallbackConfigDir;
    } catch (_) {}

    // 3. Last-resort fallback to current working directory
    final cwdConfigDir = Directory('./config');
    if (!await cwdConfigDir.exists()) {
      await cwdConfigDir.create(recursive: true);
    }
    return cwdConfigDir;
  }

  static Future<void> ensureBundledRulesExtracted() async {
    try {
      final configDir = await getAppConfigDir();
      final geoipTarget = File('${configDir.path}/geoip-cn.srs');
      final geositeTarget = File('${configDir.path}/geosite-cn.srs');

      if (!await geoipTarget.exists() || await geoipTarget.length() == 0) {
        try {
          final data = await rootBundle.load('assets/rules/geoip-cn.srs');
          await geoipTarget.writeAsBytes(data.buffer.asUint8List());
        } catch (_) {}
      }

      if (!await geositeTarget.exists() || await geositeTarget.length() == 0) {
        try {
          final data = await rootBundle.load('assets/rules/geosite-cn.srs');
          await geositeTarget.writeAsBytes(data.buffer.asUint8List());
        } catch (_) {}
      }
    } catch (_) {}
  }
}
