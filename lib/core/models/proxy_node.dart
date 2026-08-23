enum OutboundType {
  shadowsocks,
  vmess,
  vless,
  trojan,
  hysteria2,
  tuic,
  wireguard,
  direct,
  block,
  dns,
  selector,
  urltest,
  fallback,
  loadbalance,
  unknown;

  static OutboundType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'shadowsocks':
      case 'ss':
        return OutboundType.shadowsocks;
      case 'vmess':
        return OutboundType.vmess;
      case 'vless':
        return OutboundType.vless;
      case 'trojan':
        return OutboundType.trojan;
      case 'hysteria2':
      case 'hy2':
        return OutboundType.hysteria2;
      case 'tuic':
        return OutboundType.tuic;
      case 'wireguard':
      case 'wg':
        return OutboundType.wireguard;
      case 'direct':
        return OutboundType.direct;
      case 'block':
        return OutboundType.block;
      case 'dns':
        return OutboundType.dns;
      case 'selector':
        return OutboundType.selector;
      case 'urltest':
      case 'url-test':
        return OutboundType.urltest;
      case 'fallback':
        return OutboundType.fallback;
      case 'loadbalance':
      case 'load-balance':
        return OutboundType.loadbalance;
      default:
        return OutboundType.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case OutboundType.shadowsocks:
        return 'Shadowsocks';
      case OutboundType.vmess:
        return 'VMess';
      case OutboundType.vless:
        return 'VLESS';
      case OutboundType.trojan:
        return 'Trojan';
      case OutboundType.hysteria2:
        return 'Hysteria 2';
      case OutboundType.tuic:
        return 'TUIC';
      case OutboundType.wireguard:
        return 'WireGuard';
      case OutboundType.direct:
        return 'Direct';
      case OutboundType.block:
        return 'Block';
      case OutboundType.dns:
        return 'DNS';
      case OutboundType.selector:
        return 'Selector';
      case OutboundType.urltest:
        return 'URL-Test';
      case OutboundType.fallback:
        return 'Fallback';
      case OutboundType.loadbalance:
        return 'Load-Balance';
      case OutboundType.unknown:
        return 'Proxy';
    }
  }
}

class ProxyNode {
  final String name;
  final OutboundType type;
  final String? server;
  final int? port;
  final bool udp;
  int? delay; // in milliseconds
  bool isTesting;
  final Map<String, dynamic> raw;

  ProxyNode({
    required this.name,
    required this.type,
    this.server,
    this.port,
    this.udp = true,
    this.delay,
    this.isTesting = false,
    this.raw = const {},
  });

  factory ProxyNode.fromClashApi(String name, Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final history = json['history'] as List<dynamic>?;
    int? latestDelay;
    if (history != null && history.isNotEmpty) {
      final last = history.last as Map<String, dynamic>;
      latestDelay = last['delay'] as int?;
    }

    return ProxyNode(
      name: name,
      type: OutboundType.fromString(typeStr),
      server: json['server'] as String?,
      port: json['port'] as int?,
      udp: json['udp'] as bool? ?? true,
      delay: latestDelay ?? json['delay'] as int?,
      raw: json,
    );
  }

  ProxyNode copyWith({
    String? name,
    OutboundType? type,
    String? server,
    int? port,
    bool? udp,
    int? delay,
    bool? isTesting,
    Map<String, dynamic>? raw,
  }) {
    return ProxyNode(
      name: name ?? this.name,
      type: type ?? this.type,
      server: server ?? this.server,
      port: port ?? this.port,
      udp: udp ?? this.udp,
      delay: delay ?? this.delay,
      isTesting: isTesting ?? this.isTesting,
      raw: raw ?? this.raw,
    );
  }
}

class ProxyGroup {
  final String name;
  final OutboundType type;
  final String current;
  final List<String> all;
  final Map<String, dynamic> raw;

  ProxyGroup({
    required this.name,
    required this.type,
    required this.current,
    required this.all,
    this.raw = const {},
  });

  factory ProxyGroup.fromClashApi(String name, Map<String, dynamic> json) {
    final allList = (json['all'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return ProxyGroup(
      name: name,
      type: OutboundType.fromString(json['type'] as String? ?? 'selector'),
      current: json['now'] as String? ?? (allList.isNotEmpty ? allList.first : ''),
      all: allList,
      raw: json,
    );
  }

  ProxyGroup copyWith({
    String? name,
    OutboundType? type,
    String? current,
    List<String>? all,
    Map<String, dynamic>? raw,
  }) {
    return ProxyGroup(
      name: name ?? this.name,
      type: type ?? this.type,
      current: current ?? this.current,
      all: all ?? this.all,
      raw: raw ?? this.raw,
    );
  }
}
