import 'dart:async';

import 'package:display_mode/display_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:rhttp/rhttp.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/cache_manager.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/foundation/js_engine.dart';
import 'package:zeitlind/foundation/log.dart';
import 'package:zeitlind/network/cookie_jar.dart';
import 'package:zeitlind/pages/comic_source_page.dart';
import 'package:zeitlind/pages/follow_updates_page.dart';
import 'package:zeitlind/pages/settings/settings_page.dart';
import 'package:zeitlind/utils/app_links.dart';
import 'package:zeitlind/utils/handle_text_share.dart';
import 'package:zeitlind/utils/opencc.dart';
import 'package:zeitlind/utils/tags_translation.dart';
import 'package:zeitlind/utils/translations.dart';
import 'foundation/appdata.dart';
import 'features/sources/domain/source_preferences.dart';

extension _FutureInit<T> on Future<T> {
  /// Prevent unhandled exception
  ///
  /// A unhandled exception occurred in init() will cause the app to crash.
  Future<void> wait() async {
    try {
      await this;
    } catch (e, s) {
      Log.error("init", "$e\n$s");
    }
  }
}

Future<void> init() async {
  await App.init().wait();
  await SingleInstanceCookieJar.createInstance();
  try {
    var futures = [
      Rhttp.init(),
      App.initComponents(),
      SAFTaskWorker().init().wait(),
      AppTranslation.init().wait(),
      TagsTranslation.readData().wait(),
      JsEngine().init().wait(),
      ComicSourceManager().init().wait(),
      OpenCC.init(),
    ];
    await Future.wait(futures);
  } catch (e, s) {
    Log.error("init", "$e\n$s");
  }
  CacheManager().setLimitSize(appdata.settings['cacheSize']);
  await _checkOldConfigs();
  if (App.isAndroid) {
    handleLinks();
    handleTextShare();
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      Log.error("Display Mode", "Failed to set high refresh rate: $e");
    }
  }
  FlutterError.onError = (details) {
    Log.error("Unhandled Exception", "${details.exception}\n${details.stack}");
  };
  if (App.isWindows) {
    // Report to the monitor thread that the app is running
    // https://github.com/venera-app/venera/issues/343
    Timer.periodic(const Duration(seconds: 1), (_) {
      const methodChannel = MethodChannel('zeitlind/method_channel');
      methodChannel.invokeMethod("heartBeat");
    });
  }
}

Future<void> _checkOldConfigs() async {
  if (appdata.implicitData['neutralPaletteMigration'] != true) {
    if (appdata.settings['color'] == 'green' &&
        appdata.settings['customThemeHue'] == 150.0 &&
        appdata.settings['customThemeSaturation'] == .26 &&
        appdata.settings['themeSurfaceTint'] == .12) {
      appdata.settings['color'] = 'monochrome';
      appdata.settings['themeSurfaceTint'] = 0.0;
      appdata.saveData();
    }
    appdata.implicitData['neutralPaletteMigration'] = true;
    appdata.writeImplicitData();
  }
  if (appdata.settings['searchSources'] == null) {
    appdata.settings['searchSources'] = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
  }

  if (appdata.implicitData['webdavAutoSync'] == null) {
    var webdavConfig = appdata.settings['webdav'];
    if (webdavConfig is List &&
        webdavConfig.length == 3 &&
        webdavConfig.whereType<String>().length == 3) {
      appdata.implicitData['webdavAutoSync'] = true;
    } else {
      appdata.implicitData['webdavAutoSync'] = false;
    }
    appdata.writeImplicitData();
  }

  if (appdata.implicitData['nativeSourceDirectoryMigration'] != true) {
    final preferences = SourceDirectoryPreferences.migrate(
      appdata.settings['comicSourceListUrl'],
      appdata.settings['comicSourceRepositories'],
    );
    appdata.settings['comicSourceListUrl'] = preferences.selected;
    appdata.settings['comicSourceRepositories'] = preferences.repositories;
    try {
      await appdata.saveData();
      appdata.implicitData['nativeSourceDirectoryMigration'] = true;
      await appdata.writeImplicitData();
    } catch (e, s) {
      Log.error('Source directory migration', e, s);
    }
  }
}

Future<void> _checkAppUpdates() async {
  var lastCheck = appdata.implicitData['lastCheckUpdate'] ?? 0;
  var now = DateTime.now().millisecondsSinceEpoch;
  if (now - lastCheck < 24 * 60 * 60 * 1000) {
    return;
  }
  appdata.implicitData['lastCheckUpdate'] = now;
  appdata.writeImplicitData();
  try {
    await ComicSourcePage.checkComicSourceUpdate();
  } catch (e, s) {
    Log.error('Source updates', e, s);
  }
  if (appdata.settings['checkUpdateOnStart']) {
    await checkUpdateUi(false, true);
  }
}

void checkUpdates() {
  _checkAppUpdates();
  FollowUpdatesService.initChecker();
}
