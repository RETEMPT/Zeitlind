import 'source_catalog.dart';

class SourceTextResponse {
  const SourceTextResponse(this.content, this.uri);
  final String content;
  final Uri uri;
}

typedef SourceProbeLoader = Future<SourceTextResponse> Function(Uri uri);

enum SourceHealth { reachable, warning, failed }

class SourceProbeTarget {
  const SourceProbeTarget({
    required this.key,
    required this.name,
    required this.url,
  });
  final String key;
  final String name;
  final String url;
}

class SourceDiagnostic {
  const SourceDiagnostic({
    required this.target,
    required this.health,
    required this.message,
    required this.elapsed,
    this.resolvedUri,
  });
  final SourceProbeTarget target;
  final SourceHealth health;
  final String message;
  final Duration elapsed;
  final Uri? resolvedUri;
}

/// Checks transport and static metadata, without installing or executing code.
class SourceDiagnostics {
  const SourceDiagnostics(this.loader);
  final SourceProbeLoader loader;

  Future<SourceDiagnostic> check(SourceProbeTarget target) async {
    final stopwatch = Stopwatch()..start();
    SourceDiagnostic result(SourceHealth health, String message, [Uri? uri]) =>
        SourceDiagnostic(
          target: target,
          health: health,
          message: message,
          elapsed: stopwatch.elapsed,
          resolvedUri: uri,
        );
    try {
      final uri = sourceHttpUri(target.url);
      final response = await loader(uri).timeout(const Duration(seconds: 45));
      if (!RegExp(
        r'class\s+\w+\s+extends\s+ComicSource',
      ).hasMatch(response.content)) {
        return result(
          SourceHealth.failed,
          'The link did not return a comic source script',
          response.uri,
        );
      }
      final key = RegExp(
        r'''\bkey\s*=\s*['"]([^'"]+)['"]''',
      ).firstMatch(response.content)?.group(1);
      if (key != null && key != target.key) {
        return result(
          SourceHealth.failed,
          'Source key does not match',
          response.uri,
        );
      }
      return result(
        key == null ? SourceHealth.warning : SourceHealth.reachable,
        key == null
            ? 'Script received; dynamic metadata needs manual verification'
            : 'Script link and source key are valid; reading still needs verification',
        response.uri,
      );
    } catch (e) {
      return result(SourceHealth.failed, e.toString());
    } finally {
      stopwatch.stop();
    }
  }
}
