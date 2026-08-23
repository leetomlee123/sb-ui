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

  // --- Windows ---

  static Future<bool> _setWindowsProxy(String host, int port) async {
    try {
      final proxyServer = '$host:$port';
      const regKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      final command = "Set-ItemProperty -Path '$regKey' -Name ProxyEnable -Value 1; Set-ItemProperty -Path '$regKey' -Name ProxyServer -Value '$proxyServer'";
      final result = await Process.run('powershell', ['-NoProfile', '-Command', command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _clearWindowsProxy() async {
    try {
      const regKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      final command = "Set-ItemProperty -Path '$regKey' -Name ProxyEnable -Value 0";
      final result = await Process.run('powershell', ['-NoProfile', '-Command', command]);
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
