import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:desktop_updater/desktop_updater.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/proxy_dio_helper.dart';
import 'core_updater_service.dart';
import 'json_file_update_recovery_store.dart';

/// Checks releases of this app itself and performs desktop updates via desktop_updater plugin.
class AppUpdaterService {
  static const repoApiUrl =
      'https://api.github.com/repos/leetomlee123/singular/releases/latest';

  final Dio _dio;
  final DesktopUpdater _desktopUpdater = DesktopUpdater();

  AppUpdaterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(minutes: 5),
                headers: {
                  'User-Agent': 'sing-box-ui-app-updater',
                  'Accept': 'application/vnd.github.v3+json',
                },
              ),
            );

  /// Desktop updater facade from desktop_updater package
  DesktopUpdater get desktopUpdater => _desktopUpdater;

  /// Returns current desktop app version from native desktop_updater plugin
  Future<String?> getCurrentVersion() async {
    try {
      return await _desktopUpdater.getCurrentVersion();
    } catch (_) {
      return null;
    }
  }

  /// Returns current executable path from native desktop_updater plugin
  Future<String?> getExecutablePath() async {
    try {
      return await _desktopUpdater.getExecutablePath();
    } catch (_) {
      return null;
    }
  }

  /// Restarts the application via native desktop_updater helper
  Future<void> restartApp() async {
    try {
      await _desktopUpdater.restartApp();
    } catch (_) {}
  }

  /// Creates a configured DesktopUpdaterController with local recovery store
  static Future<DesktopUpdaterController> createDesktopUpdaterController({
    required Uri appArchiveUrl,
    Map<String, String>? trustedReleasePublicKeys,
    String? expectedPackageId,
    String channel = 'stable',
  }) async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    final separator = Platform.pathSeparator;
    final recoveryStore = JsonFileUpdateRecoveryStore(
      File(
        '${appSupportDirectory.path}${separator}desktop_updater'
        '${separator}pending-install-$channel.json',
      ),
    );

    String packageId = expectedPackageId ?? 'sb_ui';
    if (expectedPackageId == null) {
      if (Platform.isMacOS) packageId = 'com.singular.desktop';
      if (Platform.isWindows) packageId = 'sb_ui';
      if (Platform.isLinux) packageId = 'com.singular.desktop';
    }

    return DesktopUpdaterController(
      appArchiveUrl: appArchiveUrl,
      expectedPackageId: packageId,
      trustedReleasePublicKeys: trustedReleasePublicKeys ?? {},
      recoveryStore: recoveryStore,
      channel: channel,
    );
  }

  /// Configures local proxy port for downloading and API calls when core is running.
  void setProxyPort(int? port) {
    ProxyDioHelper.configureProxy(_dio, proxyPort: port);
  }

  /// Check GitHub for the latest app release (any platform; asset matching is Windows-only).
  Future<RemoteReleaseInfo?> checkLatestRelease() async {
    final apiUrls = [
      repoApiUrl,
      'https://ghproxy.net/$repoApiUrl',
      'https://mirror.ghproxy.com/$repoApiUrl',
    ];

    Map<String, dynamic>? data;
    for (final url in apiUrls) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(url);
        if (response.data != null && response.data!['tag_name'] != null) {
          data = response.data;
          break;
        }
      } catch (_) {}
    }

    if (data == null) return null;

    try {
      final tagName = (data['tag_name'] ?? '').toString();
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = (data['body'] ?? '').toString();
      final publishedAt = DateTime.tryParse((data['published_at'] ?? '').toString()) ?? DateTime.now();

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? assetKeyword;
      if (Platform.isWindows) {
        assetKeyword = 'windows-x64';
      } else if (Platform.isLinux) {
        assetKeyword = 'linux-x64';
      } else if (Platform.isMacOS) {
        assetKeyword = 'macos';
      }
      if (assetKeyword == null) return null;

      Map<String, dynamic>? matchingAsset;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name.contains(assetKeyword) && name.endsWith('.zip')) {
            matchingAsset = asset;
            break;
          }
        }
      }

      // Optional checksum manifest shipped alongside the bundle.
      Map<String, dynamic>? sumsAsset;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name == 'sha256sums.txt') {
            sumsAsset = asset;
            break;
          }
        }
      }

      if (matchingAsset == null) return null;

      return RemoteReleaseInfo(
        tagName: tagName,
        version: version,
        releaseNotes: releaseNotes,
        assetName: (matchingAsset['name'] ?? '').toString(),
        downloadUrl: (matchingAsset['browser_download_url'] ?? '').toString(),
        assetSize: int.tryParse((matchingAsset['size'] ?? '0').toString()) ?? 0,
        publishedAt: publishedAt,
        sha256SumsUrl: sumsAsset == null
            ? null
            : (sumsAsset['browser_download_url'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the release zip, verifies its SHA256 against SHA256SUMS.txt
  /// when available, and extracts it into a fresh temp staging directory.
  ///
  /// Files that must never clobber the live install are stripped from the
  /// staging copy first:
  ///  - `config/` (user's live config dir)
  ///
  /// Returns the staging directory path containing the new bundle.
  Future<String> downloadAndPrepare({
    required String downloadUrl,
    String? sha256SumsUrl,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.05, 'Connecting to download server...');

    List<int>? bytes;
    final downloadUrls = [
      downloadUrl,
      'https://ghproxy.net/$downloadUrl',
      'https://mirror.ghproxy.com/$downloadUrl',
    ];

    dynamic lastError;
    for (final url in downloadUrls) {
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = (received / total).clamp(0.05, 0.85);
              onProgress(
                progress,
                'Downloading: ${(received / (1024 * 1024)).toStringAsFixed(1)} MB / '
                '${(total / (1024 * 1024)).toStringAsFixed(1)} MB',
              );
            }
          },
        );
        if (response.data != null && response.data!.isNotEmpty) {
          bytes = response.data;
          break;
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Failed to download update archive: $lastError');
    }

    // Verify integrity via SHA256SUMS.txt when the release provides one.
    final expectedSha256 = await _fetchExpectedSha256(
      p.basename(downloadUrl),
      sha256SumsUrl,
    );
    if (expectedSha256 != null) {
      onProgress(0.87, 'Verifying download integrity...');
      final actual = crypto.sha256.convert(bytes).toString();
      if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
        throw Exception('SHA256 verification failed. The download may be corrupted.');
      }
    }

    onProgress(0.90, 'Extracting update package...');
    final stagingDir = await Directory.systemTemp.createTemp('singular_update');
    final archive = ZipDecoder().decodeBytes(bytes);
    await _extractArchive(archive, stagingDir.path);

    // Strip paths that must not overwrite the user's live installation.
    await _deleteIfExists(Directory(p.join(stagingDir.path, 'config')));
    await _deleteIfExists(File(p.join(stagingDir.path, 'sing-box.exe')));
    await _deleteIfExists(File(p.join(stagingDir.path, 'data', 'core', 'sing-box.exe')));

    onProgress(1.0, 'Update package ready');
    return stagingDir.path;
  }

  /// Looks up the expected hash for [assetName] inside the release's
  /// SHA256SUMS.txt ("hash␣␣filename" lines). Returns null if unavailable.
  Future<String?> _fetchExpectedSha256(String assetName, String? sumsUrl) async {
    if (sumsUrl == null || sumsUrl.isEmpty) return null;
    try {
      final res = await _dio.get<String>(
        sumsUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final text = res.data;
      if (text == null || text.isEmpty) return null;
      for (final line in text.split('\n')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1].toLowerCase() == assetName.toLowerCase()) {
          return parts[0];
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _extractArchive(Archive archive, String destPath) async {
    for (final file in archive) {
      final outPath = p.normalize(p.join(destPath, file.name));
      if (!p.isWithin(destPath, outPath)) continue; // guard zip-slip

      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Performs atomic in-place desktop update handoff using the native desktop_updater plugin.
  Future<void> installNativeUpdate({
    required String stagingPath,
    required String version,
    String packageId = 'sb_ui',
    String channel = 'stable',
    String? artifactSha256,
  }) async {
    const channelName = MethodChannel('desktop_updater');
    final transactionId = _generateUuidV4();
    final dummyProvenanceSha256 = artifactSha256 ?? ('0' * 64);
    final expectedSha256 = artifactSha256 ?? ('0' * 64);

    await channelName.invokeMethod<void>('installUpdate', {
      'stagingPath': stagingPath,
      'expectedPackageId': packageId,
      'updateVersion': version,
      'updateBuildNumber': null,
      'platform': 'windows-x64',
      'channel': channel,
      'expectedArtifactSha256': expectedSha256,
      'stageProvenanceSha256': dummyProvenanceSha256,
      'transactionId': transactionId,
    });
  }

  static String _generateUuidV4() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Startup cleanup: remove leftover staging dirs.
  static Future<void> cleanupOnStartup() async {
    try {
      final tmp = Directory.systemTemp;
      await for (final entity in tmp.list(followLinks: false)) {
        if (entity is Directory) {
          final base = p.basename(entity.path);
          if (base.startsWith('singular_update')) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
