import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../utils/proxy_dio_helper.dart';
import 'core_updater_service.dart';

/// Checks GitHub Releases of this app itself and prepares a self-update.
///
/// Release assets follow the CI naming convention:
///   sb-ui-windows-x64-v{tag}.zip
///   SHA256SUMS.txt
class AppUpdaterService {
  static const repoApiUrl =
      'https://api.github.com/repos/leetomlee123/sb-ui/releases/latest';

  final Dio _dio;

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

  /// Configures local proxy port for downloading and API calls when core is running.
  void setProxyPort(int? port) {
    ProxyDioHelper.configureProxy(_dio, proxyPort: port);
  }

  /// Check GitHub for the latest app release (any platform; asset matching is Windows-only).
  Future<RemoteReleaseInfo?> checkLatestRelease() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(repoApiUrl);
      final data = response.data;
      if (data == null) return null;

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
  ///  - `config/`           (user's live config dir)
  ///  - sing-box binaries   (a newer core may already be installed in-place)
  ///
  /// Returns the staging directory path containing the new bundle.
  Future<String> downloadAndPrepare({
    required String downloadUrl,
    String? sha256SumsUrl,
    required void Function(double progress, String status) onProgress,
  }) async {
    onProgress(0.05, 'Connecting to download server...');

    final response = await _dio.get<List<int>>(
      downloadUrl,
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

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Downloaded update archive is empty.');
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
    final stagingDir = await Directory.systemTemp.createTemp('sb_ui_update');
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

  /// Writes the Windows self-swap batch script used to replace a running exe.
  ///
  /// Flow: poll until the app process exits -> rename old exe to `.old`
  /// (allowed even while running) -> xcopy the staged bundle over the app dir
  /// -> delete `.old` only if the new exe landed -> relaunch -> remove the
  /// staging dir -> self-delete.
  Future<String> writeSwapScript({
    required String stagingDir,
    required String appDir,
    required String exeName,
  }) async {
    final scriptPath = p.join(stagingDir, 'sb_ui_self_update.bat');
    final content = '''
@echo off
set "APP_DIR=$appDir"
set "SRC_DIR=$stagingDir"
set "EXE_NAME=$exeName"

:wait_exit
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>nul | find /I "%EXE_NAME%" >nul 2>&1
if not errorlevel 1 (
  ping -n 2 127.0.0.1 >nul
  goto wait_exit
)

if exist "%APP_DIR%\\%EXE_NAME%" move /y "%APP_DIR%\\%EXE_NAME%" "%APP_DIR%\\%EXE_NAME%.old" >nul 2>&1

xcopy /e /y /i "%SRC_DIR%\\*" "%APP_DIR%\\" >nul 2>&1

rem The staging copy includes this script itself; drop the duplicated one.
del /f /q "%APP_DIR%\\sb_ui_self_update.bat" >nul 2>&1

if exist "%APP_DIR%\\%EXE_NAME%" (
  if exist "%APP_DIR%\\%EXE_NAME%.old" del /f /q "%APP_DIR%\\%EXE_NAME%.old" >nul 2>&1
)

cd /d "%APP_DIR%"
start "" "%EXE_NAME%"
rd /s /q "%SRC_DIR%" >nul 2>&1
del /f /q "%~f0" >nul 2>&1
''';
    final scriptFile = File(scriptPath);
    await scriptFile.parent.create(recursive: true);
    await scriptFile.writeAsString(content, flush: true);
    return scriptPath;
  }

  /// Launches the swap script detached from this process so it survives exit.
  Future<void> launchDetached(String scriptPath) async {
    await Process.start(
      'cmd.exe',
      ['/c', scriptPath],
      mode: ProcessStartMode.detached,
    );
  }

  /// Startup cleanup: remove leftover rollback binary and stale staging dirs.
  static Future<void> cleanupOnStartup() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final oldBinary = File(p.join(exeDir, '${p.basename(Platform.resolvedExecutable)}.old'));
      if (await oldBinary.exists()) {
        await oldBinary.delete();
      }
    } catch (_) {}

    try {
      final tmp = Directory.systemTemp;
      await for (final entity in tmp.list()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith('sb_ui_update')) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
