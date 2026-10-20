import '../domain/source_catalog.dart';
import '../domain/source_diagnostics.dart';
import 'source_catalog_repository.dart';

/// Failover is scoped to the same path in the known community repository.
class ResilientSourceLoader {
  const ResilientSourceLoader(this.request);
  final SourceTextLoader request;

  Future<SourceTextResponse> load(Uri uri) async {
    final errors = <String>[];
    for (final candidate in sourceFallbackUris(uri)) {
      try {
        final text = await request(
          candidate,
        ).timeout(const Duration(seconds: 20));
        if (text.trim().isEmpty ||
            text.trimLeft().toLowerCase().startsWith('<!doctype html') ||
            text.trimLeft().toLowerCase().startsWith('<html')) {
          throw const FormatException(
            'The link returned an empty or HTML response',
          );
        }
        return SourceTextResponse(text, candidate);
      } catch (e) {
        errors.add('${candidate.host}: $e');
      }
    }
    throw StateError(errors.join('\n'));
  }
}
