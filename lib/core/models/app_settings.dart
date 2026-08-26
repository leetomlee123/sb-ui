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

  const AppSettings({
    this.mixedPort = 7890,
    this.clashApiPort = 9090,
    this.clashApiSecret = '',
    this.systemProxyEnabled = true,
    this.tunModeEnabled = false,
    this.tunStack = 'system',
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
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      mixedPort: json['mixedPort'] as int? ?? 7890,
      clashApiPort: json['clashApiPort'] as int? ?? 9090,
      clashApiSecret: json['clashApiSecret'] as String? ?? '',
      systemProxyEnabled: json['systemProxyEnabled'] as bool? ?? false,
      tunModeEnabled: json['tunModeEnabled'] as bool? ?? false,
      tunStack: json['tunStack'] as String? ?? 'system',
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
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String str) =>
      AppSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
