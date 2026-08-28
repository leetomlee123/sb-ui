import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/geo_asset.dart';
import '../services/geo_updater_service.dart';
import '../utils/app_logger.dart';
import 'core_provider.dart';
import 'settings_provider.dart';

class GeoUpdaterState {
  final List<GeoAssetInfo> assets;
  final bool isUpdating;
  final String? activeAssetName;
  final double progress;
  final String statusMessage;
  final String? errorMessage;
  final String? successMessage;

  const GeoUpdaterState({
    this.assets = const [],
    this.isUpdating = false,
    this.activeAssetName,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
    this.successMessage,
  });

  GeoUpdaterState copyWith({
    List<GeoAssetInfo>? assets,
    bool? isUpdating,
    String? activeAssetName,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    String? successMessage,
  }) {
    return GeoUpdaterState(
      assets: assets ?? this.assets,
      isUpdating: isUpdating ?? this.isUpdating,
      activeAssetName: activeAssetName ?? this.activeAssetName,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class GeoUpdaterNotifier extends StateNotifier<GeoUpdaterState> {
  final Ref _ref;
  final GeoUpdaterService _service = GeoUpdaterService();

  GeoUpdaterNotifier(this._ref) : super(const GeoUpdaterState()) {
    refreshAssets();
  }

  void _syncProxy() {
    final isRunning = _ref.read(coreProvider).isRunning;
    final mixedPort = _ref.read(settingsProvider).mixedPort;
    _service.setProxyPort(isRunning ? mixedPort : null);
  }

  Future<void> refreshAssets() async {
    try {
      final assets = await _service.getGeoAssets();
      state = state.copyWith(assets: assets);
    } catch (_) {}
  }

  Future<bool> updateSingleAsset(GeoAssetInfo asset) async {
    _syncProxy();
    state = state.copyWith(
      isUpdating: true,
      activeAssetName: asset.name,
      progress: 0.0,
      statusMessage: 'Starting update for ${asset.name}...',
      errorMessage: null,
      successMessage: null,
    );

    try {
      await _service.updateGeoAsset(
        asset,
        onProgress: (progress, status) {
          state = state.copyWith(progress: progress, statusMessage: status);
        },
      );

      await refreshAssets();

      // If core is running, seamlessly reload/restart it to apply the new rules immediately
      final isRunning = _ref.read(coreProvider).isRunning;
      if (isRunning) {
        await _ref.read(coreProvider.notifier).startCore();
      }

      state = state.copyWith(
        isUpdating: false,
        activeAssetName: null,
        progress: 1.0,
        statusMessage: '${asset.name} updated successfully',
        successMessage: '${asset.displayName} 已成功更新为最新版本！',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        activeAssetName: null,
        errorMessage: 'Update failed: $e',
      );
      return false;
    }
  }

  Future<bool> updateAllAssets({bool silent = false}) async {
    _syncProxy();
    if (state.assets.isEmpty) await refreshAssets();
    if (state.assets.isEmpty) return false;

    if (!silent) {
      state = state.copyWith(
        isUpdating: true,
        activeAssetName: null,
        progress: 0.0,
        statusMessage: 'Updating all Geo datasets...',
        errorMessage: null,
        successMessage: null,
      );
    }

    int succeeded = 0;
    for (int i = 0; i < state.assets.length; i++) {
      final asset = state.assets[i];
      if (!silent) {
        state = state.copyWith(
          activeAssetName: asset.name,
          statusMessage: 'Updating ${asset.name} (${i + 1}/${state.assets.length})...',
        );
      }

      try {
        await _service.updateGeoAsset(
          asset,
          onProgress: (subProgress, status) {
            if (!silent) {
              final overallProgress = (i + subProgress) / state.assets.length;
              state = state.copyWith(progress: overallProgress, statusMessage: status);
            }
          },
        );
        succeeded++;
      } catch (e) {
        AppLogger.warn('[GeoUpdater] 规则集 ${asset.name} 更新失败: $e');
      }
    }

    await refreshAssets();

    // If core is running, restart core to reload rules
    final isRunning = _ref.read(coreProvider).isRunning;
    if (isRunning && succeeded > 0) {
      await _ref.read(coreProvider.notifier).startCore();
    }

    if (succeeded > 0) {
      AppLogger.info('[GeoUpdater] 成功更新 $succeeded 个规则集文件 (.srs)');
      if (!silent) {
        state = state.copyWith(
          isUpdating: false,
          activeAssetName: null,
          progress: 1.0,
          statusMessage: 'All Geo assets updated successfully',
          successMessage: '已成功更新 $succeeded 个 Geo 规则文件！',
        );
      }
      return true;
    } else {
      if (!silent) {
        state = state.copyWith(
          isUpdating: false,
          activeAssetName: null,
          errorMessage: 'Failed to update Geo datasets. Please check network connection.',
        );
      }
      return false;
    }
  }
}

final geoUpdaterProvider =
    StateNotifierProvider<GeoUpdaterNotifier, GeoUpdaterState>((ref) {
  return GeoUpdaterNotifier(ref);
});
