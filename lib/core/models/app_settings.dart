import 'dart:convert';

enum RoutingMode {
  rule,
  global,
  direct;

  String get displayName {
    switch (this) {
      case RoutingMode.rule:
        return 'Rule';
      case RoutingMode.global:
        return 'Global';
      case RoutingMode.direct:
        return 'Direct';
    }
  }
}

class AppSettings {
  final int mixedPort;
  final int clashApiPort;
  final String clashApiSecret;
  final bool systemProxyEnabled;
  final bool tunModeEnabled;
  final String tunStack; // 'mixed', 'system', 'gvisor'
  final String logLevel; // 'trace', 'debug', 'info', 'warn', 'error'
  final RoutingMode routingMode;
  final bool autoStart;
  final bool startMinimized;
  final bool closeToTray;
  final bool hasAskedCloseToTray; // Whether the user has made a permanent close action choice
  final String themeMode; // 'dark', 'light', 'system'
  final String language; // 'zh', 'en', 'system'
  final String customSingboxPath;
  final String remoteDns;
  final String directDns;
  final bool allowLan;
  final String selectedProxyNode; // persisted user choice for primary selector
  final bool showSpeedMetrics; // Dashboard: toggle speed metrics bento strip
  final bool showTelemetryChart; // Dashboard: toggle live traffic waveform chart
  final bool autoCheckAppUpdates; // Settings: silent update check on startup
  final bool autoUpdateRuleset; // Settings: silent ruleset auto-update on startup

  // DNS Advanced
  final bool fakeIpEnabled;
  final String fakeIpRange;
  final bool dnsHijack;
  final String dnsStrategy; // 'prefer_ipv4', 'prefer_ipv6', 'ipv4_only', 'ipv6_only'

  // Inbounds
  final bool separateInboundPorts;
  final int httpPort;
  final int socksPort;

  // Routing & Scenario Rules
  final bool blockAds;
  final String aiServicesRoute; // 'proxy', 'direct'
  final String streamMediaRoute; // 'proxy', 'direct'

  // TUN & Kernel
  final bool tunGso;
  final bool tunIpv6;
  final int tunMtu;
  final bool tunStrictRoute;

  // Sniffing & Advanced
  final bool sniffingEnabled;
  final bool sniffingOverrideDestination;
  final bool tcpFastOpen;
  final String multiplex; // 'none', 'smux', 'yamux', 'h2mux'

  const AppSettings({
    this.mixedPort = 7890,
    this.clashApiPort = 9090,
    this.clashApiSecret = '',
    this.systemProxyEnabled = true,
    this.tunModeEnabled = false,
    this.tunStack = 'mixed',
    this.logLevel = 'info',
    this.routingMode = RoutingMode.rule,
    this.autoStart = false,
    this.startMinimized = false,
    this.closeToTray = true,
    this.hasAskedCloseToTray = false,
    this.themeMode = 'light',
    this.language = 'zh',
    this.customSingboxPath = '',
    this.remoteDns = 'https://1.1.1.1/dns-query',
    this.directDns = '223.5.5.5',
    this.allowLan = false,
    this.selectedProxyNode = '',
    this.showSpeedMetrics = true,
    this.showTelemetryChart = true,
    this.autoCheckAppUpdates = true,
    this.autoUpdateRuleset = true,
    // DNS Advanced
    this.fakeIpEnabled = false,
    this.fakeIpRange = '198.18.0.0/15',
    this.dnsHijack = true,
    this.dnsStrategy = 'prefer_ipv4',
    // Inbounds
    this.separateInboundPorts = false,
    this.httpPort = 7890,
    this.socksPort = 7891,
    // Routing & Rules
    this.blockAds = false,
    this.aiServicesRoute = 'proxy',
    this.streamMediaRoute = 'proxy',
    // TUN
    this.tunGso = false,
    this.tunIpv6 = false,
    this.tunMtu = 9000,
    this.tunStrictRoute = true,
    // Sniffing & Advanced
    this.sniffingEnabled = true,
    this.sniffingOverrideDestination = true,
    this.tcpFastOpen = false,
    this.multiplex = 'none',
  });

