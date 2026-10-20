import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/reader/domain/reading_preset.dart';

void main() {
  test('webtoon preset clears double-page settings when switching modes', () {
    final settings = <String, dynamic>{'readerScreenPicNumberForLandscape': 2};
    settings.addAll(ReadingPreset.webtoon.settings);
    expect(settings['readerMode'], 'continuousTopToBottom');
    expect(settings['readerScreenPicNumberForLandscape'], 1);
  });
  test(
    'manga uses right-to-left pagination and does not reset unrelated settings',
    () {
      final settings = <String, dynamic>{'enableTapToTurnPages': false};
      settings.addAll(ReadingPreset.manga.settings);
      expect(settings['readerMode'], 'galleryRightToLeft');
      expect(settings['enableTapToTurnPages'], isFalse);
    },
  );
}
