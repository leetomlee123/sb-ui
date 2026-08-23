class GeoAssetInfo {
  final String name; // e.g. 'geoip-cn.srs'
  final String tag; // e.g. 'geoip-cn'
  final String displayName;
  final String description;
  final String primaryUrl;
  final String fallbackUrl;
  final int sizeInBytes;
  final DateTime? lastModified;
  final bool isInstalled;

  const GeoAssetInfo({
    required this.name,
    required this.tag,
    required this.displayName,
    required this.description,
    required this.primaryUrl,
    required this.fallbackUrl,
    this.sizeInBytes = 0,
    this.lastModified,
    this.isInstalled = false,
  });

  GeoAssetInfo copyWith({
    String? name,
    String? tag,
    String? displayName,
    String? description,
    String? primaryUrl,
    String? fallbackUrl,
    int? sizeInBytes,
    DateTime? lastModified,
    bool? isInstalled,
  }) {
    return GeoAssetInfo(
      name: name ?? this.name,
      tag: tag ?? this.tag,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      primaryUrl: primaryUrl ?? this.primaryUrl,
      fallbackUrl: fallbackUrl ?? this.fallbackUrl,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastModified: lastModified ?? this.lastModified,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }
}