  Map<String, dynamic> toJson() {
    return {
      'mixedPort': mixedPort,
      'clashApiPort': clashApiPort,
      'clashApiSecret': clashApiSecret,
      'systemProxyEnabled': systemProxyEnabled,
      'tunModeEnabled': tunModeEnabled,
      'tunStack': tunStack,
      'logLevel': logLevel,
      'routingMode': routingMode.name,
      'autoStart': autoStart,
      'startMinimized': startMinimized,
      'closeToTray': closeToTray,
      'hasAskedCloseToTray': hasAskedCloseToTray,
      'themeMode': themeMode,
      'language': language,
      'customSingboxPath': customSingboxPath,
      'remoteDns': remoteDns,
      'directDns': directDns,
      'allowLan': allowLan,
      'selectedProxyNode': selectedProxyNode,
      'showSpeedMetrics': showSpeedMetrics,
      'showTelemetryChart': showTelemetryChart,
      'autoCheckAppUpdates': autoCheckAppUpdates,
      'autoUpdateRuleset': autoUpdateRuleset,
      // DNS Advanced
      'fakeIpEnabled': fakeIpEnabled,
      'fakeIpRange': fakeIpRange,
      'dnsHijack': dnsHijack,
      'dnsStrategy': dnsStrategy,
      // Inbounds
      'separateInboundPorts': separateInboundPorts,
      'httpPort': httpPort,
      'socksPort': socksPort,
      // Routing & Rules
      'blockAds': blockAds,
      'aiServicesRoute': aiServicesRoute,
      'streamMediaRoute': streamMediaRoute,
      // TUN
      'tunGso': tunGso,
      'tunIpv6': tunIpv6,
      'tunMtu': tunMtu,
      'tunStrictRoute': tunStrictRoute,
      // Sniffing & Advanced
      'sniffingEnabled': sniffingEnabled,
      'sniffingOverrideDestination': sniffingOverrideDestination,
      'tcpFastOpen': tcpFastOpen,
      'multiplex': multiplex,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      mixedPort: json['mixedPort'] as int? ?? 7890,
      clashApiPort: json['clashApiPort'] as int? ?? 9090,
      clashApiSecret: json['clashApiSecret'] as String? ?? '',
      systemProxyEnabled: json['systemProxyEnabled'] as bool? ?? false,
      tunModeEnabled: json['tunModeEnabled'] as bool? ?? false,
      tunStack: (json['tunStack'] == 'system' || json['tunStack'] == null) ? 'mixed' : json['tunStack'] as String,
      logLevel: json['logLevel'] as String? ?? 'info',
      routingMode: RoutingMode.values.firstWhere(
        (e) => e.name == json['routingMode'],
        orElse: () => RoutingMode.rule,
      ),
      autoStart: json['autoStart'] as bool? ?? false,
      startMinimized: json['startMinimized'] as bool? ?? false,
      closeToTray: json['closeToTray'] as bool? ?? true,
      hasAskedCloseToTray: json['hasAskedCloseToTray'] as bool? ?? false,
      themeMode: json['themeMode'] as String? ?? 'light',
      language: json['language'] as String? ?? 'zh',
      customSingboxPath: json['customSingboxPath'] as String? ?? '',
      remoteDns: json['remoteDns'] as String? ?? 'https://1.1.1.1/dns-query',
      directDns: json['directDns'] as String? ?? '223.5.5.5',
      allowLan: json['allowLan'] as bool? ?? false,
      selectedProxyNode: json['selectedProxyNode'] as String? ?? '',
      showSpeedMetrics: json['showSpeedMetrics'] as bool? ?? true,
      showTelemetryChart: json['showTelemetryChart'] as bool? ?? true,
      autoCheckAppUpdates: json['autoCheckAppUpdates'] as bool? ?? true,
      autoUpdateRuleset: json['autoUpdateRuleset'] as bool? ?? true,
      // DNS Advanced
      fakeIpEnabled: json['fakeIpEnabled'] as bool? ?? false,
      fakeIpRange: json['fakeIpRange'] as String? ?? '198.18.0.0/15',
      dnsHijack: json['dnsHijack'] as bool? ?? true,
      dnsStrategy: json['dnsStrategy'] as String? ?? 'prefer_ipv4',
      // Inbounds
      separateInboundPorts: json['separateInboundPorts'] as bool? ?? false,
      httpPort: json['httpPort'] as int? ?? 7890,
      socksPort: json['socksPort'] as int? ?? 7891,
      // Routing & Rules
      blockAds: json['blockAds'] as bool? ?? false,
      aiServicesRoute: json['aiServicesRoute'] as String? ?? 'proxy',
      streamMediaRoute: json['streamMediaRoute'] as String? ?? 'proxy',
      // TUN
      tunGso: json['tunGso'] as bool? ?? false,
      tunIpv6: json['tunIpv6'] as bool? ?? false,
      tunMtu: json['tunMtu'] as int? ?? 9000,
      tunStrictRoute: json['tunStrictRoute'] as bool? ?? true,
      // Sniffing & Advanced
      sniffingEnabled: json['sniffingEnabled'] as bool? ?? true,
      sniffingOverrideDestination: json['sniffingOverrideDestination'] as bool? ?? true,
      tcpFastOpen: json['tcpFastOpen'] as bool? ?? false,
      multiplex: json['multiplex'] as String? ?? 'none',
    );
  }

