import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:desktop_updater/desktop_updater.dart';
import 'package:dio/dio.dart';
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

  /// Writes the Windows self-swap PowerShell script used to safely replace
  /// the running executable and relaunch the updated application.
  Future<String> writeSwapScript({
    required String stagingDir,
    required String appDir,
    required String exeName,
    int? targetPid,
  }) async {
    final currentPid = targetPid ?? pid;
    final scriptPath = p.join(stagingDir, 'singular_self_update.ps1');

    final content = '''
# Singular Windows Silent Self-Updater
\$targetPid = $currentPid
\$appDir = "$appDir"
\$srcDir = "$stagingDir"
\$exeName = "$exeName"

# 1. Wait for the old process to fully exit (max 8 seconds)
for (\$i = 0; \$i -lt 40; \$i++) {
    \$proc = Get-Process -Id \$targetPid -ErrorAction SilentlyContinue
    if (-not \$proc -or \$proc.HasExited) { break }
    Start-Sleep -Milliseconds 200
}

# Force terminate any lingering instances of the target process
\$proc = Get-Process -Id \$targetPid -ErrorAction SilentlyContinue
if (\$proc -and -not \$proc.HasExited) {
    Stop-Process -Id \$targetPid -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}
Get-Process -Name "singular" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Ensure file handles are fully released
Start-Sleep -Milliseconds 500

# 2. Backup or rename old executable files
\$targetExePath = Join-Path \$appDir \$exeName
if (Test-Path \$targetExePath) {
    try {
        Move-Item -Path \$targetExePath -Destination "\$targetExePath.old" -Force -ErrorAction SilentlyContinue
    } catch {}
}

# 3. Robust directory tree copy (uses robocopy or recursive file sync without directory collisions)
\$copySuccess = \$false
for (\$attempt = 1; \$attempt -le 5; \$attempt++) {
    try {
        & robocopy \$srcDir \$appDir /E /IS /IT /R:2 /W:1 /NP /NFL /NDL /NJH /NJS | Out-Null
        if (\$LASTEXITCODE -ge 0 -and \$LASTEXITCODE -le 7) {
            \$copySuccess = \$true
            break
        }
    } catch {}

    try {
        Get-ChildItem -Path \$srcDir -Recurse | ForEach-Object {
            \$relPath = \$_.FullName.Substring(\$srcDir.Length).TrimStart('\\\\', '/')
            \$destPath = Join-Path \$appDir \$relPath
            if (\$_.PSIsContainer) {
                if (-not (Test-Path \$destPath)) {
                    New-Item -ItemType Directory -Path \$destPath -Force | Out-Null
                }
            } else {
                \$destParent = Split-Path \$destPath -Parent
                if (-not (Test-Path \$destParent)) {
                    New-Item -ItemType Directory -Path \$destParent -Force | Out-Null
                }
                Copy-Item -Path \$_.FullName -Destination \$destPath -Force -ErrorAction SilentlyContinue
            }
        }
        if (Test-Path (Join-Path \$appDir "singular.exe") -or (Test-Path (Join-Path \$appDir \$exeName))) {
            \$copySuccess = \$true
            break
        }
    } catch {}

    Start-Sleep -Milliseconds 600
}

# 4. Rollback safety: if copy failed, restore backup
if (-not (Test-Path (Join-Path \$appDir "singular.exe")) -and -not (Test-Path (Join-Path \$appDir \$exeName))) {
    if (Test-Path "\$targetExePath.old") {
        Move-Item -Path "\$targetExePath.old" -Destination \$targetExePath -Force -ErrorAction SilentlyContinue
    }
} else {
    Remove-Item -Path (Join-Path \$appDir "\$exeName.old") -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path \$appDir "singular.exe.old") -Force -ErrorAction SilentlyContinue
}

# Remove updater script from destination if copied over
\$copiedScript = Join-Path \$appDir "singular_self_update.ps1"
if (Test-Path \$copiedScript) {
    Remove-Item -Path \$copiedScript -Force -ErrorAction SilentlyContinue
}

# 5. Resolve and launch the new executable
\$launchTarget = Join-Path \$appDir "singular.exe"
if (-not (Test-Path \$launchTarget)) {
    \$launchTarget = Join-Path \$appDir \$exeName
}

if (Test-Path \$launchTarget) {
    Start-Process -FilePath \$launchTarget -WorkingDirectory \$appDir
}

# 6. Clean up temporary staging directory
Start-Sleep -Seconds 1
Remove-Item -Path \$srcDir -Recurse -Force -ErrorAction SilentlyContinue
''';

    final scriptFile = File(scriptPath);
    await scriptFile.parent.create(recursive: true);
    await scriptFile.writeAsString(content, flush: true);
    return scriptPath;
  }

  /// Launches the swap script detached and silently in background without any visible console window.
  Future<void> launchDetached(String scriptPath) async {
    if (Platform.isWindows) {
      try {
        await Process.start(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-WindowStyle',
            'Hidden',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            scriptPath,
          ],
          mode: ProcessStartMode.detached,
        );
        return;
      } catch (_) {}
    }

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
