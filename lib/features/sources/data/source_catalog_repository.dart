import '../domain/source_catalog.dart';

typedef SourceTextLoader = Future<String> Function(Uri uri);

/// Transport is injected so directory parsing can be tested without networking.
class SourceCatalogRepository {
  const SourceCatalogRepository(this.loadText);

  final SourceTextLoader loadText;

  Future<List<SourceCatalogEntry>> load(String address) async {
    final uri = sourceHttpUri(address);
    final content = await loadText(uri).timeout(const Duration(seconds: 45));
    return parseSourceCatalog(content, uri);
  }
}
