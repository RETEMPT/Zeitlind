import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/source_catalog_repository.dart';

class StarterSource {
  const StarterSource(this.key, this.name, this.sha256);
  final String key;
  final String name;
  final String sha256;
  Uri get uri => Uri.parse(
    'https://cdn.jsdelivr.net/gh/kuiti/manga-source-index@1850cfa5903a6c5105d57860ff6dc7f5607df00a/05-venera-sources/sources/$key.js',
  );
}

/// Links to fixed, audited upstream revisions; no remote scripts are bundled.
const starterSources = [
  StarterSource(
    'mkzhan',
    '漫客栈',
    '2988fe4b9c8913e9201375b0dd25ea8aa5febf7af6cac15801f2b70f1a99d429',
  ),
  StarterSource(
    'dongmanmanhua',
    '咚漫',
    '65df758f8643f331baf978a55d5bbbe8c8fff1df285b92f63f97bb18aa48935f',
  ),
  StarterSource(
    'manga_dex',
    'MangaDex',
    'c8beb84262da8fa3922ff0392fc2f79f03ee36ae08933d10571172ef6c8ce21d',
  ),
];

class StarterSourceResult {
  const StarterSourceResult(this.completed, this.errors);
  final Set<String> completed;
  final Map<String, Object> errors;
}

class StarterSourceInstaller {
  const StarterSourceInstaller(this.load);
  final SourceTextLoader load;

  Future<StarterSourceResult> run({
    Set<String> completed = const {},
    required bool Function(StarterSource source) isInstalled,
    required Future<void> Function(StarterSource source, String script) install,
    List<StarterSource> sources = starterSources,
  }) async {
    final done = Set<String>.of(completed);
    final errors = <String, Object>{};
    for (final source in sources) {
      if (done.contains(source.key)) continue;
      if (isInstalled(source)) {
        done.add(source.key);
        continue;
      }
      try {
        final script = await load(
          source.uri,
        ).timeout(const Duration(seconds: 45));
        if (sha256.convert(utf8.encode(script)).toString() != source.sha256) {
          throw const FormatException(
            'The basic source checksum does not match the audited version',
          );
        }
        await install(source, script);
        done.add(source.key);
      } catch (e) {
        errors[source.key] = e;
      }
    }
    return StarterSourceResult(done, errors);
  }
}
