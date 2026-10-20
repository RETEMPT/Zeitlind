/// A script update URL identifies its repository, never the comic website.
String sourceWebsiteIdentity(String key, [String? website]) {
  const known = {
    'copy_manga': 'copymanga',
    'copy_manga_multi_accounts': 'copymanga',
    'manga_dex': 'mangadex.org',
    'mangadex': 'mangadex.org',
    'mkzhan': 'mkzhan.com',
    'kanman': 'kanman.com',
    'dongmanmanhua': 'dongmanmanhua.cn',
    'manben': 'manben.com',
    'bilimanga': 'bilibili.com',
    'bilibili': 'bilibili.com',
    'qq_comic_official': 'qq.com',
    'qq_comic': 'qq.com',
    'shonen_jump_plus': 'shonenjumpplus.com',
  };
  final normalizedKey = key.toLowerCase();
  if (known.containsKey(normalizedKey)) return 'site:${known[normalizedKey]}';
  if (website != null && website.trim().isNotEmpty) {
    final uri = Uri.tryParse(
      website.contains('://') ? website.trim() : 'https://${website.trim()}',
    );
    var host = uri?.host.toLowerCase() ?? '';
    host = host.replaceFirst(RegExp(r'^(www\d*|m|mobile)\.'), '');
    if (host.isNotEmpty) return 'site:$host';
  }
  return 'key:${normalizedKey.replaceAll(RegExp(r'[_\-\s]'), '')}';
}

String? scriptWebsite(String script) => RegExp(
  r'''\b(?:webBase|baseUrl|baseURL|BASE_URL|webUrl)\s*=\s*['"](https?://[^'"]+)['"]''',
).firstMatch(script)?.group(1);

String resolveSourceWebsiteIdentity(
  String key,
  String script, {
  String? supplied,
  String? previous,
}) {
  final inferred = sourceWebsiteIdentity(key, scriptWebsite(script));
  for (final candidate in [supplied, previous, inferred]) {
    if (candidate != null && candidate.startsWith('site:')) {
      return candidate;
    }
  }
  return supplied ?? previous ?? inferred;
}
