import 'package:flutter/services.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/pages/aggregated_search_page.dart';
import 'package:zeitlind/pages/comic_source_page.dart';
import 'package:zeitlind/features/sources/domain/source_import.dart';

bool _isHandling = false;

/// Handle text share event.
/// App will navigate to [AggregatedSearchPage] with the shared text as keyword.
void handleTextShare() async {
  if (_isHandling) return;
  _isHandling = true;

  var channel = EventChannel('zeitlind/text_share');
  await for (var event in channel.receiveBroadcastStream()) {
    if (App.mainNavigatorKey == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (event is String) {
      try {
        final uri = sourceImportUri(event);
        if (RegExp(
          r'\.(js|json|pb|apk)$',
          caseSensitive: false,
        ).hasMatch(uri.path)) {
          App.rootContext.to(() => ComicSourcePage(initialInput: event));
          continue;
        }
      } on FormatException {
        // Other shared text continues to global comic search.
      }
      App.rootContext.to(() => AggregatedSearchPage(keyword: event));
    }
  }
}
