import 'package:zeitlind/app/theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/features/library/presentation/library_dashboard.dart';
import 'package:zeitlind/utils/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTranslation.init();
    appdata.settings['language'] = 'en-US';
    if (const bool.fromEnvironment('ZEITLIND_CAPTURE_PREVIEW') &&
        Platform.isWindows) {
      final loader = FontLoader('ZeitlindPreview');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/msyh.ttc').readAsBytes(),
          ),
        ),
      );
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final (width, scale) in [(360.0, 1.0), (360.0, 2.0), (900.0, 1.0)]) {
    testWidgets('home actions fit a $width wide display at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = const bool.fromEnvironment('ZEITLIND_CAPTURE_PREVIEW');
      appdata.settings['language'] = capture ? 'zh-CN' : 'en-US';
      var searches = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ZeitlindTheme.create(
            fontFamily: capture ? 'ZeitlindPreview' : null,
          ),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: const ValueKey('dashboard-preview'),
                  child: Material(
                    child: LibraryDashboard(
                      sourceCount: 0,
                      onSearch: () => searches++,
                      onSources: () {},
                      onLocal: () {},
                      onDownloads: () {},
                      onHistory: () {},
                      onSettings: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Search all your sources'.tl));
      expect(searches, 1);
      // Optional reproducible preview; no golden files tied to a host font.
      if (const bool.fromEnvironment('ZEITLIND_CAPTURE_PREVIEW') &&
          scale == 1.0 &&
          width == 360) {
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('dashboard-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/previews').create(recursive: true);
          await File(
            'build/previews/zeitlind-home.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
