import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/source_diagnostics.dart';
import 'package:zeitlind/features/sources/data/resilient_source_loader.dart';

void main() {
  const script = 'class Komga extends ComicSource { key = "komga"; }';
  const target = SourceProbeTarget(
    key: 'komga',
    name: 'Komga',
    url:
        'https://raw.githubusercontent.com/venera-app/venera-configs/main/komga.js',
  );

  test('copied GitHub file pages become raw script links', () {
    expect(
      sourceHttpUri(
        'https://github.com/user/repo/blob/main/source.js?raw=true',
      ).toString(),
      'https://raw.githubusercontent.com/user/repo/main/source.js',
    );
  });

  test('known mirror failure retries the identical repository path', () async {
    final requested = <Uri>[];
    final loader = ResilientSourceLoader((uri) async {
      requested.add(uri);
      if (uri.host == 'raw.githubusercontent.com') throw StateError('offline');
      return script;
    });
    final result = await SourceDiagnostics(loader.load).check(target);
    expect(result.health, SourceHealth.reachable);
    expect(result.resolvedUri!.host, 'cdn.jsdelivr.net');
    expect(requested.length, 2);
    expect(requested.last.path, '/gh/venera-app/venera-configs@main/komga.js');
  });

  test(
    'custom repositories are never silently redirected to other hosts',
    () async {
      var calls = 0;
      final loader = ResilientSourceLoader((_) async {
        calls++;
        throw StateError('offline');
      });
      await expectLater(
        loader.load(Uri.parse('https://private.example/source.js')),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );

  test(
    'HTML responses use the mirror instead of trying to install a web page',
    () async {
      final loader = ResilientSourceLoader(
        (uri) async => uri.host == 'raw.githubusercontent.com'
            ? '<!DOCTYPE html><html>Error</html>'
            : script,
      );
      expect(
        (await SourceDiagnostics(loader.load).check(target)).health,
        SourceHealth.reachable,
      );
    },
  );

  test(
    'reports a source key mismatch and network failures per source',
    () async {
      final mismatch = await SourceDiagnostics(
        (uri) async =>
            SourceTextResponse(script.replaceAll('"komga"', '"other"'), uri),
      ).check(target);
      expect(mismatch.health, SourceHealth.failed);
      final failed = await SourceDiagnostics(
        (_) async => throw StateError('404'),
      ).check(target);
      expect(failed.health, SourceHealth.failed);
      expect(failed.message, contains('404'));
    },
  );

  test('dynamic metadata is marked for manual verification', () async {
    final result = await SourceDiagnostics(
      (uri) async => SourceTextResponse(
        'class Komga extends ComicSource { get key() { return "komga"; } }',
        uri,
      ),
    ).check(target);
    expect(result.health, SourceHealth.warning);
  });
}
