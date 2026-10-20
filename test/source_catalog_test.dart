import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/data/source_catalog_repository.dart';
import 'package:zeitlind/features/sources/application/source_catalog_controller.dart';

const entry = {
  'name': 'Komga',
  'key': 'komga',
  'version': '1.0.0',
  'fileName': 'komga.js',
};

void main() {
  final uri = Uri.parse('https://example.org/sources/index.json?token=1');

  test('resolves a script relative to the directory actually loaded', () {
    final source = parseSourceCatalog(jsonEncode([entry]), uri).single;
    expect(source.scriptUri.toString(), 'https://example.org/sources/komga.js');
    expect(source.matches('  KOMGA '), isTrue);
  });

  test('supports explicit absolute URLs and description search', () {
    final source = parseSourceCatalog(
      jsonEncode([
        {
          ...entry,
          'url': 'https://cdn.example.org/plugin.js?v=2',
          'description': '自建书库',
        },
      ]),
      uri,
    ).single;
    expect(source.scriptUri.host, 'cdn.example.org');
    expect(source.matches('自建'), isTrue);
  });

  test('invalid directory shapes and missing fields give useful errors', () {
    for (final content in ['{}', '[null]', '[{"name":"Incomplete"}]']) {
      expect(() => parseSourceCatalog(content, uri), throwsFormatException);
    }
  });

  test('merges duplicates and rejects executable or local URL schemes', () {
    expect(parseSourceCatalog(jsonEncode([entry, entry]), uri).length, 1);
    for (final value in [
      'file:///private/source.js',
      'javascript:alert(1)',
      'https://u:p@example.org/a',
      'invalid',
    ]) {
      expect(() => sourceHttpUri(value), throwsFormatException);
    }
  });

  test('a late response cannot replace a newer directory', () async {
    final first = Completer<String>();
    final second = Completer<String>();
    final controller = SourceCatalogController(
      SourceCatalogRepository(
        (uri) => uri.host == 'first.org' ? first.future : second.future,
      ),
    );
    final old = controller.load('https://first.org/index.json');
    final recent = controller.load('https://second.org/index.json');
    second.complete(
      jsonEncode([
        {...entry, 'name': 'New directory'},
      ]),
    );
    expect(await recent, isTrue);
    first.complete(jsonEncode([entry]));
    expect(await old, isFalse);
    expect(controller.entries.single.name, 'New directory');
    expect(controller.loadedAddress, 'https://second.org/index.json');
    controller.dispose();
  });

  test(
    'failed refresh preserves entries and the last successful address',
    () async {
      var fail = false;
      final controller = SourceCatalogController(
        SourceCatalogRepository((_) async {
          if (fail) throw StateError('offline');
          return jsonEncode([entry]);
        }),
      );
      await controller.load('https://example.org/index.json');
      fail = true;
      expect(await controller.load('https://bad.org/index.json'), isFalse);
      expect(controller.status, SourceCatalogStatus.failed);
      expect(controller.entries.single.key, 'komga');
      expect(controller.loadedAddress, 'https://example.org/index.json');
      controller.dispose();
    },
  );

  test(
    'closing during a request never notifies a disposed controller',
    () async {
      final response = Completer<String>();
      final controller = SourceCatalogController(
        SourceCatalogRepository((_) => response.future),
      );
      final pending = controller.load('https://example.org/index.json');
      controller.dispose();
      response.complete(jsonEncode([entry]));
      expect(await pending, isFalse);
    },
  );
}
