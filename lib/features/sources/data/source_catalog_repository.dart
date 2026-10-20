import '../domain/source_catalog.dart';
import '../domain/source_import.dart';
import 'package:zeitlind/core/version.dart';

typedef SourceTextLoader = Future<String> Function(Uri uri);

/// Transport is injected so directory parsing can be tested without networking.
class SourceCatalogRepository {
  const SourceCatalogRepository(this.loadText);

  final SourceTextLoader loadText;

  Future<List<SourceCatalogEntry>> loadMany(Iterable<String> addresses) async {
    final merged = <String, SourceCatalogEntry>{};
    final failures = <Object>[];
    var succeeded = 0;
    final unique = addresses.toSet().toList();
    for (var start = 0; start < unique.length; start += 3) {
      await Future.wait(
        unique.skip(start).take(3).map((address) async {
          try {
            final entries = await load(address);
            succeeded++;
            for (final entry in entries) {
              final previous = merged[entry.key];
              if (previous == null ||
                  compareVersions(entry.version, previous.version) > 0) {
                merged[entry.key] = entry;
              }
            }
          } catch (e) {
            failures.add(e);
          }
        }),
      );
    }
    if (succeeded == 0) {
      throw StateError(
        'No source directory could be loaded: ${failures.join('; ')}',
      );
    }
    return deduplicateSourceCatalog(merged.values);
  }

  Future<List<SourceCatalogEntry>> load(String address) async {
    final uri = sourceImportUri(address);
    final content = await loadText(uri).timeout(const Duration(seconds: 45));
    final document = SourceImportDocument.parse(content, origin: uri);
    if (document.kind == SourceImportKind.mihonRepository) {
      throw const FormatException(
        'Use Suwayomi to connect a Mihon extension repository',
      );
    }
    if (document.kind != SourceImportKind.directory) {
      throw const FormatException(
        'This link is a script. Import it from Add comic source',
      );
    }
    return document.entries;
  }
}
