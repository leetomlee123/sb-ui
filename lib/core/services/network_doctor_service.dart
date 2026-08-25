import 'dart:io';
import 'package:dio/dio.dart';
import '../models/app_settings.dart';
import '../process/singbox_process_manager.dart';
import 'storage_service.dart';

enum DiagnosticStatus { pass, warn, fail, checking }

class DiagnosticItem {
  final String key;
  final String title;
  final String description;
  final DiagnosticStatus status;
  final String detail;

  DiagnosticItem({
    required this.key,
    required this.title,
    required this.description,
    required this.status,
    required this.detail,
  });

  DiagnosticItem copyWith({
    DiagnosticStatus? status,
    String? detail,
  }) {
    return DiagnosticItem(
      key: key,
      title: title,
      description: description,
      status: status ?? this.status,
      detail: detail ?? this.detail,
    );
  }
}

class NetworkDoctorService {
  static Future<List<DiagnosticItem>> runDiagnostics({
    required AppSettings settings,
    required bool isCoreRunning,
  }) async {
    final results = <DiagnosticItem>[];

    // 1. Core Executable Check
    final manager = SingboxProcessManager();
    final coreBinPath = await manager.findSingboxBinary(
      customPath: settings.customSingboxPath.isNotEmpty ? settings.customSingboxPath : null,
    );

    if (coreBinPath != null) {
      try {
        final res = await Process.run(coreBinPath, ['version']);
        if (res.exitCode == 0) {
          final firstLine = (res.stdout as String).split('\n').first.trim();
          results.add(DiagnosticItem(
            key: 'core_bin',
            title: 'sing-box 内核可执行程序',
            description: '检查核心文件是否存在并可正常响应指令',
            status: DiagnosticStatus.pass,
            detail: '文件就绪 ($firstLine)',
          ));
        } else {
          results.add(DiagnosticItem(
            key: 'core_bin',
            title: 'sing-box 内核可执行程序',
            description: '核心文件执行返回异常状态码',
            status: DiagnosticStatus.warn,
            detail: '退出码: ${res.exitCode}',
          ));
        }
      } catch (e) {
        results.add(DiagnosticItem(
          key: 'core_bin',
          title: 'sing-box 内核可执行程序',
          description: '调用核心文件失败',
          status: DiagnosticStatus.fail,
          detail: '$e',
        ));
      }
    } else {
      results.add(DiagnosticItem(
        key: 'core_bin',
        title: 'sing-box 内核可执行程序',
        description: '未在系统路径或应用目录检测到内核程序',
        status: DiagnosticStatus.fail,
        detail: '未找到有效 sing-box 核心',
      ));
    }

    // 2. Windows Wintun Driver Check (for TUN mode)
    if (Platform.isWindows) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final configDir = (await StorageService.getAppConfigDir()).path;
        final wintunCandidates = [
          '$exeDir/data/core/wintun.dll',
          '$exeDir/wintun.dll',
          '$configDir/wintun.dll',
          r'C:\Windows\System32\wintun.dll',
        ];
        bool wintunFound = false;
        String foundPath = '';
        for (final p in wintunCandidates) {
          if (await File(p).exists()) {
            wintunFound = true;
            foundPath = p;
            break;
          }
        }

        if (wintunFound) {
          results.add(DiagnosticItem(
            key: 'wintun_driver',
            title: 'Wintun 虚拟网卡驱动',
            description: '检查 TUN 模式必需的 Windows Wintun 驱动动态库',
            status: DiagnosticStatus.pass,
            detail: '已就绪 ($foundPath)',
          ));
        } else {
          results.add(DiagnosticItem(
            key: 'wintun_driver',
            title: 'Wintun 虚拟网卡驱动',
            description: '未检测到 wintun.dll，开启 TUN 虚拟网卡将无法建立适配器',
            status: settings.tunModeEnabled ? DiagnosticStatus.fail : DiagnosticStatus.warn,
            detail: '缺失 wintun.dll，请将驱动放入应用目录或重新下载完整包',
          ));
        }
      } catch (e) {
        results.add(DiagnosticItem(
          key: 'wintun_driver',
          title: 'Wintun 虚拟网卡驱动',
          description: '检测驱动异常',
          status: DiagnosticStatus.warn,
          detail: '$e',
        ));
      }
    }

    // 3. Port Binding & Conflict Check
    final mixedPort = settings.mixedPort;
    final clashPort = settings.clashApiPort;
    bool mixedPortOk = true;
    bool clashPortOk = true;
    try {
      final s1 = await ServerSocket.bind(InternetAddress.loopbackIPv4, mixedPort);
      await s1.close();
    } catch (_) {
      mixedPortOk = isCoreRunning;
    }
    try {
      final s2 = await ServerSocket.bind(InternetAddress.loopbackIPv4, clashPort);
      await s2.close();
    } catch (_) {
      clashPortOk = isCoreRunning;
    }

    if (mixedPortOk && clashPortOk) {
      results.add(DiagnosticItem(
        key: 'ports',
        title: '本地监听端口状态',
        description: '检查混合入站端口 ($mixedPort) 与 Clash 控制器端口 ($clashPort)',
        status: DiagnosticStatus.pass,
        detail: '端口可用，无第三方进程冲突',
      ));
    } else {
      results.add(DiagnosticItem(
        key: 'ports',
        title: '本地监听端口状态',
        description: '检测到端口已被系统其他程序占用',
        status: DiagnosticStatus.fail,
        detail: '冲突端口: ${!mixedPortOk ? "$mixedPort " : ""}${!clashPortOk ? "$clashPort" : ""}',
      ));
    }

    // 4. GeoIP / GeoSite / SRS Rule-set Integrity Check
    try {
      final appDir = await StorageService.getAppConfigDir();
      final exeDir = File(Platform.resolvedExecutable).parent.path;

      Future<File?> findRuleFile(String filename) async {
        final candidates = [
          '${appDir.path}/$filename',
          '$exeDir/config/$filename',
          '$exeDir/$filename',
          'assets/rules/$filename',
        ];
        for (final path in candidates) {
          final f = File(path);
          if (await f.exists() && (await f.length()) > 500) {
            return f;
          }
        }
        return null;
      }

      final geoipSrs = await findRuleFile('geoip-cn.srs');
      final geositeSrs = await findRuleFile('geosite-cn.srs');
      final geoipDb = await findRuleFile('geoip.db');
      final geositeDb = await findRuleFile('geosite.db');

      if (geoipSrs != null && geositeSrs != null) {
        final ipKb = (await geoipSrs.length()) ~/ 1024;
        final siteKb = (await geositeSrs.length()) ~/ 1024;
        results.add(DiagnosticItem(
          key: 'geo_assets',
          title: 'GeoIP / GeoSite 路由规则集',
          description: '检查 sing-box 原生 SRS 二进制规则集 (geoip-cn.srs / geosite-cn.srs)',
          status: DiagnosticStatus.pass,
          detail: '规则集就绪 (SRS 二进制: geoip-cn ${ipKb}KB, geosite-cn ${siteKb}KB)',
        ));
      } else if (geoipDb != null && geositeDb != null) {
        final ipKb = (await geoipDb.length()) ~/ 1024;
        final siteKb = (await geositeDb.length()) ~/ 1024;
        results.add(DiagnosticItem(
          key: 'geo_assets',
          title: 'GeoIP / GeoSite 路由规则库',
          description: '检查传统 Geo 数据库文件完整性',
          status: DiagnosticStatus.pass,
          detail: '规则库就绪 (传统 DB: GeoIP ${ipKb}KB, GeoSite ${siteKb}KB)',
        ));
      } else {
        results.add(DiagnosticItem(
          key: 'geo_assets',
          title: 'GeoIP / GeoSite 路由规则集',
          description: '规则集文件缺失，可能影响中国大陆直连与 DNS 加速',
          status: DiagnosticStatus.warn,
          detail: '可在设置页面一键下载或更新官方 SRS 规则集',
        ));
      }
    } catch (e) {
      results.add(DiagnosticItem(
        key: 'geo_assets',
        title: 'GeoIP / GeoSite 路由规则集',
        description: '规则集检查异常',
        status: DiagnosticStatus.warn,
        detail: '$e',
      ));
    }

    // 4. DNS Resolution Check
    try {
      final lookupWatch = Stopwatch()..start();
      final addresses = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 3));
      lookupWatch.stop();
      if (addresses.isNotEmpty) {
        results.add(DiagnosticItem(
          key: 'dns_lookup',
          title: '系统底层 DNS 解析',
          description: '测试对公共根域名的系统 DNS 解析响应',
          status: DiagnosticStatus.pass,
          detail: '响应正常 (${lookupWatch.elapsedMilliseconds}ms, ${addresses.first.address})',
        ));
      } else {
        results.add(DiagnosticItem(
          key: 'dns_lookup',
          title: '系统底层 DNS 解析',
          description: 'DNS 查询返回空结果',
          status: DiagnosticStatus.warn,
          detail: '未解析到有效 IP',
        ));
      }
    } catch (e) {
      results.add(DiagnosticItem(
        key: 'dns_lookup',
        title: '系统底层 DNS 解析',
        description: '域名解析超时或不可达',
        status: DiagnosticStatus.warn,
        detail: '$e',
      ));
    }

    // 5. Clash API Controller Check (if core running)
    if (isCoreRunning) {
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)));
        final res = await dio.get('http://127.0.0.1:$clashPort/version');
        if (res.statusCode == 200) {
          results.add(DiagnosticItem(
            key: 'clash_api',
            title: 'Clash API 通信控制器',
            description: '检查 UI 与 sing-box 内核之间的控制信道',
            status: DiagnosticStatus.pass,
            detail: '通信正常 (${res.data})',
          ));
        } else {
          results.add(DiagnosticItem(
            key: 'clash_api',
            title: 'Clash API 通信控制器',
            description: 'Clash 控制器返回异常 HTTP 状态',
            status: DiagnosticStatus.warn,
            detail: 'HTTP ${res.statusCode}',
          ));
        }
      } catch (e) {
        results.add(DiagnosticItem(
          key: 'clash_api',
          title: 'Clash API 通信控制器',
          description: '无法连接到 Clash API 控制端口',
          status: DiagnosticStatus.fail,
          detail: '$e',
        ));
      }
    }

    return results;
  }
}
