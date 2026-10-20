import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/source_preferences.dart';

void main() {
  test('native is the default and never silently replaced with a mirror', () {
    for (final selected in [null, '', ...SourceCatalogPresets.defaults]) {
      final result = SourceDirectoryPreferences.migrate(selected, []);
      expect(result.selected, SourceCatalogPresets.native);
      expect(result.repositories.first, SourceCatalogPresets.native);
      expect(
        result.repositories.toSet(),
        containsAll(SourceCatalogPresets.defaults),
      );
    }
  });
  test('custom selection and saved repositories survive migration', () {
    const custom = 'https://example.org/private/index.json?token=mine';
    final result = SourceDirectoryPreferences.migrate(custom, [
      custom,
      ' ',
      custom,
      SourceCatalogPresets.native,
    ]);
    expect(result.selected, custom);
    expect(result.repositories.where((item) => item == custom).length, 1);
    expect(
      result.repositories
          .where((item) => item == SourceCatalogPresets.native)
          .length,
      1,
    );
  });
  test('migration is idempotent and malformed saved values are ignored', () {
    final first = SourceDirectoryPreferences.migrate(null, [
      null,
      1,
      '',
      SourceCatalogPresets.native,
    ]);
    final second = SourceDirectoryPreferences.migrate(
      first.selected,
      first.repositories,
    );
    expect(second.selected, first.selected);
    expect(second.repositories, first.repositories);
    expect(
      SourceDirectoryPreferences.migrate(null, 'invalid').repositories,
      SourceCatalogPresets.defaults,
    );
  });
  test('native source filenames resolve on the original host and branch', () {
    final source = parseSourceCatalog(
      '[{"name":"Native","key":"native","version":"1.0.0","fileName":"source.js"}]',
      Uri.parse(SourceCatalogPresets.native),
    ).single;
    expect(
      source.scriptUri.toString(),
      'https://git.nyne.dev/nyne/venera-configs/raw/branch/main/source.js',
    );
    expect(sourceFallbackUris(source.scriptUri), [source.scriptUri]);
  });
}
