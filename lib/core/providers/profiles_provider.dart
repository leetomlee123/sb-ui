import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../engine/profile_parser.dart';
import '../models/profile.dart';
import '../services/storage_service.dart';
import '../utils/proxy_dio_helper.dart';
import 'core_provider.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';

class ProfilesState {
  final List<Profile> profiles;
  final String? activeProfileId;
  final bool isLoading;
  final String? errorMessage;

  ProfilesState({
    required this.profiles,
    this.activeProfileId,
    this.isLoading = false,
    this.errorMessage,
  });

  Profile? get activeProfile {
    if (activeProfileId == null) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
    try {
      return profiles.firstWhere((p) => p.id == activeProfileId);
    } catch (_) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  ProfilesState copyWith({
    List<Profile>? profiles,
    String? activeProfileId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfilesState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProfilesNotifier extends StateNotifier<ProfilesState> {
  final Ref _ref;
  final StorageService _storage;
  final _uuid = const Uuid();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'sing-box/1.13.0 ClashMeta/1.18.0',
    },
  ));

  ProfilesNotifier(this._ref, this._storage)
      : super(ProfilesState(
          profiles: _storage.loadProfiles(),
          activeProfileId: _storage.getActiveProfileId(),
        )) {
    // If no active profile is marked, default to the first one
    if (state.activeProfileId == null && state.profiles.isNotEmpty) {
      setActiveProfile(state.profiles.first.id);
    }
  }

  void _syncProxy() {
    final isRunning = _ref.read(coreProvider).isRunning;
    final mixedPort = _ref.read(settingsProvider).mixedPort;
    ProxyDioHelper.configureProxy(_dio, proxyPort: isRunning ? mixedPort : null);
  }

  Future<void> setActiveProfile(String id) async {
    final updatedList = state.profiles.map((p) {
      return p.copyWith(active: p.id == id);
    }).toList();
    state = state.copyWith(
      profiles: updatedList,
      activeProfileId: id,
    );
    await _storage.saveProfiles(updatedList);
    await _storage.setActiveProfileId(id);
  }

  Future<bool> addProfileFromUrl({
    required String name,
    required String url,
    int autoUpdateHours = 24,
  }) async {
    _syncProxy();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final rawContent = response.data ?? '';
      if (rawContent.trim().isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: 'Subscription returned empty content');
        return false;
      }

      final parseResult = ProfileParser.parse(rawContent);
      
      // Parse User-Info header if present (traffic/expire info)
      int? upload;
      int? download;
      int? total;
      DateTime? expire;
      final userInfoHeader = response.headers.value('subscription-userinfo');
      if (userInfoHeader != null) {
        final pairs = userInfoHeader.split(';');
        for (final pair in pairs) {
          final kv = pair.trim().split('=');
          if (kv.length == 2) {
            final k = kv[0].trim();
            final v = int.tryParse(kv[1].trim());
            if (v != null) {
              if (k == 'upload') upload = v;
              if (k == 'download') download = v;
              if (k == 'total') total = v;
              if (k == 'expire') expire = DateTime.fromMillisecondsSinceEpoch(v * 1000);
            }
          }
        }
      }

      final newProfile = Profile(
        id: _uuid.v4(),
        name: name.trim().isEmpty ? 'Subscription' : name.trim(),
        type: ProfileType.remote,
        url: url.trim(),
        updatedAt: DateTime.now(),
        autoUpdateIntervalHours: autoUpdateHours,
        nodeCount: parseResult.count,
        rawConfig: rawContent,
        uploadTraffic: upload,
        downloadTraffic: download,
        totalTraffic: total,
        expireDate: expire,
        active: state.profiles.isEmpty,
      );

      final updatedProfiles = [...state.profiles, newProfile];
      final newActiveId = state.profiles.isEmpty ? newProfile.id : state.activeProfileId;
      state = state.copyWith(
        profiles: updatedProfiles,
        activeProfileId: newActiveId,
        isLoading: false,
      );

      await _storage.saveProfiles(updatedProfiles);
      if (state.profiles.isEmpty) {
        await _storage.setActiveProfileId(newProfile.id);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to download subscription: $e',
      );
      return false;
    }
  }

  Future<bool> addProfileFromLocalFile({
    required String name,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(errorMessage: 'File does not exist');
        return false;
      }
      final rawContent = await file.readAsString();
      final parseResult = ProfileParser.parse(rawContent);

      final newProfile = Profile(
        id: _uuid.v4(),
        name: name.trim().isEmpty ? file.uri.pathSegments.last : name.trim(),
        type: ProfileType.local,
        filePath: filePath,
        updatedAt: DateTime.now(),
        nodeCount: parseResult.count,
        rawConfig: rawContent,
        active: state.profiles.isEmpty,
      );

      final updatedProfiles = [...state.profiles, newProfile];
      final newActiveId = state.profiles.isEmpty ? newProfile.id : state.activeProfileId;
      state = state.copyWith(
        profiles: updatedProfiles,
        activeProfileId: newActiveId,
      );

      await _storage.saveProfiles(updatedProfiles);
      if (state.profiles.isEmpty) {
        await _storage.setActiveProfileId(newProfile.id);
      }
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load local file: $e');
      return false;
    }
  }

  Future<bool> addProfileFromRawText({
    required String name,
    required String rawContent,
  }) async {
    try {
      final parseResult = ProfileParser.parse(rawContent);
      final newProfile = Profile(
        id: _uuid.v4(),
        name: name.trim().isEmpty ? 'Manual Profile' : name.trim(),
        type: ProfileType.manual,
        updatedAt: DateTime.now(),
        nodeCount: parseResult.count,
        rawConfig: rawContent,
        active: state.profiles.isEmpty,
      );

      final updatedProfiles = [...state.profiles, newProfile];
      final newActiveId = state.profiles.isEmpty ? newProfile.id : state.activeProfileId;
      state = state.copyWith(
        profiles: updatedProfiles,
        activeProfileId: newActiveId,
      );

      await _storage.saveProfiles(updatedProfiles);
      if (state.profiles.isEmpty) {
        await _storage.setActiveProfileId(newProfile.id);
      }
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save config: $e');
      return false;
    }
  }

  Future<bool> updateProfileContent(String id, String newRawContent) async {
    final parseResult = ProfileParser.parse(newRawContent);
    final updatedProfiles = state.profiles.map((p) {
      if (p.id == id) {
        return p.copyWith(
          rawConfig: newRawContent,
          nodeCount: parseResult.count,
          updatedAt: DateTime.now(),
        );
      }
      return p;
    }).toList();

    state = state.copyWith(profiles: updatedProfiles);
    await _storage.saveProfiles(updatedProfiles);
    return true;
  }

  Future<bool> refreshProfile(String id) async {
    final profile = state.profiles.firstWhere((p) => p.id == id);
    if (profile.type != ProfileType.remote || profile.url == null) return false;

    _syncProxy();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _dio.get<String>(
        profile.url!,
        options: Options(responseType: ResponseType.plain),
      );
      final rawContent = response.data ?? '';
      final parseResult = ProfileParser.parse(rawContent);

      final updatedProfiles = state.profiles.map((p) {
        if (p.id == id) {
          return p.copyWith(
            rawConfig: rawContent,
            nodeCount: parseResult.count,
            updatedAt: DateTime.now(),
          );
        }
        return p;
      }).toList();

      state = state.copyWith(profiles: updatedProfiles, isLoading: false);
      await _storage.saveProfiles(updatedProfiles);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Update failed: $e');
      return false;
    }
  }

  Future<void> deleteProfile(String id) async {
    final updatedProfiles = state.profiles.where((p) => p.id != id).toList();
    String? newActiveId = state.activeProfileId;
    if (state.activeProfileId == id) {
      newActiveId = updatedProfiles.isNotEmpty ? updatedProfiles.first.id : null;
    }

    state = state.copyWith(
      profiles: updatedProfiles,
      activeProfileId: newActiveId,
    );
    await _storage.saveProfiles(updatedProfiles);
    await _storage.setActiveProfileId(newActiveId);
  }
}

final profilesProvider = StateNotifierProvider<ProfilesNotifier, ProfilesState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ProfilesNotifier(ref, storage);
});
