import 'source_catalog.dart';

class SourceDirectoryPreferences {
  const SourceDirectoryPreferences(this.selected, this.repositories);
  final String selected;
  final List<String> repositories;

  /// Move built-in defaults to the native directory while preserving custom URLs.
  factory SourceDirectoryPreferences.migrate(dynamic selected, dynamic saved) {
    final previous = selected is String ? selected.trim() : '';
    final address =
        previous.isEmpty || SourceCatalogPresets.defaults.contains(previous)
        ? SourceCatalogPresets.native
        : previous;
    final repositories = <String>{
      SourceCatalogPresets.native,
      address,
      if (saved is List)
        ...saved
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      ...SourceCatalogPresets.defaults,
    }.take(12).toList();
    return SourceDirectoryPreferences(address, repositories);
  }
}
