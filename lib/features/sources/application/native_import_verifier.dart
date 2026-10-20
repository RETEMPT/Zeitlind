import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:rhttp/rhttp.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/foundation/js_engine.dart';
import 'package:zeitlind/utils/translations.dart';
import '../data/source_catalog_repository.dart';
import '../data/source_transport.dart';
import '../domain/source_catalog.dart';
import '../domain/source_import.dart';
import '../domain/suwayomi_bridge.dart';
import '../domain/starter_sources.dart';

/// Runs in a fresh profile. No library, account, or installed user source is read.
Future<Map<String, dynamic>> verifyNativeSourceImports({
  Future<void> Function(Map<String, dynamic>)? onProgress,
}) async {
  await App.init();
  final profile = await Directory.systemTemp.createTemp(
    'zeitlind-native-import-',
  );
  App.dataPath = profile.path;
  App.cachePath = '${profile.path}/cache';
  await Directory(App.cachePath).create(recursive: true);
  appdata.settings['language'] = 'en-US';
  appdata.settings['proxy'] = 'direct';
  await AppTranslation.init();
  await Rhttp.init().timeout(const Duration(seconds: 30));
  await JsEngine().init().timeout(const Duration(seconds: 30));
  await ComicSourceManager().init().timeout(const Duration(seconds: 30));
  final checks = <Map<String, dynamic>>[];
  Future<void> check(String name, Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 65));
      checks.add({'name': name, 'passed': true});
    } catch (e) {
      checks.add({'name': name, 'passed': false, 'error': e.toString()});
    }
    await onProgress?.call({
      'platform': Platform.operatingSystem,
      'passed': false,
      'phase': 'running',
      'profile': profile.path,
      'checks': checks,
    });
  }

  void require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  const fixture =
      '\uFEFF// Unicode and declaration layout regression\n  class\n ImportFixture extends /* native */ ComicSource {\n name="Import fixture"; key="zeitlind_import_fixture"; version="1.0.0";\n settings={ number:{title:"Number",type:"select",options:[{value:1,text:"One"},{value:2,text:"Two"}],default:1}, enabled:{title:"Enabled",type:"switch",default:true}, address:{title:"Address",type:"input",default:""}, callback:{title:"Callback",type:"callback",callback:async()=>42} }; }';
  await check('local-file-bom-multiline-and-native-settings', () async {
    final file = File('${profile.path}/fixture.JS');
    await file.writeAsString(fixture);
    final source = await ComicSourceManager().install(
      decodeSourceBytes(await file.readAsBytes()),
      file.uri.pathSegments.last,
      initialize: false,
    );
    require(source.settings?.length == 4, 'Native settings types were lost');
    require(
      source.settings!['number']!['options'][1]['value'] == 2,
      'Numeric option values changed type',
    );
    source.data['settings'] = {'number': 2};
    await source.saveData();
    await ComicSourceManager().reload();
    require(
      ComicSource.find(source.key)?.data['settings']['number'] == 2,
      'Reload lost the saved setting',
    );
  });
  await check('failed-update-keeps-old-file-and-runtime', () async {
    final previous = ComicSource.find('zeitlind_import_fixture')!;
    final original = await File(previous.filePath).readAsString();
    var rejected = false;
    try {
      await ComicSourceManager().install(
        'class Broken extends ComicSource { name="Bad"; key="another_key"; version="2"; }',
        previous.filePath,
        replacing: previous,
        expectedKey: previous.key,
        initialize: false,
      );
    } catch (_) {
      rejected = true;
    }
    require(
      rejected && identical(ComicSource.find(previous.key), previous),
      'Failed update changed the installed source',
    );
    require(
      await File(previous.filePath).readAsString() == original,
      'Failed update replaced the old script',
    );
  });

  await check('same-website-deduplication-and-legacy-aliases', () async {
    final previous = ComicSource.find('zeitlind_import_fixture')!;
    final count = ComicSource.all().length;
    var rejected = false;
    try {
      await ComicSourceManager().install(
        fixture.replaceAll('zeitlind_import_fixture', 'duplicate_fixture'),
        'duplicate.js',
        websiteIdentity: previous.websiteIdentity,
        initialize: false,
      );
    } on FormatException {
      rejected = true;
    }
    require(
      rejected && ComicSource.all().length == count,
      'Duplicate website was installed',
    );
    final legacy = File('${profile.path}/comic_source/legacy.js');
    await legacy.writeAsString(
      fixture.replaceAll('zeitlind_import_fixture', 'legacy_fixture'),
    );
    await File(
      '${profile.path}/comic_source/legacy_fixture.data',
    ).writeAsString(jsonEncode({'_zeitlindWebsite': previous.websiteIdentity}));
    await ComicSourceManager().reload();
    require(
      ComicSource.all().length == count &&
          await File('${legacy.path}.duplicate').exists(),
      'Legacy duplicate was not retired safely',
    );
    await ComicSourceManager().reload();
    require(
      ComicSource.find('legacy_fixture')?.key == previous.key &&
          ComicSource.fromIntKey('legacy_fixture'.hashCode)?.key ==
              previous.key,
      'Legacy library identities were lost',
    );
    final canonical = ComicSource.find(previous.key)!;
    await ComicSourceManager().install(
      fixture.replaceAll('1.0.0', '1.0.1'),
      canonical.filePath,
      replacing: canonical,
      initialize: false,
    );
    require(
      JsEngine().runCode('ComicSource.sources.legacy_fixture.version') ==
          '1.0.1',
      'Source update left a stale legacy alias',
    );
  });
  await check('script-website-overrides-missing-directory-metadata', () async {
    const script =
        'class SiteFixture extends ComicSource { name="Site fixture"; key="site_primary"; version="1"; static webBase="https://www.fixture.example"; }';
    await ComicSourceManager().install(
      script,
      'site-primary.js',
      websiteIdentity: 'key:siteprimary',
      initialize: false,
    );
    var rejected = false;
    try {
      await ComicSourceManager().install(
        script.replaceAll('site_primary', 'site_alternative'),
        'site-alternative.js',
        websiteIdentity: 'key:sitealternative',
        initialize: false,
      );
    } on FormatException {
      rejected = true;
    }
    require(
      rejected && ComicSource.find('site_alternative') == null,
      'Missing directory metadata allowed a duplicate website',
    );
  });
  final mock = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final server = Uri.parse('http://127.0.0.1:${mock.port}/');
  final receivedHeaders = <String?>[];
  mock.listen((request) async {
    receivedHeaders.add(request.headers.value('authorization'));
    dynamic data;
    final path = request.uri.path;
    if (path.endsWith('/source/list')) {
      data = [
        {'id': '42', 'name': 'Mock source', 'lang': 'en'},
      ];
    } else if (path.contains('/source/42/')) {
      data = {
        'mangaList': [
          {'id': 7, 'title': 'Native bridge comic'},
        ],
        'hasNextPage': false,
      };
    } else if (path.endsWith('/chapters')) {
      data = [
        {'index': 1, 'name': 'Chapter 1', 'chapterNumber': 1},
      ];
    } else if (path.endsWith('/chapter/1')) {
      data = {'pageCount': 2};
    } else {
      data = {
        'id': 7,
        'title': 'Native bridge comic',
        'genre': ['Test'],
      };
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  });
  try {
    await check('suwayomi-search-details-pages-and-authentication', () async {
      final sources = SuwayomiRemoteSource.parse(
        await loadSourceText(server.resolve('api/v1/source/list')),
      );
      final template = await rootBundle.loadString(
        'assets/sources/suwayomi.js',
      );
      final remote = sources.single;
      final source = await ComicSourceManager().install(
        buildSuwayomiScript(template, server, remote),
        'suwayomi-fixture.js',
        initialize: false,
      );
      source.data['bridgeAuthorization'] = 'Basic dGVzdDp0ZXN0';
      final result = await JsEngine().runCode(
        'ComicSource.sources.${source.key}.search.load("test", [], 1)',
      );
      require(
        result['comics'][0]['id'] == '7',
        'Bridge search result could not be read',
      );
      final details = await source.loadComicInfo!('7');
      require(
        !details.error && details.data.title == 'Native bridge comic',
        'Bridge details failed',
      );
      final pages = await source.loadComicPages!('7', '1');
      require(
        !pages.error &&
            pages.data.length == 2 &&
            pages.data.first.endsWith('/page/0'),
        'Bridge page mapping failed',
      );
      final image = await source.getImageLoadingConfig!(
        '${server}api/v1/manga/7/thumbnail',
        '7',
        '1',
      );
      require(
        image['headers']['Authorization'] == 'Basic dGVzdDp0ZXN0',
        'Image authentication missing',
      );
      final external = await source.getImageLoadingConfig!(
        'https://outside.example/image.png',
        '7',
        '1',
      );
      require(
        (external['headers'] as Map).isEmpty,
        'Credentials escaped the server origin',
      );
      require(
        receivedHeaders
            .skip(1)
            .every((header) => header == 'Basic dGVzdDp0ZXN0'),
        'API authentication missing',
      );
    });
  } finally {
    await mock.close(force: true);
  }

  if (Platform.environment['ZEITLIND_VERIFY_LIVE'] != '0') {
    await check('audited-basic-sources-bootstrap', () async {
      final result = await const StarterSourceInstaller(loadSourceText).run(
        isInstalled: (spec) => ComicSource.find(spec.key) != null,
        install: (spec, script) async {
          await ComicSourceManager().install(
            script,
            '${spec.key}.js',
            expectedKey: spec.key,
            initialize: false,
          );
        },
      );
      require(
        result.errors.isEmpty &&
            result.completed.length == starterSources.length,
        'Basic source setup failed: ${result.errors}',
      );
    });
    for (final directory in [
      SourceCatalogPresets.direct,
      'https://cdn.jsdelivr.net/gh/kuiti/manga-source-index@main/05-venera-sources/tier1/index.json',
    ]) {
      var entries = <SourceCatalogEntry>[];
      await check('directory:$directory', () async {
        entries = await const SourceCatalogRepository(
          loadSourceText,
        ).load(directory);
        require(entries.isNotEmpty, 'Directory is empty');
      });
      for (final entry in entries) {
        await check('native-install:${entry.key}:$directory', () async {
          final content = await loadSourceText(entry.scriptUri);
          final source = await ComicSourceManager().install(
            content,
            '${entry.key}.js',
            expectedKey: entry.key,
            replacing: ComicSource.find(entry.key),
            initialize: false,
            websiteIdentity: entry.websiteIdentity,
          );
          require(
            source.key == entry.key && await File(source.filePath).exists(),
            'The native source was not committed',
          );
        });
      }
    }
  }
  final report = {
    'platform': Platform.operatingSystem,
    'version': App.version,
    'scope':
        'Native script import, settings persistence, update rollback and Suwayomi REST fixture. Live scripts are parsed with initialization disabled; actual websites are not read.',
    'profile': profile.path,
    'passed': checks.every((item) => item['passed'] == true),
    'checks': checks,
  };
  JsEngine().dispose();
  return report;
}
