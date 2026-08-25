/// Cleans and extracts the semantic version (e.g. "v1.2.10+30" -> "1.2.10", "v1.2.11" -> "1.2.11").
String normalizeSemver(String ver) {
  var v = ver.trim().toLowerCase();
  if (v.startsWith('v')) v = v.substring(1);
  // Strip build metadata: e.g. "1.2.10+30" -> "1.2.10"
  if (v.contains('+')) v = v.split('+').first;
  return v;
}

/// Compares dotted numeric version strings (e.g. "1.2.11" vs "1.2.10").
/// Returns true when [latest] is strictly newer than [current].
/// Handles build numbers (e.g. "30" or "+30"), "v" prefixes, and pre-release suffixes.
bool isNewerVersion(String latest, String current) {
  final lClean = normalizeSemver(latest);
  final cClean = normalizeSemver(current);

  // If current is just a build number (like "30") without dots and latest is semver (like "1.2.11"),
  // latest is definitely a valid new version.
  if (!cClean.contains('.') && lClean.contains('.')) {
    return true;
  }

  final l = lClean.split('.');
  final c = cClean.split('.');
  for (int i = 0; i < l.length && i < c.length; i++) {
    // Strip trailing pre-release suffixes like "1-rc" from numeric parts.
    final lNum = int.tryParse(l[i].split('-').first) ?? 0;
    final cNum = int.tryParse(c[i].split('-').first) ?? 0;
    if (lNum > cNum) return true;
    if (lNum < cNum) return false;
  }
  return l.length > c.length;
}
