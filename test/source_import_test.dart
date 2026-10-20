import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/source_import.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/source_script.dart';
import 'package:zeitlind/features/sources/domain/suwayomi_bridge.dart';
import 'package:zeitlind/features/sources/data/source_catalog_repository.dart';

void main() {
  test(
    'one broken repository does not hide updates from other repositories',
    () async {
      final repository = SourceCatalogRepository((uri) async {
        if (uri.host == 'broken.example') throw StateError('offline');
        final version = uri.host == 'new.example' ? '2.0.0' : '1.0.0';
        return jsonEncode([
          {
            'key': 'a',
            'name': 'Source',
            'version': version,
            'fileName': 'source.js',
          },
        ]);
      });
      final result = await repository.loadMany([
        'https://old.example/index.json',
        'https://broken.example/index.json',
        'https://new.example/index.json',
      ]);
      expect(result.single.version, '2.0.0');
      await expectLater(
        repository.loadMany(['https://broken.example/index.json']),
        throwsStateError,
      );
    },
  );
  final directory = Uri.parse(
    'https://cdn.jsdelivr.net/gh/kuiti/manga-source-index@main/05-venera-sources/tier1/index.json',
  );
  final entries = [
    {
      'name': '漫客栈',
      'key': 'mkzhan',
      'version': '1.1.4',
      'fileName': 'mkzhan.js',
      'url':
          'https://cdn.jsdelivr.net/gh/kuiti/manga-source-index@main/05-venera-sources/sources/mkzhan.js',
      'ecosystems': ['legado', 'venera'],
    },
  ];
  test(
    'user directory is recognized as a directory rather than JavaScript',
    () {
      final result = SourceImportDocument.parse(
        jsonEncode(entries),
        origin: directory,
      );
      expect(result.kind, SourceImportKind.directory);
      expect(result.entries.single.key, 'mkzhan');
      expect(
        result.entries.single.scriptUri.path,
        endsWith('/sources/mkzhan.js'),
      );
    },
  );
  test('native Venera relative filenames use the directory location', () {
    final result = SourceImportDocument.parse(
      '[{"name":"Komga","key":"komga","version":"1","fileName":"komga.js"}]',
      origin: Uri.parse(SourceCatalogPresets.direct),
    );
    expect(
      result.entries.single.scriptUri.toString(),
      'https://raw.githubusercontent.com/venera-app/venera-configs/main/komga.js',
    );
  });
  test(
    'JSON exports support wrappers and single entries with absolute URLs',
    () {
      for (final content in [
        jsonEncode(entries.single),
        jsonEncode({'sources': entries}),
        jsonEncode({'items': entries}),
        jsonEncode({'data': entries}),
      ]) {
        expect(
          SourceImportDocument.parse(content).entries.single.key,
          'mkzhan',
        );
      }
    },
  );
  test('a local directory cannot resolve relative names on another host', () {
    expect(
      () => SourceImportDocument.parse(
        '[{"name":"A","key":"a","version":"1","fileName":"a.js"}]',
      ),
      throwsFormatException,
    );
  });
  test('Mihon metadata is routed to the compatible server connector', () {
    final result = SourceImportDocument.parse(
      '[{"name":"Extension","pkg":"eu.kanade.example","apk":"example.apk"}]',
    );
    expect(result.kind, SourceImportKind.mihonRepository);
  });
  test(
    'Legado rules, malformed JSON and HTML give format-specific failures',
    () {
      for (final content in [
        '[{"bookSourceUrl":"https://example.com","ruleSearch":{}}]',
        '[{"name":',
        '<!DOCTYPE html><html>Denied</html>',
        '',
        'PK\u0003\u0004binary',
      ]) {
        expect(
          () => SourceImportDocument.parse(content),
          throwsFormatException,
        );
      }
    },
  );
  test('BOM, indentation, comments and line breaks are accepted', () {
    final parsed = SourceScript.parse(
      '\uFEFF/*class Wrong extends ComicSource {}*/\r\n  class\n Good_Source\t extends /* note */\n ComicSource { name = "中文"; }',
    );
    expect(parsed.className, 'Good_Source');
    expect(parsed.content, isNot(startsWith('\uFEFF')));
  });
  test('class-like text inside comments and strings is ignored', () {
    for (final content in [
      '// class Fake extends ComicSource {}',
      'const text = "class Fake extends ComicSource {}";',
      'const text = `class Fake extends ComicSource {}`;',
      'class Fake extends ComicSourceOther {}',
    ]) {
      expect(() => SourceScript.parse(content), throwsFormatException);
    }
    expect(
      () => SourceScript.parse(
        'class A extends ComicSource {} class B extends ComicSource {}',
      ),
      throwsFormatException,
    );
  });
  test('regex quotes and escaped slashes do not hide source declarations', () {
    final source = SourceScript.parse(r'''
      const cookie = /document\.cookie\s*=\s*(["'])([\s\S]*?)\1/;
      const fake = /class Fake extends ComicSource {}/;
      const ratio = 10 / 2;
      function parse(value) { return value.replace(/\\([\\"'])/g, "$1"); }
      class Actual extends ComicSource {}
    ''');
    expect(source.className, 'Actual');
    expect(
      () => SourceScript.parse(r'/class Fake extends ComicSource {}/;'),
      throwsFormatException,
    );
  });
  test('UTF-8 BOM and Windows UTF-16 files preserve source text', () {
    const text = 'class 中文 {}';
    expect(decodeSourceBytes([239, 187, 191, ...utf8.encode(text)]), text);
    expect(
      decodeSourceBytes([
        255,
        254,
        for (final unit in text.codeUnits) ...[unit & 255, unit >> 8],
      ]),
      text,
    );
    expect(
      decodeSourceBytes([
        254,
        255,
        for (final unit in text.codeUnits) ...[unit >> 8, unit & 255],
      ]),
      text,
    );
    expect(() => decodeSourceBytes([255, 254, 1]), throwsFormatException);
  });
  test('Markdown and application links share URL normalization', () {
    expect(sourceImportUri('[$directory]($directory)'), directory);
    expect(
      sourceImportUri(
        'venera://source?url=${Uri.encodeQueryComponent(directory.toString())}',
      ),
      directory,
    );
    expect(
      sourceImportUri(
        'zeitlind://source?repo=${Uri.encodeQueryComponent(directory.toString())}',
      ),
      directory,
    );
    expect(
      sourceImportUri('https://github.com/owner/repository').path,
      '/owner/repository/HEAD/index.json',
    );
    expect(
      sourceImportUri(
        'https://github.com/owner/repository/tree/main/folder',
      ).path,
      '/owner/repository/main/folder/index.json',
    );
  });
  test('public GitHub mirrors retry only the identical repository path', () {
    final candidates = sourceFallbackUris(directory);
    expect(candidates.length, 2);
    expect(
      candidates.last.toString(),
      'https://raw.githubusercontent.com/kuiti/manga-source-index/main/05-venera-sources/tier1/index.json',
    );
    expect(sourceFallbackUris(directory.replace(query: 'token=private')), [
      directory.replace(query: 'token=private'),
    ]);
  });
  test('Suwayomi supports subpaths and large source IDs', () {
    final server = suwayomiBaseUri('http://localhost:4567/library/api/v1/');
    expect(server.toString(), 'http://localhost:4567/library/');
    final source = SuwayomiRemoteSource.parse(
      '[{"id":"9223372036854775807","name":"A","lang":"zh"}]',
    ).single;
    expect(source.id, '9223372036854775807');
    expect(source.key(server), startsWith('suwayomi_'));
    expect(
      source.key(server),
      isNot(source.key(suwayomiBaseUri('http://localhost:4568'))),
    );
  });
  test('bridge configuration escapes names without embedding credentials', () {
    final server = suwayomiBaseUri('https://example.com');
    const source = SuwayomiRemoteSource('42', '"; throw new Error(); //', 'en');
    final script = buildSuwayomiScript(
      'server = __ZEITLIND_SERVER__; name = __ZEITLIND_SOURCE_NAME__; key = __ZEITLIND_SOURCE_KEY__;',
      server,
      source,
    );
    expect(script, contains(jsonEncode('"; throw new Error(); // · en')));
    expect(script, isNot(contains('Authorization')));
  });
}
