import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class Translations {
  final String code;

  const Translations({required this.code});

  bool get isZh => code == 'zh';

  String get appTitle => isZh ? 'Singular - 奇点代理客户端' : 'Singular Desktop';
  String get minimize => isZh ? '最小化' : 'Minimize';
  String get maximize => isZh ? '最大化' : 'Maximize';
  String get restore => isZh ? '还原' : 'Restore';
  String get close => isZh ? '关闭' : 'Close';
  String get saveChanges => isZh ? '保存更改' : 'Save Changes';
  String get savedSuccess => isZh ? '设置已成功保存' : 'Settings saved successfully';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get confirm => isZh ? '确定' : 'Confirm';
  String get delete => isZh ? '删除' : 'Delete';
  String get edit => isZh ? '编辑' : 'Edit';
  String get copy => isZh ? '复制' : 'Copy';
  String get refresh => isZh ? '刷新' : 'Refresh';

  // Close confirmation dialog
  String get closeDialogTitle => isZh ? '关闭窗口选项' : 'Close Window Options';
  String get closeActionMinimize => isZh ? '最小化到系统托盘 (推荐)' : 'Minimize to System Tray (Recommended)';
  String get closeActionMinimizeDesc => isZh ? '在后台静默运行，保持网络代理与分流不中断' : 'Keep running in background without interrupting proxy';
  String get closeActionExit => isZh ? '直接退出应用程序' : 'Exit Application Completely';
  String get closeActionExitDesc => isZh ? '关闭代理核心服务并完全退出程序' : 'Stop proxy core and close application';
  String get rememberChoice => isZh ? '记住我的选择，下次不再提示' : 'Remember my choice and do not ask again';

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
  String get restartCore => isZh ? '重启核心' : 'Restart Core';
  String get restartingCore => isZh ? '正在重启核心服务...' : 'Restarting core service...';

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
  String get sortDefault => isZh ? '默认排序' : 'Default Order';
  String get sortDelayAsc => isZh ? '延迟优先' : 'Lowest Latency';
  String get sortNameAsc => isZh ? '名称排序' : 'Name (A-Z)';
  String get hideUnavailableNodes => isZh ? '隐藏不可用' : 'Hide Timeout';
  String get deleteUnavailableNodes => isZh ? '删除不可用' : 'Delete Timeout';
  String get noUnavailableNodesFound => isZh ? '当前暂无可删除的不可用节点（请先进行测速）' : 'No unavailable nodes to delete (run speed test first)';
  String deletedUnavailableNodesCount(int count) => isZh ? '已成功删除 $count 个不可用节点' : 'Successfully deleted $count unavailable nodes';
  String get quickSelectNode => isZh ? '快捷切换出口节点' : 'Quick Switch Outbound Node';
  String get nodeSwitchedTo => isZh ? '已切换出口节点: ' : 'Active node switched to: ';
  String get stopPing => isZh ? '停止测速' : 'Stop Test';
  String get testStopped => isZh ? '已停止测速' : 'Speed test stopped';

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
  String get tabLocalConfig => isZh ? '本地 config.json' : 'Local config.json';
  String get tabRawConfig => isZh ? '文本/单节点 URI' : 'Raw Config / URI';
  String get tabManualForm => isZh ? '手动配置节点' : 'Manual Form';
  String get localConfigPath => isZh ? '本地配置文件路径' : 'Config File Path';
  String get browseFile => isZh ? '浏览...' : 'Browse...';
  String get selectConfigFile => isZh ? '选择本地 config.json 或 YAML 配置文件' : 'Select local config.json or YAML file';
  String get loadTemplate => isZh ? '载入标准模板' : 'Load Standard Template';
  String get templateLoaded => isZh ? '已载入标准 sing-box config.json 模板' : 'Loaded standard sing-box template';
  String get syncWithLocalFile => isZh ? '保持本地文件联动 (文件更新时可重新载入)' : 'Sync with local file (Reloadable)';
  String get fileNotFound => isZh ? '文件不存在，请检查路径' : 'File not found, please check path';
  String get importLocalConfig => isZh ? '导入本地配置' : 'Import Local Config';
  String get formatJson => isZh ? '格式化' : 'Format';
  String get minifyJson => isZh ? '压缩' : 'Minify';
  String get findText => isZh ? '查找' : 'Find';
  String get findPrevious => isZh ? '上一个 (Shift+Enter)' : 'Previous (Shift+Enter)';
  String get findNext => isZh ? '下一个 (Enter)' : 'Next (Enter)';
  String get noMatchesFound => isZh ? '无匹配项' : 'No matches found';
  String get wordWrap => isZh ? '自动换行' : 'Word Wrap';
  String get syntaxValid => isZh ? '语法正确' : 'Valid';
  String get syntaxError => isZh ? '语法错误' : 'Syntax Error';
  String get jsonSyntaxError => isZh ? 'JSON 语法错误' : 'JSON Syntax Error';
  String get jumpToError => isZh ? '定位错误' : 'Jump to Error';
  String get configSaved => isZh ? '配置已保存' : 'Configuration saved';
  String get reloadFromFile => isZh ? '重新从本地文件载入' : 'Reload from Local File';
  String get syncToFile => isZh ? '同步写入本地文件' : 'Sync to local file';
  String get localFileBadge => isZh ? '本地文件' : 'LOCAL FILE';
  String get protocolType => isZh ? '协议类型' : 'Protocol Type';
  String get nodeName => isZh ? '节点名称' : 'Node Name';
  String get serverHost => isZh ? '服务器地址 (Host / IP)' : 'Server Host / IP';
  String get serverPort => isZh ? '端口 (Port)' : 'Port';
  String get passwordLabel => isZh ? '密码 (Password)' : 'Password';
  String get uuidLabel => isZh ? '用户 UUID' : 'User UUID';
  String get cipherLabel => isZh ? '加密方式 (Cipher)' : 'Cipher / Security';
  String get transportLabel => isZh ? '传输协议 (Transport)' : 'Transport Network';
  String get tlsLabel => isZh ? 'TLS 加密传输' : 'TLS Security';
  String get sniLabel => isZh ? 'SNI 伪装域名' : 'SNI / Server Name';
  String get allowInsecure => isZh ? '允许不安全证书 (Insecure)' : 'Allow Insecure Certificate';
  String get realityPublicKey => isZh ? 'Reality 公钥 (Public Key)' : 'Reality Public Key';
  String get realityShortId => isZh ? 'Reality Short ID' : 'Reality Short ID';
  String get flowLabel => isZh ? '流控算法 (Flow)' : 'Flow (e.g. xtls-rprx-vision)';
  String get wsPath => isZh ? 'WebSocket / HTTP 路径' : 'WebSocket / HTTP Path';
  String get wsHost => isZh ? 'Host 标头 (可选)' : 'Host Header (Optional)';
  String get grpcServiceName => isZh ? 'gRPC ServiceName' : 'gRPC Service Name';
  String get obfsPassword => isZh ? '混淆密码 (Obfs Password)' : 'Obfs Password';
  String get congestionControl => isZh ? '拥塞控制算法' : 'Congestion Control';
  String get createNodeProfile => isZh ? '创建节点配置' : 'Create Node Profile';
  String get fillRequiredFields => isZh ? '请填写必填项（节点名称、服务器地址和有效端口）' : 'Please fill all required fields (name, host, and port)';
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
  String get editPortTitle => isZh ? '修改入站监听端口' : 'Edit Inbound Port';
  String get editPortDesc => isZh ? '修改入站代理端口（HTTP / SOCKS5 混合代理）。修改后将自动重启内核服务以使新端口生效。' : 'Modify inbound proxy port (HTTP / SOCKS5). Core service will automatically restart to apply changes.';
  String get portUpdatedAndRestarted => isZh ? '端口已更新，核心已重启生效' : 'Port updated and core service restarted';

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

  // App Self-Update
  String get secAppUpdate => isZh ? '应用更新' : 'APP UPDATE';
  String get appCurrentVersion => isZh ? '当前应用版本: ' : 'Current app version: ';
  String get btnCheckAppUpdate => isZh ? '检查应用更新' : 'Check for App Updates';
  String get appNewBadge => isZh ? '发现新版本' : 'New Version Available';
  String get appUpdateNow => isZh ? '立即更新' : 'Update Now';
  String get appUpToDateMsg => isZh ? '当前已是最新版本' : 'App is up to date';
  String get autoCheckAppUpdatesTitle => isZh ? '启动时自动检查更新' : 'Check for Updates on Startup';
  String get autoCheckAppUpdatesSubtitle => isZh ? '启动后在后台静默检查 GitHub 最新 Release（不自动下载）' : 'Silently check GitHub releases in background on startup (no auto-download)';
  String get appInstallingRestartMsg => isZh ? '更新包已就绪，应用即将退出并自动安装重启...' : 'Update package ready. The app will exit, install, and relaunch...';
  String get appUpdateUnsupported => isZh ? '当前平台暂不支持应用内更新，请前往 GitHub Releases 手动下载' : 'In-app update is not supported on this platform yet. Please download from GitHub Releases manually';

  String get secGeoAssets => isZh ? 'RULE-SET 分流规则集 (SRS)' : 'RULE-SET ROUTING ASSETS (SRS)';
  String get geoAssetsDesc => isZh ? '基于 sing-box 现代统一 Rule-Set 二进制规则集架构 (.srs)，全面替代传统 geoip.db / geosite.db，支持高速 CDN 一键更新' : 'sing-box native binary Rule-Set architecture (.srs) replacing legacy geoip.db/geosite.db with CDN acceleration';
  String get updateAllGeo => isZh ? '更新全部 Rule-Set 规则集' : 'Update All Rule-Sets';
  String get updatingGeo => isZh ? '正在更新 Rule-Set 规则集...' : 'Updating Rule-Set Assets...';
  String get geoUpdatedSuccess => isZh ? 'Rule-Set 规则集已成功更新为最新版本' : 'Rule-Set assets updated successfully';
  String get lastUpdated => isZh ? '最后更新: ' : 'Last updated: ';
  String get fileSize => isZh ? '大小: ' : 'Size: ';
  String get updateSingle => isZh ? '更新' : 'Update';
  String get geoInstalled => isZh ? '已就绪' : 'Ready';
  String get autoUpdateRuleset => isZh ? '启动后自动更新规则集' : 'Auto-update Rule-Sets on Startup';
  String get autoUpdateRulesetDesc => isZh ? '每次应用启动后自动在后台从高速 CDN 获取最新的 geoip-cn.srs 与 geosite-cn.srs' : 'Automatically fetch latest geoip-cn.srs and geosite-cn.srs from CDN in the background after app starts';

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

  // Settings Tabs
  String get tabGeneral => isZh ? '常规偏好' : 'General';
  String get tabInbounds => isZh ? '网络入站' : 'Inbounds';
  String get tabDns => isZh ? 'DNS 架构' : 'DNS';
  String get tabRouting => isZh ? '分流规则' : 'Routing';
  String get tabTun => isZh ? 'TUN 核心' : 'TUN Core';
  String get tabAdvanced => isZh ? '高级实验' : 'Advanced';

  // Settings New Options
  String get fakeIpTitle => isZh ? 'Fake-IP 模式' : 'Fake-IP Mode';
  String get fakeIpDesc => isZh ? '为所有代理域名分配 198.18.x.x 虚拟 IP 地址，加速 DNS 响应并防止 DNS 污染' : 'Assign 198.18.x.x synthetic IPs to proxied domains to boost lookup speed and avoid DNS poisoning';
  String get dnsHijackTitle => isZh ? 'DNS 53 端口劫持' : 'DNS Hijack (Port 53)';
  String get dnsHijackDesc => isZh ? '强制拦截本机发出的 UDP/TCP 53 端口 DNS 请求并交由 sing-box 智能调度' : 'Intercept local port 53 DNS queries and route via sing-box DNS engine';
  String get dnsStrategyTitle => isZh ? 'DNS 域名解析策略' : 'DNS Resolution Strategy';
  String get separateInboundTitle => isZh ? '分离 HTTP / SOCKS5 端口' : 'Separate HTTP / SOCKS5 Ports';
  String get separateInboundDesc => isZh ? '分别监听独立的 HTTP 代理端口与 SOCKS5 代理端口' : 'Listen on dedicated ports for HTTP proxy and SOCKS5 proxy individually';
  String get httpPortLabel => isZh ? 'HTTP 代理端口' : 'HTTP Proxy Port';
  String get socksPortLabel => isZh ? 'SOCKS5 代理端口' : 'SOCKS5 Proxy Port';
  String get blockAdsTitle => isZh ? '拦截广告与跟踪器 (AdBlock)' : 'Block Advertisements & Trackers';
  String get blockAdsDesc => isZh ? '基于内置广告域名规则库直接拦截各类常见弹窗广告与追踪 SDK' : 'Automatically drop traffic to common advertisement and telemetry domains';
  String get aiServicesTitle => isZh ? 'AI 平台分流 (OpenAI / Claude / Gemini)' : 'AI Platforms Routing (OpenAI / Claude / Gemini)';
  String get streamMediaTitle => isZh ? '国际流媒体分流 (YouTube / Netflix / Disney+)' : 'Streaming Media Routing (YouTube / Netflix / Disney+)';
  String get routeProxy => isZh ? '节点代理 (Proxy)' : 'Proxy Outbound';
  String get routeDirect => isZh ? '国内直连 (Direct)' : 'Direct Outbound';
  String get tunGsoTitle => isZh ? 'TUN GSO 硬件分段卸载加速' : 'TUN Generic Segmentation Offload (GSO)';
  String get tunGsoDesc => isZh ? '利用网卡硬件分段加速，显著提升大流量吞吐性能并降低 CPU 占用' : 'Leverage hardware segmentation offload to increase throughput and reduce CPU overhead';
  String get tunIpv6Title => isZh ? 'TUN IPv6 虚拟网卡支持' : 'TUN IPv6 Virtual Stack';
  String get tunIpv6Desc => isZh ? '默认禁用 IPv6 可彻底避免因宽带 IPv6 旁路导致的真实 IP 泄露' : 'Disabled by default to prevent IP leaks via direct IPv6 bypass routes';
  String get tunStrictRouteTitle => isZh ? '严格路由 (Strict Route)' : 'Strict Route';
  String get tunStrictRouteDesc => isZh ? '强制所有网络流量必须经过 TUN 虚拟网卡，杜绝 WebRTC 等旁路泄露' : 'Prevent direct traffic bypass via alternative interfaces or WebRTC';
  String get sniffingTitle => isZh ? '协议嗅探 (Protocol Sniffing)' : 'Protocol Sniffing (TLS / HTTP / QUIC)';
  String get sniffingDesc => isZh ? '从连接握手报文中自动识别真实访问域名（如 TLS SNI、HTTP Host、QUIC）' : 'Extract target hostname from TLS SNI, HTTP Host, or QUIC handshake packets';
  String get sniffOverrideTitle => isZh ? '嗅探域名覆写 (Override Destination)' : 'Override Destination by Sniffed Domain';
  String get sniffOverrideDesc => isZh ? '使用嗅探提取到的真实域名替换目标 IP，解决纯 IP 请求的精准分流' : 'Replace destination IP with sniffed domain for accurate routing rules matching';
  String get tcpFastOpenTitle => isZh ? 'TCP Fast Open (TFO)' : 'TCP Fast Open (TFO)';
  String get tcpFastOpenDesc => isZh ? '在 TCP 三次握手 SYN 包中附带数据，减少连接 RTT 延迟' : 'Send data in TCP SYN packet to eliminate one round-trip time';
  String get multiplexTitle => isZh ? 'Multiplex 连接多路复用' : 'Multiplex Connection Sharing';
  String get multiplexDesc => isZh ? '在单条 TCP/TLS 连接中复用多个数据流，降低频繁握手延迟并改善并发' : 'Multiplex multiple concurrent streams over a single TCP/TLS connection';
  String get btnPreviewConfig => isZh ? '预览实时 Config.json' : 'Preview Live Config.json';
  String get previewConfigTitle => isZh ? '当前生成的 sing-box 运行时配置' : 'Generated sing-box Runtime Config';

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
