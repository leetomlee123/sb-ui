import 'dart:io';

class NativeFileDialog {
  /// Opens a native system file picker dialog to select a JSON/YAML configuration file.
  /// Returns the absolute path of the selected file, or null if canceled.
  static Future<String?> pickConfigFile() async {
    if (Platform.isWindows) {
      return _pickConfigFileWindows();
    } else if (Platform.isMacOS) {
      return _pickConfigFileMacOS();
    } else if (Platform.isLinux) {
      return _pickConfigFileLinux();
    }
    return null;
  }

  static Future<String?> _pickConfigFileWindows() async {
    // Uses PowerShell to invoke Win32 OpenFileDialog without adding heavy native plugins
    const psScript = r'''
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = "选择 sing-box 配置文件"
$dlg.Filter = "sing-box / Clash 配置 (*.json;*.yaml;*.yml)|*.json;*.yaml;*.yml|JSON 配置文件 (*.json)|*.json|YAML 配置文件 (*.yaml;*.yml)|*.yaml;*.yml|所有文件 (*.*)|*.*"
$dlg.CheckFileExists = $true
$dlg.RestoreDirectory = $true
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::WriteLine($dlg.FileName)
}
''';
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
      ).timeout(const Duration(minutes: 3));
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _pickConfigFileMacOS() async {
    const script =
        'POSIX path of (choose file of type {"json", "yaml", "yml", "public.json", "public.plain-text"} with prompt "选择 sing-box 配置文件")';
    try {
      final result = await Process.run('osascript', ['-e', script])
          .timeout(const Duration(minutes: 3));
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _pickConfigFileLinux() async {
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        '--title=选择 sing-box 配置文件',
        '--file-filter=配置文件 (*.json, *.yaml, *.yml) | *.json *.yaml *.yml',
        '--file-filter=所有文件 (*) | *',
      ]).timeout(const Duration(minutes: 3));
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {
      try {
        final result = await Process.run('kdialog', [
          '--getopenfilename',
          '--title',
          '选择 sing-box 配置文件',
          '*.json *.yaml *.yml',
        ]).timeout(const Duration(minutes: 3));
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty && await File(path).exists()) {
            return path;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
