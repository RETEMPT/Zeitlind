import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/starter_sources.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/suwayomi_bridge.dart';

void main() {
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
