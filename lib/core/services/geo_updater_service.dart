import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/geo_asset.dart';
import 'storage_service.dart';

class GeoUpdaterService {
  final Dio _dio;

  static const List<Map<String, String>> defaultGeoDefinitions = [
    {
      'name': 'geoip-cn.srs',
      'tag': 'geoip-cn',
      'displayName': '中国大陆 IP 规则集 (geoip-cn.srs)',
      'description': 'sing-box 原生 SRS 二进制规则集，精准匹配中国大陆 IP 范围用于国内直连',
      'primaryUrl': 'https://testingcf.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs',
      'fallbackUrl': 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
    },
    {
      'name': 'geosite-cn.srs',
      'tag': 'geosite-cn',
      'displayName': '中国大陆域名规则集 (geosite-cn.srs)',
      'description': 'sing-box 原生 SRS 二进制规则集，覆盖国内主流网站与服务域名用于直连与 DNS 加速',
      'primaryUrl': 'https://testingcf.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs',
      'fallbackUrl': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
    },
  ];

  GeoUpdaterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'User-Agent': 'sing-box-ui-geo-updater',
                },
              ),
            );

  Future<List<GeoAssetInfo>> getGeoAssets() async {
    final configDir = await StorageService.getAppConfigDir();
    final List<GeoAssetInfo> list = [];

    for (final def in defaultGeoDefinitions) {
      final fileName = def['name']!;
      final targetFile = File(p.join(configDir.path, fileName));

      int size = 0;
      DateTime? modified;
      bool isPresent = false;

      if (await targetFile.exists()) {
        isPresent = true;
        size = await targetFile.length();
        modified = await targetFile.lastModified();
      }

      list.add(
        GeoAssetInfo(
          name: fileName,
          tag: def['tag']!,
          displayName: def['displayName']!,
          description: def['description']!,
          primaryUrl: def['primaryUrl']!,
          fallbackUrl: def['fallbackUrl']!,
          sizeInBytes: size,
          lastModified: modified,
          isInstalled: isPresent && size > 0,
        ),
      );
    }

    return list;
  }

  Future<bool> updateGeoAsset(
    GeoAssetInfo asset, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Connecting to CDN mirror...');

    List<int>? fileBytes;

    // 1. Try primary URL (jsdelivr CDN)
    try {
      final response = await _dio.get<List<int>>(
        asset.primaryUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress((received / total).clamp(0.1, 0.85), 'Downloading ${asset.name}...');
          }
        },
      );
      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        fileBytes = response.data;
      }
    } catch (_) {}

    // 2. Fallback to secondary URL (GitHub Raw) if primary failed
    if (fileBytes == null || fileBytes.isEmpty) {
      onProgress?.call(0.2, 'Retrying from secondary mirror...');
      try {
        final response = await _dio.get<List<int>>(
          asset.fallbackUrl,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress((received / total).clamp(0.2, 0.85), 'Downloading ${asset.name}...');
            }
          },
        );
        if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
          fileBytes = response.data;
        }
      } catch (_) {}
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('Failed to download ${asset.name} from all mirrors.');
    }

    onProgress?.call(0.9, 'Saving ${asset.name}...');

    final configDir = await StorageService.getAppConfigDir();
    final targetFile = File(p.join(configDir.path, asset.name));
    await targetFile.writeAsBytes(fileBytes);

    onProgress?.call(1.0, '${asset.name} updated successfully.');
    return true;
  }
}
