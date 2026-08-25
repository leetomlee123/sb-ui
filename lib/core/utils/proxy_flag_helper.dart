class ProxyFlagHelper {
  /// Returns a country/region flag emoji or representative symbol based on the node name.
  static String getFlag(String nodeName) {
    final lower = nodeName.toLowerCase();

    // 1. Special types priority
    if (lower.contains('auto') || lower.contains('自动') || lower.contains('urltest') || lower.contains('fallback')) {
      return '⚡';
    }
    if (lower.contains('direct') || lower.contains('直连')) {
      return '🎯';
    }

    // Helper to match 2-letter country code or keywords safely
    bool matches(String code, List<String> keywords) {
      for (final kw in keywords) {
        if (lower.contains(kw)) return true;
      }
      final regex = RegExp('(^|[^a-z])$code([^a-z]|\$)');
      return regex.hasMatch(lower);
    }

    if (matches('hk', ['hong', '香港', '港'])) return '🇭🇰';
    if (matches('tw', ['taiwan', '台湾', '臺', '台北'])) return '🇹🇼';
    if (matches('jp', ['japan', '东京', '日本', '大阪'])) return '🇯🇵';
    if (matches('sg', ['singapore', '新加坡', '狮城'])) return '🇸🇬';
    if (matches('us', ['united states', 'america', '美国', '洛杉矶', '硅谷', '纽约', '波特兰'])) return '🇺🇸';
    if (matches('kr', ['korea', '韩国', '首尔'])) return '🇰🇷';
    if (matches('uk', ['united kingdom', 'britain', 'london', '英国', '伦敦', 'gb'])) return '🇬🇧';
    if (matches('de', ['germany', '德国', '法兰克福'])) return '🇩🇪';
    if (matches('fr', ['france', '法国', '巴黎'])) return '🇫🇷';
    if (matches('ca', ['canada', '加拿大'])) return '🇨🇦';
    if (matches('au', ['australia', '澳大利亚', '悉尼', '墨尔本', '澳洲'])) return '🇦🇺';
    if (matches('ru', ['russia', '俄罗斯', '莫斯科'])) return '🇷🇺';
    if (matches('in', ['india', '印度'])) return '🇮🇳';
    if (matches('tr', ['turkey', '土耳其'])) return '🇹🇷';
    if (matches('ar', ['argentina', '阿根廷'])) return '🇦🇷';
    if (matches('nl', ['netherlands', '荷兰', '阿姆斯特丹'])) return '🇳🇱';
    if (matches('ch', ['switzerland', '瑞士'])) return '🇨🇭';
    if (matches('se', ['sweden', '瑞典'])) return '🇸🇪';
    if (matches('my', ['malaysia', '马来西亚'])) return '🇲🇾';
    if (matches('ph', ['philippines', '菲律宾'])) return '🇵🇭';
    if (matches('vn', ['vietnam', '越南'])) return '🇻🇳';
    if (matches('th', ['thailand', '泰国'])) return '🇹🇭';
    if (matches('cn', ['china', '中国'])) return '🇨🇳';

    return '🌐';
  }
}
