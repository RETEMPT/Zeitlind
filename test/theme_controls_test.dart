import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/app/theme.dart';
import 'package:zeitlind/features/appearance/domain/theme_tuning.dart';
import 'package:zeitlind/features/appearance/presentation/theme_tuning_controls.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/utils/translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTranslation.init();
    appdata.settings['language'] = 'en-US';
  });
  testWidgets(
    'background slider commits a value without replacing the accent choice',
    (tester) async {
      var tuning = const ThemeTuning();
      ThemeTuning? committed;
      bool? changesAccent;
      await tester.pumpWidget(
        MaterialApp(
          theme: ZeitlindTheme.create(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ThemeTuningControls(
                value: tuning,
                onChanged: (value) => setState(() => tuning = value),
                onCommit: (value, accent) {
                  committed = value;
                  changesAccent = accent;
                },
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(Slider).last, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(committed, isNotNull);
      expect(committed!.surfaceTint, greaterThan(.12));
      expect(changesAccent, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
