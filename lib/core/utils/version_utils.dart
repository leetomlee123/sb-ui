/// Compares dotted numeric version strings (e.g. "1.2.10" vs "1.2.9").
/// Returns true when [latest] is strictly newer than [current].
/// Leading "v" prefixes are tolerated; non-numeric segments fall back to 0.
bool isNewerVersion(String latest, String current) {
  final l = latest.replaceAll('v', '').split('.');
  final c = current.replaceAll('v', '').split('.');
  for (int i = 0; i < l.length && i < c.length; i++) {
    // Strip trailing pre-release suffixes like "1-rc" from numeric parts.
    final lNum = int.tryParse(l[i].split('-').first) ?? 0;
    final cNum = int.tryParse(c[i].split('-').first) ?? 0;
    if (lNum > cNum) return true;
    if (lNum < cNum) return false;
  }
  return l.length > c.length;
}
