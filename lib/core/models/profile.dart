enum ProfileType {
  remote,
  local,
  manual;

  String get displayName {
    switch (this) {
      case ProfileType.remote:
        return 'Remote Subscription';
      case ProfileType.local:
        return 'Local File';
      case ProfileType.manual:
        return 'Manual Config';
    }
  }
}

class Profile {
  final String id;
  final String name;
  final ProfileType type;
  final String? url;
  final String? filePath;
  final DateTime updatedAt;
  final int autoUpdateIntervalHours; // 0 = disabled
  final bool active;
  final int nodeCount;
  final int? uploadTraffic; // bytes
  final int? downloadTraffic; // bytes
  final int? totalTraffic; // bytes
  final DateTime? expireDate;
  final String rawConfig;

  Profile({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.filePath,
    required this.updatedAt,
    this.autoUpdateIntervalHours = 24,
    this.active = false,
    this.nodeCount = 0,
    this.uploadTraffic,
    this.downloadTraffic,
    this.totalTraffic,
    this.expireDate,
    required this.rawConfig,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'url': url,
      'filePath': filePath,
      'updatedAt': updatedAt.toIso8601String(),
      'autoUpdateIntervalHours': autoUpdateIntervalHours,
      'active': active,
      'nodeCount': nodeCount,
      'uploadTraffic': uploadTraffic,
      'downloadTraffic': downloadTraffic,
      'totalTraffic': totalTraffic,
      'expireDate': expireDate?.toIso8601String(),
      'rawConfig': rawConfig,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ProfileType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProfileType.remote,
      ),
      url: json['url'] as String?,
      filePath: json['filePath'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      autoUpdateIntervalHours: json['autoUpdateIntervalHours'] as int? ?? 24,
      active: json['active'] as bool? ?? false,
      nodeCount: json['nodeCount'] as int? ?? 0,
      uploadTraffic: json['uploadTraffic'] as int?,
      downloadTraffic: json['downloadTraffic'] as int?,
      totalTraffic: json['totalTraffic'] as int?,
      expireDate: json['expireDate'] != null ? DateTime.tryParse(json['expireDate'] as String) : null,
      rawConfig: json['rawConfig'] as String? ?? '',
    );
  }

  Profile copyWith({
    String? id,
    String? name,
    ProfileType? type,
    String? url,
    String? filePath,
    DateTime? updatedAt,
    int? autoUpdateIntervalHours,
    bool? active,
    int? nodeCount,
    int? uploadTraffic,
    int? downloadTraffic,
    int? totalTraffic,
    DateTime? expireDate,
    String? rawConfig,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      updatedAt: updatedAt ?? this.updatedAt,
      autoUpdateIntervalHours: autoUpdateIntervalHours ?? this.autoUpdateIntervalHours,
      active: active ?? this.active,
      nodeCount: nodeCount ?? this.nodeCount,
      uploadTraffic: uploadTraffic ?? this.uploadTraffic,
      downloadTraffic: downloadTraffic ?? this.downloadTraffic,
      totalTraffic: totalTraffic ?? this.totalTraffic,
      expireDate: expireDate ?? this.expireDate,
      rawConfig: rawConfig ?? this.rawConfig,
    );
  }
}
