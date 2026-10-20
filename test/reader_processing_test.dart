import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/reader/application/image_processing_result.dart';

void main() {
  final original = Uint8List.fromList([1]);
  final processed = Uint8List.fromList([2]);

  test('supports synchronous, async, and async wrapped results', () async {
    for (final result in [
      processed,
      Future.value(processed),
      {'image': processed},
      Future.value({'image': Future.value(processed)}),
    ]) {
      expect(await resolveProcessedImage(result, original, () {}), processed);
    }
  });

  test(
    'a rejected image promise reports failure instead of waiting forever',
    () async {
      final image = Completer<Uint8List>();
      final result = resolveProcessedImage(
        {'image': image.future, 'onCancel': () {}},
        original,
        () {},
      );
      final expectation = expectLater(
        result.timeout(const Duration(seconds: 1)),
        throwsStateError,
      );
      image.completeError(StateError('processing failed'));
      await expectation;
    },
  );

  test('cancelling a pending processor invokes cancellation once', () async {
    var calls = 0;
    final result = resolveProcessedImage(
      {'image': Completer<Uint8List>().future, 'onCancel': 'cancel'},
      original,
      () => throw StateError('reader closed'),
      invokeCancel: (callback) {
        expect(callback, 'cancel');
        calls++;
      },
    );
    await expectLater(
      result.timeout(const Duration(seconds: 1)),
      throwsStateError,
    );
    expect(calls, 1);
  });

  test('unsupported return values preserve the original bytes', () async {
    expect(await resolveProcessedImage(null, original, () {}), same(original));
    expect(
      await resolveProcessedImage(
        {'image': Future.value(null)},
        original,
        () {},
      ),
      same(original),
    );
  });
}
