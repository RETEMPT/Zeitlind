import 'dart:io';

/// Replace the final script only after parsing and durable staging succeed.
class SourceInstallTransaction {
  const SourceInstallTransaction();

  Future<T> run<T>({
    required File destination,
    required String script,
    required Future<T> Function() parse,
    required void Function() snapshot,
    required void Function() restore,
    required void Function() release,
  }) async {
    final pending = File('${destination.path}.pending');
    snapshot();
    try {
      await pending.writeAsString(script, flush: true);
      final result = await parse();
      await pending.rename(destination.path);
      return result;
    } catch (_) {
      restore();
      rethrow;
    } finally {
      release();
      if (await pending.exists()) await pending.delete();
    }
  }
}
