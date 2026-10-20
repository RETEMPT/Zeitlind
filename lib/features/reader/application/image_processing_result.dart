import 'dart:async';
import 'dart:typed_data';

/// Resolve the plugin's sync, async and cancellable image result consistently.
Future<Uint8List> resolveProcessedImage(
  dynamic result,
  Uint8List original,
  void Function() checkStop, {
  void Function(dynamic callback)? invokeCancel,
}) async {
  if (result is Future) result = await result;
  if (result is Uint8List) return result;
  if (result is! Map) return original;
  final image = result['image'];
  if (image is Uint8List) return image;
  if (image is! Future) return original;
  final cancelled = Completer<Uint8List>();
  final timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
    try {
      checkStop();
    } catch (e, stack) {
      if (!cancelled.isCompleted) {
        try {
          invokeCancel?.call(result['onCancel']);
        } catch (_) {
          // Cancellation errors must not hide the original stop signal.
        } finally {
          cancelled.completeError(e, stack);
        }
      }
    }
  });
  try {
    return await Future.any<Uint8List>([
      image.then<Uint8List>((value) => value is Uint8List ? value : original),
      cancelled.future,
    ]);
  } finally {
    timer.cancel();
  }
}
