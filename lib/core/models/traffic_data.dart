class TrafficPoint {
  final int up; // bytes per second
  final int down; // bytes per second
  final DateTime timestamp;

  TrafficPoint({
    required this.up,
    required this.down,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TrafficPoint.fromJson(Map<String, dynamic> json) {
    return TrafficPoint(
      up: json['up'] as int? ?? 0,
      down: json['down'] as int? ?? 0,
    );
  }
}

class MemoryInfo {
  final int inuse;
  final int oslimit;

  MemoryInfo({
    required this.inuse,
    required this.oslimit,
  });

  factory MemoryInfo.fromJson(Map<String, dynamic> json) {
    return MemoryInfo(
      inuse: json['inuse'] as int? ?? 0,
      oslimit: json['oslimit'] as int? ?? 0,
    );
  }
}
