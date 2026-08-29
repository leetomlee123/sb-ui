import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../models/geo_asset.dart';
import '../utils/proxy_dio_helper.dart';
import 'storage_service.dart';

class GeoUpdaterService {
  final Dio _dio;

  static const List<Map<String, String>> defaultGeoDefinitions = [
    {
      'name': 'geoip-cn.srs',
      'tag': 'geoip-cn',
      'displayName': '中国大陆 IP 规则集 (geoip-cn.srs)',
      'description': 'sing-box 原生 SRS 二进制规则集，精准匹配中国大陆 IP 范围用于国内直连',
      'primaryUrl': 'https://fastly.jsdelivr.net/gh/SagerNet/sing-geoip@rule-set/geoip-cn.srs',
      'fallbackUrl': 'https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.srs',
    },
    {
      'name': 'geosite-cn.srs',
      'tag': 'geosite-cn',
      'displayName': '中国大陆域名规则集 (geosite-cn.srs)',
      'description': 'sing-box 原生 SRS 二进制规则集，覆盖国内主流网站与服务域名用于直连与 DNS 加速',
      'primaryUrl': 'https://fastly.jsdelivr.net/gh/SagerNet/sing-geosite@rule-set/geosite-cn.srs',
      'fallbackUrl': 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.srs',
    },
  ];

  GeoUpdaterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'User-Agent': 'sing-box-ui-geo-updater',
                },
              ),
            );

  /// Configures local proxy port for downloading rule sets when core is running.
  void setProxyPort(int? port) {
    ProxyDioHelper.configureProxy(_dio, proxyPort: port);
  }

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

    final repo = asset.name.startsWith('geosite') ? 'sing-geosite' : 'sing-geoip';
    final candidateUrls = [
      'https://fastly.jsdelivr.net/gh/SagerNet/$repo@rule-set/${asset.name}',
      'https://cdn.jsdelivr.net/gh/SagerNet/$repo@rule-set/${asset.name}',
      'https://gcore.jsdelivr.net/gh/SagerNet/$repo@rule-set/${asset.name}',
      'https://testingcf.jsdelivr.net/gh/SagerNet/$repo@rule-set/${asset.name}',
      'https://raw.gitmirror.com/SagerNet/$repo/rule-set/${asset.name}',
      'https://ghproxy.net/https://raw.githubusercontent.com/SagerNet/$repo/rule-set/${asset.name}',
      'https://mirror.ghproxy.com/https://raw.githubusercontent.com/SagerNet/$repo/rule-set/${asset.name}',
      asset.primaryUrl,
      asset.fallbackUrl,
    ];

    for (int i = 0; i < candidateUrls.length; i++) {
      final url = candidateUrls[i];
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
          ),
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress((received / total).clamp(0.1, 0.85), 'Downloading ${asset.name}...');
            }
          },
        );
        if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
          fileBytes = response.data;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    final configDir = await StorageService.getAppConfigDir();
    final targetFile = File(p.join(configDir.path, asset.name));

    if (fileBytes != null && fileBytes.isNotEmpty) {
      if (await targetFile.exists()) {
        try {
          final existingBytes = await targetFile.readAsBytes();
          if (existingBytes.length == fileBytes.length) {
            bool identical = true;
            for (int i = 0; i < existingBytes.length; i++) {
              if (existingBytes[i] != fileBytes[i]) {
                identical = false;
                break;
              }
            }
            if (identical) {
              onProgress?.call(1.0, '${asset.name} 已经是最新版本。');
              return false; // Already up-to-date, no change
            }
          }
        } catch (_) {}
      }

      onProgress?.call(0.9, 'Saving ${asset.name}...');
      await targetFile.writeAsBytes(fileBytes);
      onProgress?.call(1.0, '${asset.name} updated successfully.');
      return true; // Actually updated with new content
    }

    // Fallback: If offline and local target file does not exist or is empty, copy from bundled assets/rules
    if (!await targetFile.exists() || await targetFile.length() == 0) {
      try {
        final byteData = await rootBundle.load('assets/rules/${asset.name}');
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
        onProgress?.call(1.0, '${asset.name} restored from offline bundle.');
        return true;
      } catch (_) {}
    }

    throw Exception('Failed to download ${asset.name} from all mirrors.');
  }
}