  AppSettings copyWith({
    int? mixedPort,
    int? clashApiPort,
    String? clashApiSecret,
    bool? systemProxyEnabled,
    bool? tunModeEnabled,
    String? tunStack,
    String? logLevel,
    RoutingMode? routingMode,
    bool? autoStart,
    bool? startMinimized,
    bool? closeToTray,
    bool? hasAskedCloseToTray,
    String? themeMode,
    String? language,
    String? customSingboxPath,
    String? remoteDns,
    String? directDns,
    bool? allowLan,
    String? selectedProxyNode,
    bool? showSpeedMetrics,
    bool? showTelemetryChart,
    bool? autoCheckAppUpdates,
    bool? autoUpdateRuleset,
    // DNS Advanced
    bool? fakeIpEnabled,
    String? fakeIpRange,
    bool? dnsHijack,
    String? dnsStrategy,
    // Inbounds
    bool? separateInboundPorts,
    int? httpPort,
    int? socksPort,
    // Routing & Rules
    bool? blockAds,
    String? aiServicesRoute,
    String? streamMediaRoute,
    // TUN
    bool? tunGso,
    bool? tunIpv6,
    int? tunMtu,
    bool? tunStrictRoute,
    // Sniffing & Advanced
    bool? sniffingEnabled,
    bool? sniffingOverrideDestination,
    bool? tcpFastOpen,
    String? multiplex,
  }) {
    return AppSettings(
      mixedPort: mixedPort ?? this.mixedPort,
      clashApiPort: clashApiPort ?? this.clashApiPort,
      clashApiSecret: clashApiSecret ?? this.clashApiSecret,
      systemProxyEnabled: systemProxyEnabled ?? this.systemProxyEnabled,
      tunModeEnabled: tunModeEnabled ?? this.tunModeEnabled,
      tunStack: tunStack ?? this.tunStack,
      logLevel: logLevel ?? this.logLevel,
      routingMode: routingMode ?? this.routingMode,
      autoStart: autoStart ?? this.autoStart,
      startMinimized: startMinimized ?? this.startMinimized,
      closeToTray: closeToTray ?? this.closeToTray,
      hasAskedCloseToTray: hasAskedCloseToTray ?? this.hasAskedCloseToTray,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      customSingboxPath: customSingboxPath ?? this.customSingboxPath,
      remoteDns: remoteDns ?? this.remoteDns,
      directDns: directDns ?? this.directDns,
      allowLan: allowLan ?? this.allowLan,
      selectedProxyNode: selectedProxyNode ?? this.selectedProxyNode,
      showSpeedMetrics: showSpeedMetrics ?? this.showSpeedMetrics,
      showTelemetryChart: showTelemetryChart ?? this.showTelemetryChart,
      autoCheckAppUpdates: autoCheckAppUpdates ?? this.autoCheckAppUpdates,
      autoUpdateRuleset: autoUpdateRuleset ?? this.autoUpdateRuleset,
      // DNS Advanced
      fakeIpEnabled: fakeIpEnabled ?? this.fakeIpEnabled,
      fakeIpRange: fakeIpRange ?? this.fakeIpRange,
      dnsHijack: dnsHijack ?? this.dnsHijack,
      dnsStrategy: dnsStrategy ?? this.dnsStrategy,
      // Inbounds
      separateInboundPorts: separateInboundPorts ?? this.separateInboundPorts,
      httpPort: httpPort ?? this.httpPort,
      socksPort: socksPort ?? this.socksPort,
      // Routing & Rules
      blockAds: blockAds ?? this.blockAds,
      aiServicesRoute: aiServicesRoute ?? this.aiServicesRoute,
      streamMediaRoute: streamMediaRoute ?? this.streamMediaRoute,
      // TUN
      tunGso: tunGso ?? this.tunGso,
      tunIpv6: tunIpv6 ?? this.tunIpv6,
      tunMtu: tunMtu ?? this.tunMtu,
      tunStrictRoute: tunStrictRoute ?? this.tunStrictRoute,
      // Sniffing & Advanced
      sniffingEnabled: sniffingEnabled ?? this.sniffingEnabled,
      sniffingOverrideDestination: sniffingOverrideDestination ?? this.sniffingOverrideDestination,
      tcpFastOpen: tcpFastOpen ?? this.tcpFastOpen,
      multiplex: multiplex ?? this.multiplex,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String str) =>
      AppSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
