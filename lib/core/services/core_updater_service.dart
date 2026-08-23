import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'storage_service.dart';

class RemoteReleaseInfo {
  final String tagName;
  final String version;
  final String releaseNotes;
  final String assetName;
  final String downloadUrl;
  final int assetSize;
  final DateTime publishedAt;

  /// Optional URL of a SHA256SUMS.txt manifest shipped with the release
  /// (currently only the app's own releases provide one).
  final String? sha256SumsUrl;

  RemoteReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    required this.assetName,
    required this.downloadUrl,
    required this.assetSize,
    required this.publishedAt,
    this.sha256SumsUrl,
  });
}

class CoreUpdaterService {
  final Dio _dio;

  CoreUpdaterService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent': 'sing-box-ui-updater',
                  'Accept': 'application/vnd.github.v3+json',
                },
              ),
            );

  /// Check GitHub for the latest sing-box release
  Future<RemoteReleaseInfo?> checkLatestRelease() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/SagerNet/sing-box/releases/latest',
      );

      final data = response.data;
      if (data == null) return null;

      final tagName = (data['tag_name'] ?? '').toString();
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = (data['body'] ?? '').toString();
      final publishedAt = DateTime.tryParse((data['published_at'] ?? '').toString()) ?? DateTime.now();

      final assets = data['assets'] as List<dynamic>? ?? [];

      // Determine asset match pattern based on OS and architecture
      final targetKeyword = _getAssetKeyword();
      if (targetKeyword == null) return null;

      Map<String, dynamic>? matchingAsset;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] ?? '').toString().toLowerCase();
          if (name.contains(targetKeyword) &&
              (name.endsWith('.zip') || name.endsWith('.tar.gz'))) {
            matchingAsset = asset;
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
      );
    } catch (_) {
      return null;
    }
  }

  String? _getAssetKeyword() {
    if (Platform.isWindows) {
      return 'windows-amd64';
    } else if (Platform.isLinux) {
      return 'linux-amd64';
    } else if (Platform.isMacOS) {
      return 'darwin-universal';
    }
    return null;
  }

  /// Download archive and extract sing-box binary
  Future<String> downloadAndInstall({
    required String downloadUrl,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.05, 'Connecting to download server...');

    final response = await _dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = (received / total).clamp(0.05, 0.85);
          onProgress(progress, 'Downloading: ${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB');
        }
      },
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Downloaded binary archive is empty.');
    }

    onProgress(0.90, 'Extracting core executable...');

    // Extract sing-box binary from downloaded archive
    List<int>? extractedBinaryBytes;
    final binaryName = Platform.isWindows ? 'sing-box.exe' : 'sing-box';

    if (downloadUrl.endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile && (file.name.endsWith(binaryName) || file.name.endsWith('/$binaryName') || file.name == binaryName)) {
          extractedBinaryBytes = file.content as List<int>;
          break;
        }
      }
    } else if (downloadUrl.endsWith('.tar.gz') || downloadUrl.endsWith('.tgz')) {
      final tarBytes = GZipDecoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(tarBytes);
      for (final file in archive) {
        if (file.isFile && (file.name.endsWith(binaryName) || file.name.endsWith('/$binaryName') || file.name == binaryName)) {
          extractedBinaryBytes = file.content as List<int>;
          break;
        }
      }
    }

    if (extractedBinaryBytes == null || extractedBinaryBytes.isEmpty) {
      throw Exception('Could not locate $binaryName inside the release archive.');
    }

    onProgress(0.95, 'Installing binary...');

    // Determine target location (prefer application data/core directory or ./config)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final primaryTargetDir = Directory(p.join(exeDir, 'data', 'core'));

    String targetFilePath;
    try {
      if (!await primaryTargetDir.exists()) {
        await primaryTargetDir.create(recursive: true);
      }
      targetFilePath = p.join(primaryTargetDir.path, binaryName);
      await File(targetFilePath).writeAsBytes(extractedBinaryBytes);
    } catch (_) {
      // Fallback to app config dir
      final configDir = await StorageService.getAppConfigDir();
      targetFilePath = p.join(configDir.path, binaryName);
      await File(targetFilePath).writeAsBytes(extractedBinaryBytes);
    }

    // Set executable permission on Unix
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['+x', targetFilePath]);
      } catch (_) {}
    }

    onProgress(1.0, 'Core updated successfully');
    return targetFilePath;
  }
}
