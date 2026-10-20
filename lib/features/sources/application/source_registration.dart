import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';

void registerSourcePages(ComicSource source) {
  void add(String key, Iterable<String> values) {
    final previous = appdata.settings[key];
    final current = previous is List
        ? previous.whereType<String>().toSet()
        : <String>{};
    current.addAll(values);
    appdata.settings[key] = current.toList();
  }

  add('explore_pages', source.explorePages.map((page) => page.title));
  add('categories', [
    if (source.categoryData != null) source.categoryData!.key,
  ]);
  add('favorites', [if (source.favoriteData != null) source.favoriteData!.key]);
  add('searchSources', [if (source.searchPageData != null) source.key]);
}
