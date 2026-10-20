import 'package:app_links/app_links.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/pages/comic_details_page/comic_page.dart';
import 'package:zeitlind/pages/comic_source_page.dart';
import 'package:zeitlind/features/sources/domain/source_import.dart';

void handleLinks() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    handleAppLink(uri);
  });
}

Future<bool> handleAppLink(Uri uri) async {
  if (const ['zeitlind', 'venera'].contains(uri.scheme)) {
    for (
      var attempt = 0;
      attempt < 100 && App.rootNavigatorKey.currentContext == null;
      attempt++
    ) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (App.rootNavigatorKey.currentContext == null) return false;
    try {
      final address = sourceImportUri(uri.toString());
      App.rootContext.to(
        () => ComicSourcePage(initialInput: address.toString()),
      );
      return true;
    } on FormatException {
      return false;
    }
  }
  for (var source in ComicSource.all()) {
    if (source.linkHandler != null) {
      if (source.linkHandler!.domains.contains(uri.host)) {
        var id = source.linkHandler!.linkToId(uri.toString());
        if (id != null) {
          if (App.mainNavigatorKey == null) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          App.mainNavigatorKey!.currentContext?.to(() {
            return ComicPage(id: id, sourceKey: source.key);
          });
          return true;
        }
        return false;
      }
    }
  }
  return false;
}
