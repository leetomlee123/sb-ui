import 'dart:io';
import 'package:path/path.dart' as p;

class AutoStartService {
  static const String _appName = 'singbox-ui';

  static Future<bool> isAutoStartEnabled() async {
    if (Platform.isWindows) {
      try {
        const regKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
        final command = "Get-ItemPropertyValue -Path '$regKey' -Name '$_appName' -ErrorAction SilentlyContinue";
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);
        return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
      } catch (_) {
        return false;
      }
    } else if (Platform.isLinux) {
      try {
        final home = Platform.environment['HOME'] ?? '';
        final desktopFile = File(p.join(home, '.config', 'autostart', '$_appName.desktop'));
        return await desktopFile.exists();
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<bool> setAutoStart(bool enabled) async {
    if (Platform.isWindows) {
      return await _setWindowsAutoStart(enabled);
    } else if (Platform.isLinux) {
      return await _setLinuxAutoStart(enabled);
    } else if (Platform.isMacOS) {
      return await _setMacAutoStart(enabled);
    }
    return false;
  }

  static Future<bool> _setWindowsAutoStart(bool enabled) async {
    try {
      final exePath = Platform.resolvedExecutable;
      const regKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';

      if (enabled) {
        final command = "Set-ItemProperty -Path '$regKey' -Name '$_appName' -Value '\"$exePath\"'";
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);
        return result.exitCode == 0;
      } else {
        final command = "Remove-ItemProperty -Path '$regKey' -Name '$_appName' -ErrorAction SilentlyContinue";
        final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _setLinuxAutoStart(bool enabled) async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final autostartDir = Directory(p.join(home, '.config', 'autostart'));
      final desktopFile = File(p.join(autostartDir.path, '$_appName.desktop'));

      if (enabled) {
        if (!await autostartDir.exists()) {
          await autostartDir.create(recursive: true);
        }
        final exePath = Platform.resolvedExecutable;
        final content = '''
[Desktop Entry]
Type=Application
Name=sing-box UI
Exec="$exePath"
Terminal=false
Categories=Network;Proxy;
''';
        await desktopFile.writeAsString(content);
        return true;
      } else {
        if (await desktopFile.exists()) {
          await desktopFile.delete();
        }
        return true;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _setMacAutoStart(bool enabled) async {
    try {
      final appPath = Platform.resolvedExecutable;
      if (enabled) {
        final script = 'tell application "System Events" to make login item at end with properties {path:"$appPath", hidden:false}';
        final result = await Process.run('osascript', ['-e', script]);
        return result.exitCode == 0;
      } else {
        final script = 'tell application "System Events" to delete login item "$_appName"';
        final result = await Process.run('osascript', ['-e', script]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }
}
