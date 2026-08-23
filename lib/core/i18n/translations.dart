import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class Translations {
  final String code;

  const Translations({required this.code});

  bool get isZh => code == 'zh';

  // Title bar & General
  String get appTitle => isZh ? 'sing-box 客户端' : 'sing-box Desktop';
  String get minimize => isZh ? '最小化' : 'Minimize';
  String get maximize => isZh ? '最大化' : 'Maximize';
  String get close => isZh ? '关闭' : 'Close';
  String get saveChanges => isZh ? '保存更改' : 'Save Changes';
  String get savedSuccess => isZh ? '设置已成功保存' : 'Settings saved successfully';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get delete => isZh ? '删除' : 'Delete';
  String get edit => isZh ? '编辑' : 'Edit';
  String get copy => isZh ? '复制' : 'Copy';
  String get refresh => isZh ? '刷新' : 'Refresh';

  // Navigation Rail
  String get navDashboard => isZh ? '仪表盘' : 'Dashboard';
  String get navProxies => isZh ? '节点选择' : 'Proxies';
  String get navProfiles => isZh ? '配置订阅' : 'Profiles';
  String get navConnections => isZh ? '活动连接' : 'Sessions';
  String get navLogs => isZh ? '运行日志' : 'Logs';
  String get navSettings => isZh ? '设置' : 'Settings';

  // Bottom Status Ribbon
  String get noActiveProfile => isZh ? '未选择活动配置' : 'No Active Profile';
  String get running => isZh ? '运行中' : 'Running';
  String get starting => isZh ? '启动中' : 'Starting';
  String get stopped => isZh ? '已停止' : 'Stopped';
  String get error => isZh ? '异常' : 'Error';

  // Dashboard Page
  String get connected => isZh ? '已连接' : 'CONNECTED';
  String get disconnected => isZh ? '未连接' : 'DISCONNECTED';
  String get clickToConnect => isZh ? '点击电源按钮启动 sing-box' : 'Click the power button to start sing-box';
  String get uptime => isZh ? '已运行' : 'Uptime';
  String get standby => isZh ? '待机模式' : 'Standby mode';
  String get routingPolicy => isZh ? '分流策略' : 'ROUTING POLICY';
  String get modeRule => isZh ? '规则分流' : 'Rule';
  String get modeGlobal => isZh ? '全局代理' : 'Global';
  String get modeDirect => isZh ? '直连模式' : 'Direct';
  String get tunMode => isZh ? 'TUN 虚拟网卡' : 'TUN Mode';
  String get systemProxy => isZh ? '系统代理' : 'System Proxy';
  String get downloadSpeed => isZh ? '下载速率' : 'DOWNLOAD';
  String get uploadSpeed => isZh ? '上传速率' : 'UPLOAD';
  String get totalDownload => isZh ? '总下载' : 'Total Down';
  String get totalUpload => isZh ? '总上传' : 'Total Up';
  String get activeOutbound => isZh ? '当前出口节点' : 'ACTIVE OUTBOUND';
  String get notConnected => isZh ? '未建立连接' : 'Not Connected';
  String get telemetryStream => isZh ? '实时流量波形' : 'TELEMETRY STREAM';
  String get live => isZh ? '实时' : 'LIVE';
  String get telemetryEmptyHint => isZh ? '建立网络连接后将自动呈现实时流量走势图' : 'Telemetry data will populate when connection is established';
  String get dashboardDisplay => isZh ? '仪表盘模块展示' : 'DASHBOARD DISPLAY';
  String get optShowSpeedMetricsTitle => isZh ? '显示速率与流量统计卡片' : 'Speed & Traffic Metrics Bento';
  String get optShowSpeedMetricsSubtitle => isZh ? '在首页展示下载/上传实时速率及本次会话累计流量卡片' : 'Display download/upload speeds and session traffic cards on Dashboard';
  String get optShowTelemetryChartTitle => isZh ? '显示实时流量波形图表' : 'Live Traffic Waveform Graph';
  String get optShowTelemetryChartSubtitle => isZh ? '在首页渲染 90 秒实时流量折线波动图（关闭可进一步降低待机负载）' : 'Render 90s live traffic line graph (disable to minimize CPU load)';

  // Proxies Page
  String get coreOfflineTitle => isZh ? 'sing-box 核心未运行' : 'sing-box Core is Offline';
  String get coreOfflineHint => isZh ? '请在仪表盘启动连接后管理节点并测速' : 'Start connection on Dashboard to manage proxies and test latency';
  String get filterNodes => isZh ? '搜索过滤节点...' : 'Filter nodes...';
  String get pingAll => isZh ? '一键测速' : 'Ping All';
  String get noNodesFound => isZh ? '未找到符合条件的节点' : 'No proxy nodes found';
  String get pinging => isZh ? '测速中...' : 'pinging...';
  String get timeout => isZh ? '超时' : 'Timeout';

  // Profiles Page
  String get subAndProfiles => isZh ? '配置与订阅管理' : 'SUBSCRIPTIONS & PROFILES';
  String get subDesc => isZh ? '管理远程订阅链接与本地 sing-box JSON 规则' : 'Manage remote subscription sources and local sing-box JSON schemas';
  String get addProfile => isZh ? '添加配置' : 'Add Profile';
  String get noProfilesTitle => isZh ? '暂无配置文件' : 'No Profiles Configured';
  String get noProfilesHint => isZh ? '导入订阅链接或本地配置以开启智能代理' : 'Import a subscription link or local config to begin routing';
  String get importSubscription => isZh ? '导入订阅' : 'Import Subscription';
  String get useProfile => isZh ? '启用' : 'Use';
  String get activeBadge => isZh ? '生效中' : 'ACTIVE';
  String get updateSub => isZh ? '更新订阅' : 'Update Subscription';
  String get editConfig => isZh ? '编辑配置' : 'Edit Config';
  String get deleteProfile => isZh ? '删除配置' : 'Delete Profile';
  String get confirmDelete => isZh ? '确认删除此配置文件吗？' : 'Are you sure you want to delete this profile?';
  String get trafficUsage => isZh ? '套餐流量使用' : 'TRAFFIC USAGE';
  String get nodesCount => isZh ? '个节点' : 'nodes';
  String get updatedPrefix => isZh ? '更新于: ' : 'Updated: ';
  String get expiresPrefix => isZh ? '到期: ' : 'Expires: ';
  String get tabRemoteUrl => isZh ? '远程订阅链接' : 'Remote URL';
  String get tabRawConfig => isZh ? '文本/单节点 URI' : 'Raw Config / URI';
  String get profileAlias => isZh ? '配置别名' : 'Profile Alias';
  String get subUrl => isZh ? '订阅链接 URL' : 'Subscription URL';
  String get configPayload => isZh ? '配置文本' : 'Configuration Payload';
  String get configPayloadHint => isZh ? '支持粘贴 sing-box JSON、Clash YAML 或 ss/vmess/vless/trojan/hy2 节点链接' : 'Paste sing-box JSON, Clash YAML, or Shadowsocks/Vmess/Vless/Trojan/Hy2 URLs';
  String get downloadSubFailed => isZh ? '下载订阅链接失败，请检查网络或链接有效性' : 'Failed to download subscription URL';
  String get copySubUrl => isZh ? '复制订阅链接' : 'Copy Subscription URL';
  String get copyConfigPayload => isZh ? '复制配置文本' : 'Copy Config Payload';
  String get copiedSubSuccess => isZh ? '订阅链接已成功复制到剪贴板' : 'Subscription URL copied to clipboard';

  // Connections & Analytics Page
  String get activeConnections => isZh ? '实时连接与流量分析' : 'CONNECTIONS & TRAFFIC ANALYTICS';
  String get trackingSessions => isZh ? '当前正在追踪' : 'Tracking';
  String get sessionsSuffix => isZh ? '个网络会话' : 'live sessions';
  String get searchConnections => isZh ? '搜索域名、IP 或规则...' : 'Search host, IP, or rule...';
  String get closeAll => isZh ? '关闭全部' : 'Close All';
  String get noConnectionsMatching => isZh ? '暂无匹配的活动网络连接' : 'No active connections matching filter';
  String get rulePrefix => isZh ? '命中规则: ' : 'Rule: ';
  String get routePrefix => isZh ? '路由链: ' : 'Route: ';
  String get killSession => isZh ? '切断连接' : 'Kill Connection';
  String get totalTraffic => isZh ? '总计消耗流量' : 'Total Combined Traffic';
  String get totalTrafficStats => isZh ? '流量总计与统计' : 'Total Traffic Statistics';
  String get trafficAnalytics => isZh ? '流量深度分析' : 'Traffic Analytics';
  String get domainRanking => isZh ? '域名访问流量排行榜 (Top 10)' : 'Top Domains by Traffic (Top 10)';
  String get outboundDistribution => isZh ? '出口节点流量分布' : 'Outbound Traffic Share';
  String get protocolDistribution => isZh ? '网络协议分布' : 'Protocol Breakdown';
  String get connectionsTab => isZh ? '实时连接' : 'Active Connections';
  String get analyticsTab => isZh ? '流量分析' : 'Traffic Analytics';
  String get noTrafficData => isZh ? '暂无流量统计数据' : 'No traffic data available';

  // Logs Page
  String get logStream => isZh ? '核心诊断日志' : 'SYSTEM LOG STREAM';
  String get logStreamDesc => isZh ? '实时内核运行状态与 WebSocket 诊断流' : 'Real-time core diagnostics and WebSocket log pipeline';
  String get levelPrefix => isZh ? '日志级别: ' : 'Level: ';
  String get searchLogs => isZh ? '过滤日志关键字...' : 'Search logs...';
  String get pauseLogs => isZh ? '暂停刷新' : 'Pause logs';
  String get resumeLogs => isZh ? '恢复实时流' : 'Resume live update';
  String get copyAll => isZh ? '复制全部日志' : 'Copy all to clipboard';
  String get logsCopied => isZh ? '日志内容已复制到剪贴板' : 'Logs copied to clipboard';
  String get clearLogs => isZh ? '清空控制台' : 'Clear logs';
  String get noLogsYet => isZh ? '暂无捕获的核心日志事件' : 'No core log events captured yet';

  // Settings Page
  String get settingsHeader => isZh ? '应用偏好与核心设置' : 'CONFIGURATION & PREFERENCES';
  String get settingsHeaderDesc => isZh ? '配置网络入站端口、加密 DNS 解析器与系统环境行为' : 'Customize network inbounds, DNS resolvers, and desktop behavioral parameters';
  String get secRouting => isZh ? '路由模式与网络适配' : 'ROUTING & NETWORK ADAPTERS';
  String get secPorts => isZh ? '入站端口与 CONTROLLER API' : 'INBOUND PORTS & CONTROLLER API';
  String get secDns => isZh ? '加密 DNS 与本地解析器' : 'ENCRYPTED & LOCAL DNS RESOLVERS';
  String get secBinary => isZh ? 'SING-BOX 内核程序' : 'SING-BOX CORE EXECUTABLE';
  String get secDesktop => isZh ? '桌面偏好与语言外观' : 'DESKTOP ENVIRONMENT PREFERENCES';

  String get optSysProxyTitle => isZh ? '系统代理' : 'System Proxy';
  String get optSysProxySubtitle => isZh ? '自动修改操作系统网络设置以使用 HTTP/SOCKS 代理' : 'Automatically configure OS HTTP/SOCKS system proxy endpoints';
  String get optTunTitle => isZh ? 'TUN 虚拟网卡接管' : 'TUN Virtual Adapter Mode';
  String get optTunSubtitle => isZh ? '通过虚拟网卡接管全局所有进程网络流量（需管理员权限）' : 'Route all system IP packets through transparent TUN virtual interface';
  String get optLanTitle => isZh ? '允许局域网设备连接 (LAN)' : 'Allow Local Network Access (LAN)';
  String get optLanSubtitle => isZh ? '将入站代理绑定至 0.0.0.0 允许局域网其它设备接入' : 'Bind inbound mixed proxy to 0.0.0.0 allowing LAN devices to connect';

  String get mixedPortLabel => isZh ? '混合代理入站端口 (HTTP / SOCKS5)' : 'Mixed Inbound Port (HTTP / SOCKS5)';
  String get clashPortLabel => isZh ? 'Clash API 控制器端口' : 'Clash API External Controller Port';
  String get clashSecretLabel => isZh ? 'Clash API 认证密钥 (可选)' : 'Clash API Authorization Secret (Optional)';
  String get clashSecretHint => isZh ? '留空则无需认证 Token' : 'Leave empty for no authentication token';

  String get remoteDnsLabel => isZh ? '远程防污染 DNS (DoH / HTTPS / DoT)' : 'Remote DNS (DoH / DoT / HTTPS / UDP)';
  String get directDnsLabel => isZh ? '国内直连 DNS 解析器' : 'Direct / Domestic DNS';

  String get customBinaryLabel => isZh ? '自定义 sing-box 内核路径 (可选)' : 'Custom Core Binary Path (Optional)';
  String get customBinaryHint => isZh ? '默认自动从 PATH 环境变量或程序内置目录加载' : 'Auto-detected from PATH or bundled sidecar';
  String get testCore => isZh ? '检测内核' : 'Test Core';
  String get detectedCore => isZh ? '已检测到内核: ' : 'Detected Core: ';
  String get btnCheckUpdate => isZh ? '检查内核更新' : 'Check for Updates';
  String get btnUpdateNow => isZh ? '立即升级' : 'Update Now';
  String get updatingStatus => isZh ? '正在升级内核...' : 'Updating Core...';
  String get coreLatestBadge => isZh ? '最新版' : 'Latest';
  String get coreNewBadge => isZh ? '有新版本' : 'New Version';
  String get releaseNotesLabel => isZh ? '版本更新说明' : 'Release Notes';

  String get secGeoAssets => isZh ? 'GEO 规则与分流数据库' : 'GEO ASSETS & ROUTING DATABASES';
  String get geoAssetsDesc => isZh ? '维护本地离线 GeoIP 与 GeoSite 二进制分流规则库，支持高速 CDN 一键更新' : 'Manage and update offline GeoIP & GeoSite binary routing datasets';
  String get updateAllGeo => isZh ? '更新全部 Geo 规则' : 'Update All Geo Assets';
  String get updatingGeo => isZh ? '正在更新 Geo 规则库...' : 'Updating Geo Assets...';
  String get geoUpdatedSuccess => isZh ? 'Geo 规则库已成功更新为最新版本' : 'Geo assets updated successfully';
  String get lastUpdated => isZh ? '最后更新: ' : 'Last updated: ';
  String get fileSize => isZh ? '大小: ' : 'Size: ';
  String get updateSingle => isZh ? '更新' : 'Update';
  String get geoInstalled => isZh ? '已就绪' : 'Ready';

  String get autoStartTitle => isZh ? '开机自启动' : 'Launch at System Startup';
  String get autoStartSubtitle => isZh ? '系统登录后自动在后台启动应用并准备代理' : 'Automatically launch application on system startup';
  String get startMinimizedTitle => isZh ? '静默启动至托盘' : 'Start Minimized to Tray';
  String get startMinimizedSubtitle => isZh ? '启动时不弹出主窗口，仅驻留系统托盘' : 'Start in background without opening main window';
  String get closeToTrayTitle => isZh ? '关闭窗口时最小化到系统托盘' : 'Minimize to System Tray on Close';
  String get closeToTraySubtitle => isZh ? '点击右上角 X 时将程序隐藏至后台托盘继续保持代理' : 'Keep core active in background when clicking window close button';
  String get themeTitle => isZh ? '界面主题模式' : 'Application Color Theme';
  String get languageTitle => isZh ? '界面语言 / Language' : 'Application Language';
  String get langZh => '简体中文';
  String get langEn => 'English';

  // Tray Menu
  String get trayOpen => isZh ? '打开主面板' : 'Open Dashboard';
  String get trayToggle => isZh ? '开关网络连接' : 'Toggle Connection';
  String get trayQuit => isZh ? '彻底退出' : 'Quit';
}

final translationsProvider = Provider<Translations>((ref) {
  final settings = ref.watch(settingsProvider);
  String lang = settings.language;
  if (lang == 'system') {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang = systemLocale == 'zh' ? 'zh' : 'en';
  }
  return Translations(code: lang);
});
