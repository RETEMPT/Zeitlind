import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/data/source_catalog_repository.dart';
import 'package:zeitlind/features/sources/presentation/source_catalog_view.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/utils/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTranslation.init();
    appdata.settings['language'] = 'en-US';
  });
  testWidgets(
    'directory search and self-hosted filter work on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = jsonEncode([
        {
          'name': 'Komga',
          'key': 'komga',
          'version': '1.0.0',
          'fileName': 'komga.js',
        },
        {
          'name': 'Other source',
          'key': 'other',
          'version': '1.0.0',
          'fileName': 'other.js',
        },
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SourceCatalogView(
              repository: SourceCatalogRepository((_) async => json),
              onDirectoryLoaded: (_) async {},
              onInstall: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Komga'), findsOneWidget);
      await tester.tap(find.text('Self-hosted'));
      await tester.pumpAndSettle();
      expect(find.text('Other source'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching sources'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
