import 'dart:io';

class SystemProxyManager {
  static Future<bool> setProxy({
    required String host,
    required int port,
  }) async {
    if (Platform.isLinux) {
      return await _setLinuxProxy(host, port);
    } else if (Platform.isWindows) {
      return await _setWindowsProxy(host, port);
    } else if (Platform.isMacOS) {
      return await _setMacProxy(host, port);
    }
    return false;
  }

  static Future<bool> clearProxy() async {
    if (Platform.isLinux) {
      return await _clearLinuxProxy();
    } else if (Platform.isWindows) {
      return await _clearWindowsProxy();
    } else if (Platform.isMacOS) {
      return await _clearMacProxy();
    }
    return false;
  }

  // --- Linux (GNOME / XFCE / KDE) ---

  static Future<bool> _setLinuxProxy(String host, int port) async {
    try {
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'manual']);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.http', 'host', host]);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.http', 'port', port.toString()]);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.https', 'host', host]);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.https', 'port', port.toString()]);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'host', host]);
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy.socks', 'port', port.toString()]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _clearLinuxProxy() async {
    try {
      await Process.run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'none']);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Windows (WinINet with broadcast notification) ---

  static Future<bool> _setWindowsProxy(String host, int port) async {
    try {
      final proxyServer = '$host:$port';
      const proxyOverride = '<local>;localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*';
      
      final psScript = '''
\$reg = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings'
Set-ItemProperty -Path \$reg -Name ProxyEnable -Value 1
Set-ItemProperty -Path \$reg -Name ProxyServer -Value '$proxyServer'
Set-ItemProperty -Path \$reg -Name ProxyOverride -Value '$proxyOverride'

try {
  \$sig = @'
[DllImport("wininet.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
  \$type = Add-Type -MemberDefinition \$sig -Name "WinINetProxy" -Namespace "Win32Native" -PassThru -ErrorAction SilentlyContinue
  if (\$type) {
    [Win32Native.WinINetProxy]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [Win32Native.WinINetProxy]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
  }
} catch {}
''';
      final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _clearWindowsProxy() async {
    try {
      final psScript = '''
\$reg = 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings'
Set-ItemProperty -Path \$reg -Name ProxyEnable -Value 0

try {
  \$sig = @'
[DllImport("wininet.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
  \$type = Add-Type -MemberDefinition \$sig -Name "WinINetProxy" -Namespace "Win32Native" -PassThru -ErrorAction SilentlyContinue
  if (\$type) {
    [Win32Native.WinINetProxy]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [Win32Native.WinINetProxy]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
  }
} catch {}
''';
      final result = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // --- macOS ---

  static Future<bool> _setMacProxy(String host, int port) async {
    try {
      // Find primary network interface (e.g. Wi-Fi or Ethernet)
      const service = 'Wi-Fi';
      await Process.run('networksetup', ['-setwebproxy', service, host, port.toString()]);
      await Process.run('networksetup', ['-setsecurewebproxy', service, host, port.toString()]);
      await Process.run('networksetup', ['-setsocksfirewallproxy', service, host, port.toString()]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _clearMacProxy() async {
    try {
      const service = 'Wi-Fi';
      await Process.run('networksetup', ['-setwebproxystate', service, 'off']);
      await Process.run('networksetup', ['-setsecurewebproxystate', service, 'off']);
      await Process.run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
      return true;
    } catch (_) {
      return false;
    }
  }
}
