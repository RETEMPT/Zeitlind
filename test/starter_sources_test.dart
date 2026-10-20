import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/starter_sources.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/suwayomi_bridge.dart';
import 'package:zeitlind/features/sources/domain/source_identity.dart';

void main() {
  test('all 31 native defaults use verified immutable snapshot URLs', () {
    expect(starterSources, hasLength(31));
    expect(starterSources.map((s) => s.key).toSet(), hasLength(31));
    for (final source in starterSources) {
      expect(source.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(source.uri.host, 'git.nyne.dev');
      expect(source.uri.path, contains('/raw/commit/$nativeStarterRevision/'));
      expect(source.uri.pathSegments.last, source.fileName);
    }
    expect(
      starterSources.firstWhere((s) => s.key == 'Komiic').fileName,
      'komiic.js',
    );
    expect(
      starterSources.firstWhere((s) => s.key == 'ManHuaGui').fileName,
      'manhuagui.js',
    );
  });
  test(
    'a directory without website metadata still uses the script website for deduplication',
    () {
      expect(
        resolveSourceWebsiteIdentity(
          'legacy_name',
          'class Source extends ComicSource { static webBase="https://www.comic.example"; }',
          supplied: 'key:legacyname',
        ),
        'site:comic.example',
      );
    },
  );
  test('Suwayomi variants of the same website are merged', () {
    final result = SuwayomiRemoteSource.parse(
      '[{"id":"1","name":"Site EN","lang":"en","baseUrl":"https://www.comic.example"},{"id":"2","name":"Site ZH","lang":"zh","baseUrl":"https://m.comic.example"}]',
    );
    expect(result.length, 1);
  });
  const script = 'class Demo extends ComicSource { key="demo"; }';
  final spec = StarterSource(
    'demo',
    'Demo',
    sha256.convert(utf8.encode(script)).toString(),
  );
  test(
    'each success is checkpointed and a failed source resumes alone',
    () async {
      final second = StarterSource('second', 'Second', spec.sha256);
      final downloads = <String>[];
      final installed = <String>{};
      var saved = <String>{};
      var failSecond = true;
      final installer = StarterSourceInstaller((uri) async {
        downloads.add(uri.pathSegments.last);
        if (failSecond && uri.pathSegments.last == 'second.js') {
          throw StateError('Network interrupted');
        }
        return script;
      });
      Future<StarterSourceResult> run() => installer.run(
        sources: [spec, second],
        completed: saved,
        isInstalled: (source) => installed.contains(source.key),
        install: (source, _) async => installed.add(source.key),
        onProgress: (keys) async => saved = keys.toSet(),
      );
      final partial = await run();
      expect(saved, {'demo'});
      expect(partial.errors.keys, ['second']);
      failSecond = false;
      final resumed = await run();
      expect(saved, {'demo', 'second'});
      expect(resumed.errors, isEmpty);
      expect(downloads, ['demo.js', 'second.js', 'second.js']);
    },
  );
  test(
    'failed checkpoint remains retryable without reinstalling the source',
    () async {
      var installed = false;
      var downloads = 0;
      var installs = 0;
      final installer = StarterSourceInstaller((_) async {
        downloads++;
        return script;
      });
      final partial = await installer.run(
        sources: [spec],
        isInstalled: (_) => installed,
        install: (_, _) async {
          installed = true;
          installs++;
        },
        onProgress: (_) async => throw StateError('Storage unavailable'),
      );
      expect(partial.completed, isEmpty);
      expect(partial.errors.keys, ['demo']);
      Set<String>? checkpoint;
      final resumed = await installer.run(
        sources: [spec],
        completed: partial.completed,
        isInstalled: (_) => installed,
        install: (_, _) async => fail('Must not install twice'),
        onProgress: (keys) async => checkpoint = keys,
      );
      expect(resumed.completed, {'demo'});
      expect(checkpoint, {'demo'});
      expect(resumed.errors, isEmpty);
      expect(downloads, 1);
      expect(installs, 1);
    },
  );
  test(
    'basic source setup installs and remembers the verified snapshot',
    () async {
      var installs = 0;
      final result = await StarterSourceInstaller((_) async => script).run(
        sources: [spec],
        isInstalled: (_) => false,
        install: (_, value) async {
          expect(value, script);
          installs++;
        },
      );
      expect(result.completed, {'demo'});
      expect(installs, 1);
      expect(result.errors, isEmpty);
    },
  );
  test(
    'deleted completed sources stay deleted and existing websites are not duplicated',
    () async {
      var downloads = 0;
      final installer = StarterSourceInstaller((_) async {
        downloads++;
        return script;
      });
      await installer.run(
        sources: [spec],
        completed: {'demo'},
        isInstalled: (_) => false,
        install: (_, _) async => fail('Must not reinstall deleted source'),
      );
      await installer.run(
        sources: [spec],
        isInstalled: (_) => true,
        install: (_, _) async =>
            fail('Must not duplicate an installed website'),
      );
      expect(downloads, 0);
    },
  );
  test('modified source text is rejected and remains retryable', () async {
    var installs = 0;
    final result =
        await StarterSourceInstaller((_) async => '$script // changed').run(
          sources: [spec],
          isInstalled: (_) => false,
          install: (_, _) async {
            installs++;
          },
        );
    expect(result.completed, isEmpty);
    expect(result.errors.keys, ['demo']);
    expect(installs, 0);
  });
  test('same-website variants merge while preferring an installed source', () {
    final a = SourceCatalogEntry(
      key: 'a',
      name: 'First',
      version: '1',
      description: '',
      scriptUri: Uri.parse('https://repo.example/a.js'),
      website: 'https://www.comic.example',
    );
    final b = SourceCatalogEntry(
      key: 'b',
      name: 'Second',
      version: '2',
      description: '',
      scriptUri: Uri.parse('https://other-repo.example/b.js'),
      website: 'm.comic.example',
    );
    expect(deduplicateSourceCatalog([a, b]).single.key, 'b');
    expect(
      deduplicateSourceCatalog([a, b], preferredKeys: {'a'}).single.key,
      'a',
    );
    final variants = parseSourceCatalog(
      '[{"key":"copy_manga","name":"Copy","version":"1","fileName":"a.js"},{"key":"copy_manga_multi_accounts","name":"Copy alternate","version":"1","fileName":"b.js"}]',
      Uri.parse('https://example.com/index.json'),
    );
    expect(variants.length, 1);
  });
}
