import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:desktop_updater/desktop_updater.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';
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

  static const kTrustedReleasePublicKeys = <String, String>{
    'release-5990b8030c853b5353c59397': '/J66UPbmhTRQwNKuGJGejVOFo1rZyXjDQDeizo4SEos=',
  };

  static const kDefaultAppArchiveUrl =
      'https://github.com/leetomlee123/singular/releases/latest/download/app-archive.json';

  /// Creates a configured DesktopUpdaterController with local recovery store
  static Future<DesktopUpdaterController> createDesktopUpdaterController({
    Uri? appArchiveUrl,
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

    String packageId = expectedPackageId ?? 'singular';
    if (expectedPackageId == null) {
      if (Platform.isMacOS) packageId = 'singular';
      if (Platform.isWindows) packageId = 'singular';
      if (Platform.isLinux) packageId = 'singular';
    }

    return DesktopUpdaterController(
      appArchiveUrl: appArchiveUrl ?? Uri.parse(kDefaultAppArchiveUrl),
      expectedPackageId: packageId,
      trustedReleasePublicKeys: trustedReleasePublicKeys ?? kTrustedReleasePublicKeys,
      recoveryStore: recoveryStore,
      channel: channel,
      skipInitialVersionCheck: true,
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
    String? lastError;
    for (final url in apiUrls) {
      try {
        AppLogger.info('[AppUpdater] 尝试请求 GitHub 版本源: $url');
        final response = await _dio.get<Map<String, dynamic>>(url);
        if (response.data != null && response.data!['tag_name'] != null) {
          data = response.data;
          AppLogger.info('[AppUpdater] 成功获取版本信息，最新版本标签: ${data!['tag_name']}');
          break;
        }
      } catch (e) {
        lastError = e.toString();
        AppLogger.warn('[AppUpdater] 请求更新源接口失败 ($url): $e');
      }
    }

    if (data == null) {
      if (lastError != null) {
        AppLogger.error('[AppUpdater] 所有 GitHub Release 接口均访问失败: $lastError');
      }
      return null;
    }

    try {
      final tagName = (data['tag_name'] ?? '').toString();
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = (data['body'] ?? '').toString();
      final publishedAt = DateTime.tryParse((data['published_at'] ?? '').toString()) ?? DateTime.now();

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? assetKeyword;
      if (Platform.isWindows) {
        assetKeyword = 'windows';
      } else if (Platform.isLinux) {
        assetKeyword = 'linux';
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

      if (matchingAsset == null) {
        AppLogger.warn('[AppUpdater] 未在 Release ($tagName) 资产中匹配到 $assetKeyword 平台的 .zip 安装包');
        return null;
      }

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

    // If zip contains a single root folder (e.g. singular-windows-x64-v1.2.15/), flatten it
    try {
      final entries = await stagingDir.list(followLinks: false).toList();
      if (entries.length == 1 && entries.first is Directory) {
        final subDir = entries.first as Directory;
        final subDirName = p.basename(subDir.path);
        if (subDirName != 'data' && subDirName != 'config') {
          await for (final entity in subDir.list(followLinks: false)) {
            final dest = p.join(stagingDir.path, p.basename(entity.path));
            await entity.rename(dest);
          }
          await subDir.delete(recursive: true);
        }
      }
    } catch (_) {}

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

  /// Writes and launches the bulletproof background self-update worker.
  /// Decouples completely from the main application process and survives app exit.
  Future<void> prepareAndLaunchUpdate({
    required String stagingPath,
    required String appDir,
    required String exeName,
    int? targetPid,
  }) async {
    final currentPid = targetPid ?? pid;

    if (Platform.isWindows) {
      final batPath = p.join(Directory.systemTemp.path, 'singular_updater.bat');
      final vbsPath = p.join(Directory.systemTemp.path, 'singular_launch.vbs');

      final batContent = '''
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set OLD_PID=$currentPid
set STAGING_DIR=$stagingPath
set TARGET_DIR=$appDir
set EXE_NAME=$exeName

:: 1. Wait for parent process to exit
for /l %%i in (1, 1, 30) do (
    tasklist /fi "PID eq !OLD_PID!" 2>nul | findstr /i "!OLD_PID!" >nul
    if errorlevel 1 goto :SWAP
    timeout /t 1 /nobreak >nul
)

:: Force kill if still lingering
taskkill /f /pid !OLD_PID! >nul 2>&1
timeout /t 1 /nobreak >nul

:SWAP
:: 2. Safety pause to ensure all file handles and DLLs are fully unlocked
timeout /t 1 /nobreak >nul

:: 3. Backup old executables
if exist "!TARGET_DIR!\\!EXE_NAME!" (
    move /y "!TARGET_DIR!\\!EXE_NAME!" "!TARGET_DIR!\\!EXE_NAME!.old" >nul 2>&1
)
if exist "!TARGET_DIR!\\singular.exe" (
    move /y "!TARGET_DIR!\\singular.exe" "!TARGET_DIR!\\singular.exe.old" >nul 2>&1
)

:: 4. Robust recursive copy from staging to app directory
robocopy "!STAGING_DIR!" "!TARGET_DIR!" /E /IS /IT /R:5 /W:1 /NP /NFL /NDL /NJH /NJS >nul 2>&1
if errorlevel 8 (
    xcopy "!STAGING_DIR!\\*" "!TARGET_DIR!\\" /E /Y /I /Q >nul 2>&1
)

:: 5. Launch the updated application
cd /d "!TARGET_DIR!"
if exist "!TARGET_DIR!\\singular.exe" (
    start "" "!TARGET_DIR!\\singular.exe"
) else if exist "!TARGET_DIR!\\!EXE_NAME!" (
    start "" "!TARGET_DIR!\\!EXE_NAME!"
)

:: 6. Clean staging directory
timeout /t 2 /nobreak >nul
rmdir /s /q "!STAGING_DIR!" >nul 2>&1
exit 0
''';

      final vbsContent = '''
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "cmd.exe /c """ & WScript.Arguments(0) & """", 0, False
''';

      final batFile = File(batPath);
      await batFile.writeAsString(batContent, flush: true);

      final vbsFile = File(vbsPath);
      await vbsFile.writeAsString(vbsContent, flush: true);

      // Launch hidden background detached worker via Windows Script Host (wscript.exe)
      await Process.start(
        'wscript.exe',
        [vbsPath, batPath],
        mode: ProcessStartMode.detached,
      );
      return;
    }

    // Linux / macOS fallback script
    final shPath = p.join(Directory.systemTemp.path, 'singular_updater.sh');
    final shContent = '''
#!/bin/bash
PID=$currentPid
STAGING="$stagingPath"
APPDIR="$appDir"
EXE="$exeName"

for i in {1..30}; do
    if ! kill -0 \$PID 2>/dev/null; then
        break
    fi
    sleep 1
done

cp -rf "\$STAGING"/* "\$APPDIR"/
cd "\$APPDIR"
nohup ./"\$EXE" >/dev/null 2>&1 &
rm -rf "\$STAGING"
''';
    final shFile = File(shPath);
    await shFile.writeAsString(shContent, flush: true);
    await Process.run('chmod', ['+x', shPath]);
    await Process.start('sh', [shPath], mode: ProcessStartMode.detached);
  }

  /// Startup cleanup: remove leftover staging dirs, scripts and rollback binaries.
  static Future<void> cleanupOnStartup() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final oldBinary = File(p.join(exeDir, '${p.basename(Platform.resolvedExecutable)}.old'));
      if (await oldBinary.exists()) {
        await oldBinary.delete();
      }
      final oldSingular = File(p.join(exeDir, 'singular.exe.old'));
      if (await oldSingular.exists()) {
        await oldSingular.delete();
      }
    } catch (_) {}

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
        } else if (entity is File) {
          final base = p.basename(entity.path);
          if (base.startsWith('singular_updater') || base.startsWith('singular_launch') || base.startsWith('singular_self_update')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
