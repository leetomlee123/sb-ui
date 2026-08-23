class ConnectionMetadata {
  final String network;
  final String type;
  final String sourceIP;
  final String sourcePort;
  final String destinationIP;
  final String destinationPort;
  final String host;
  final String? processPath;

  ConnectionMetadata({
    required this.network,
    required this.type,
    required this.sourceIP,
    required this.sourcePort,
    required this.destinationIP,
    required this.destinationPort,
    required this.host,
    this.processPath,
  });

  factory ConnectionMetadata.fromJson(Map<String, dynamic> json) {
    return ConnectionMetadata(
      network: json['network'] as String? ?? '',
      type: json['type'] as String? ?? '',
      sourceIP: json['sourceIP'] as String? ?? '',
      sourcePort: (json['sourcePort'] ?? '').toString(),
      destinationIP: json['destinationIP'] as String? ?? '',
      destinationPort: (json['destinationPort'] ?? '').toString(),
      host: json['host'] as String? ?? '',
      processPath: json['processPath'] as String?,
    );
  }
}

class ActiveConnection {
  final String id;
  final ConnectionMetadata metadata;
  final int upload;
  final int download;
  final DateTime start;
  final List<String> chains;
  final String rule;
  final String rulePayload;

  ActiveConnection({
    required this.id,
    required this.metadata,
    required this.upload,
    required this.download,
    required this.start,
    required this.chains,
    required this.rule,
    required this.rulePayload,
  });

  factory ActiveConnection.fromJson(Map<String, dynamic> json) {
    final metaJson = json['metadata'] as Map<String, dynamic>? ?? {};
    final chainsList = (json['chains'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    
    DateTime startTime = DateTime.now();
    if (json['start'] != null) {
      try {
        startTime = DateTime.parse(json['start'] as String);
      } catch (_) {}
    }

    return ActiveConnection(
      id: json['id'] as String? ?? '',
      metadata: ConnectionMetadata.fromJson(metaJson),
      upload: json['upload'] as int? ?? 0,
      download: json['download'] as int? ?? 0,
      start: startTime,
      chains: chainsList,
      rule: json['rule'] as String? ?? '',
      rulePayload: json['rulePayload'] as String? ?? '',
    );
  }
}
