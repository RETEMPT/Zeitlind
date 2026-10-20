library;

import 'dart:async';
import 'package:zeitlind/core/version.dart';
import 'package:zeitlind/features/sources/data/source_install_transaction.dart';
import 'package:zeitlind/features/sources/domain/source_script.dart';
import 'package:zeitlind/features/sources/domain/source_identity.dart';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/comic_type.dart';
import 'package:zeitlind/foundation/history.dart';
import 'package:zeitlind/foundation/res.dart';
import 'package:zeitlind/pages/category_comics_page.dart';
import 'package:zeitlind/pages/search_result_page.dart';
import 'package:zeitlind/utils/data_sync.dart';
import 'package:zeitlind/utils/ext.dart';
import 'package:zeitlind/utils/init.dart';
import 'package:zeitlind/utils/io.dart';
import 'package:zeitlind/utils/translations.dart';

import '../js_engine.dart';
import '../log.dart';

part 'category.dart';

part 'favorites.dart';

part 'parser.dart';

part 'models.dart';

part 'types.dart';

class ComicSourceManager with ChangeNotifier, Init {
  final List<ComicSource> _sources = [];
  final Map<String, String> _aliases = {};

  static ComicSourceManager? _instance;

  ComicSourceManager._create();

  factory ComicSourceManager() => _instance ??= ComicSourceManager._create();

  List<ComicSource> all() => List.from(_sources);

  ComicSource? find(String key) => _sources.firstWhereOrNull(
    (element) => element.key == key || element.key == _aliases[key],
  );

  ComicSource? fromIntKey(int key) =>
      _sources.firstWhereOrNull((element) => element.key.hashCode == key) ??
      find(
        _aliases.keys.toList().firstWhereOrNull(
              (alias) => alias.hashCode == key,
            ) ??
            '',
      );

  ComicSource? findWebsite(String identity) =>
      _sources.firstWhereOrNull((source) => source.websiteIdentity == identity);

  Future<void> _saveAliases() async {
    await File(
      '${App.dataPath}/comic_source/aliases.json',
    ).writeAsString(jsonEncode(_aliases));
  }

  @override
  @protected
  Future<void> doInit() async {
    await JsEngine().ensureInit();
    final path = "${App.dataPath}/comic_source";
    if (!(await Directory(path).exists())) {
      Directory(path).create();
      return;
    }
    final aliasFile = File('$path/aliases.json');
    if (await aliasFile.exists()) {
      try {
        _aliases.addAll(
          Map<String, String>.from(jsonDecode(await aliasFile.readAsString())),
        );
      } catch (e) {
        Log.error('Source aliases', e);
      }
    }
    final files = await Directory(path).list().toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (var entity in files) {
      if (entity is File && entity.path.endsWith(".js")) {
        try {
          final content = await entity.readAsString();
          var source = await ComicSourceParser().parse(
            content,
            entity.absolute.path,
            initialize: false,
          );
          source.data.putIfAbsent(
            '_zeitlindWebsite',
            () => sourceWebsiteIdentity(source.key, scriptWebsite(content)),
          );
          final existing = findWebsite(source.websiteIdentity);
          if (existing != null) {
            _aliases[source.key] = existing.key;
            await entity.rename('${entity.path}.duplicate');
            await _saveAliases();
            continue;
          }
          _sources.add(source);
          unawaited(_initializeSource(source));
        } catch (e, s) {
          Log.error("ComicSource", "$e\n$s");
        }
      }
    }
    for (final alias in _aliases.entries) {
      if (find(alias.value) != null) {
        JsEngine().runCode(
          'void (ComicSource.sources[${jsonEncode(alias.key)}] = ComicSource.sources[${jsonEncode(alias.value)}]);',
        );
      }
    }
  }

  Future reload() async {
    _sources.clear();
    _aliases.clear();
    JsEngine().runCode("ComicSource.sources = {};");
    await doInit();
    notifyListeners();
  }

  Future<void> _mutation = Future.value();

  /// Serialize script mutations and commit the file only after validation.
  /// A failed update restores the previous JS objects and keeps the old source.
  Future<ComicSource> install(
    String script,
    String fileName, {
    String? expectedKey,
    ComicSource? replacing,
    bool initialize = true,
    String? websiteIdentity,
  }) {
    final result = _mutation.then((_) async {
      if (replacing != null && find(replacing.key) != replacing) {
        throw StateError('Source changed. Please refresh and retry.');
      }
      final safeName = fileName
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final directory = Directory(FilePath.join(App.dataPath, 'comic_source'));
      await directory.create(recursive: true);
      var file = File(
        replacing?.filePath ??
            FilePath.join(
              directory.path,
              safeName.endsWith('.js') ? safeName : '$safeName.js',
            ),
      );
      if (replacing == null) {
        var index = 1;
        final original = file.path;
        while (await file.exists()) {
          file = File(
            '${original.substring(0, original.length - 3)}_${index++}.js',
          );
        }
      }
      final source = await const SourceInstallTransaction().run(
        destination: file,
        script: script,
        snapshot: () => JsEngine().runCode(
          'void (this.__zeitlindSources = Object.assign({}, ComicSource.sources));',
        ),
        restore: () => JsEngine().runCode(
          'void (ComicSource.sources = this.__zeitlindSources);',
        ),
        release: () => JsEngine().runCode('delete this.__zeitlindSources;'),
        parse: () async {
          final source = await ComicSourceParser().parse(
            script,
            file.path,
            replacingKey: replacing?.key,
            expectedKey: expectedKey ?? replacing?.key,
            initialize: false,
          );
          source.data['_zeitlindWebsite'] = resolveSourceWebsiteIdentity(
            source.key,
            script,
            supplied: websiteIdentity,
            previous: source.data['_zeitlindWebsite'] as String?,
          );
          final existing = findWebsite(source.websiteIdentity);
          if (existing != null && existing.key != source.key) {
            throw const FormatException(
              'A source for this website is already installed',
            );
          }
          return source;
        },
      );
      if (replacing != null) _sources.remove(replacing);
      _sources.add(source);
      for (final alias in _aliases.entries.where(
        (entry) => entry.value == source.key,
      )) {
        JsEngine().runCode(
          'void (ComicSource.sources[${jsonEncode(alias.key)}] = ComicSource.sources[${jsonEncode(source.key)}]);',
        );
      }
      try {
        await source.saveData();
      } catch (e, s) {
        Log.error('Source metadata', e, s);
      }
      _availableUpdates.remove(source.key);
      notifyListeners();
      if (initialize) {
        await _initializeSource(source);
      }
      return source;
    });
    _mutation = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<void> _initializeSource(ComicSource source) async {
    try {
      await Future.sync(
        () => JsEngine().runCode('ComicSource.sources.${source.key}.init?.();'),
      ).timeout(const Duration(seconds: 30));
    } catch (e, s) {
      Log.error('ComicSource init', e, s);
    }
  }

  void add(ComicSource source) {
    _sources.add(source);
    notifyListeners();
  }

  void remove(String key) {
    _sources.removeWhere((element) => element.key == key);
    _availableUpdates.remove(key);
    final aliases = _aliases.entries
        .where((entry) => entry.value == key)
        .map((entry) => entry.key)
        .toList();
    for (final alias in aliases) {
      _aliases.remove(alias);
      JsEngine().runCode('delete ComicSource.sources[${jsonEncode(alias)}];');
    }
    unawaited(
      _saveAliases().catchError((Object error) {
        Log.error('Source aliases', error);
      }),
    );
    if (RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) {
      JsEngine().runCode('delete ComicSource.sources.$key;');
    }
    notifyListeners();
  }

  bool get isEmpty => _sources.isEmpty;

  /// Key is the source key, value is the version.
  final _availableUpdates = <String, String>{};

  void updateAvailableUpdates(Map<String, String> updates) {
    _availableUpdates.clear();
    _availableUpdates.addAll(updates);
    notifyListeners();
  }

  Map<String, String> get availableUpdates => Map.from(_availableUpdates);

  void notifyStateChange() {
    notifyListeners();
  }
}

class ComicSource {
  String get websiteIdentity => data['_zeitlindWebsite'] is String
      ? data['_zeitlindWebsite'] as String
      : sourceWebsiteIdentity(key);
  static List<ComicSource> all() => ComicSourceManager().all();

  static ComicSource? find(String key) => ComicSourceManager().find(key);

  static ComicSource? fromIntKey(int key) =>
      ComicSourceManager().fromIntKey(key);

  static bool get isEmpty => ComicSourceManager().isEmpty;

  /// Name of this source.
  final String name;

  /// Identifier of this source.
  final String key;

  int get intKey {
    return key.hashCode;
  }

  /// Account config.
  final AccountConfig? account;

  /// Category data used to build a static category tags page.
  final CategoryData? categoryData;

  /// Category comics data used to build a comics page with a category tag.
  final CategoryComicsData? categoryComicsData;

  /// Favorite data used to build favorite page.
  final FavoriteData? favoriteData;

  /// Explore pages.
  final List<ExplorePageData> explorePages;

  /// Search page.
  final SearchPageData? searchPageData;

  /// Load comic info.
  final LoadComicFunc? loadComicInfo;

  final ComicThumbnailLoader? loadComicThumbnail;

  /// Load comic pages.
  final LoadComicPagesFunc? loadComicPages;

  final GetImageLoadingConfigFunc? getImageLoadingConfig;

  final Map<String, dynamic> Function(String imageKey)?
  getThumbnailLoadingConfig;

  var data = <String, dynamic>{};

  bool get isLogged => data["account"] != null;

  final String filePath;

  final String url;

  final String version;

  final CommentsLoader? commentsLoader;

  final SendCommentFunc? sendCommentFunc;

  final ChapterCommentsLoader? chapterCommentsLoader;

  final SendChapterCommentFunc? sendChapterCommentFunc;

  final RegExp? idMatcher;

  final LikeOrUnlikeComicFunc? likeOrUnlikeComic;

  final VoteCommentFunc? voteCommentFunc;

  final LikeCommentFunc? likeCommentFunc;

  final Map<String, Map<String, dynamic>>? settings;

  final Map<String, Map<String, String>>? translations;

  final HandleClickTagEvent? handleClickTagEvent;

  /// Callback when a tag suggestion is selected in search.
  final TagSuggestionSelectFunc? onTagSuggestionSelected;

  final LinkHandler? linkHandler;

  final bool enableTagsSuggestions;

  final bool enableTagsTranslate;

  final StarRatingFunc? starRatingFunc;

  final ArchiveDownloader? archiveDownloader;

  Future<void> loadData() async {
    var file = File("${App.dataPath}/comic_source/$key.data");
    if (await file.exists()) {
      data = Map.from(jsonDecode(await file.readAsString()));
    }
  }

  bool _isSaving = false;
  bool _haveWaitingTask = false;

  Future<void> saveData() async {
    if (_haveWaitingTask) return;
    while (_isSaving) {
      _haveWaitingTask = true;
      await Future.delayed(const Duration(milliseconds: 20));
      _haveWaitingTask = false;
    }
    _isSaving = true;
    try {
      var file = File("${App.dataPath}/comic_source/$key.data");
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(data));
    } finally {
      _isSaving = false;
    }
    DataSync().uploadData();
  }

  Future<bool> reLogin() async {
    if (data["account"] == null) {
      return false;
    }
    final List accountData = data["account"];
    var res = await account!.login!(accountData[0], accountData[1]);
    if (res.error) {
      Log.error("Failed to re-login", res.errorMessage ?? "Error");
    }
    return !res.error;
  }

  /// Get settings dynamically from JavaScript source.
  /// This allows sources to use getters for dynamic settings that can change at runtime.
  Map<String, Map<String, dynamic>>? getSettingsDynamic() {
    try {
      var value = JsEngine().runCode("ComicSource.sources.$key.settings");
      if (value is Map) {
        var newMap = <String, Map<String, dynamic>>{};
        for (var e in value.entries) {
          if (e.key is! String) {
            continue;
          }
          var v = <String, dynamic>{};
          for (var e2 in e.value.entries) {
            if (e2.key is! String) {
              continue;
            }
            var v2 = e2.value;
            if (v2 is JSInvokable) {
              v2 = JSAutoFreeFunction(v2);
            }
            v[e2.key] = v2;
          }
          newMap[e.key] = v;
        }
        return newMap;
      }
      return null;
    } catch (e) {
      Log.error("ComicSource", "Failed to get dynamic settings: $e");
      return settings;
    }
  }

  ComicSource(
    this.name,
    this.key,
    this.account,
    this.categoryData,
    this.categoryComicsData,
    this.favoriteData,
    this.explorePages,
    this.searchPageData,
    this.settings,
    this.loadComicInfo,
    this.loadComicThumbnail,
    this.loadComicPages,
    this.getImageLoadingConfig,
    this.getThumbnailLoadingConfig,
    this.filePath,
    this.url,
    this.version,
    this.commentsLoader,
    this.sendCommentFunc,
    this.chapterCommentsLoader,
    this.sendChapterCommentFunc,
    this.likeOrUnlikeComic,
    this.voteCommentFunc,
    this.likeCommentFunc,
    this.idMatcher,
    this.translations,
    this.handleClickTagEvent,
    this.onTagSuggestionSelected,
    this.linkHandler,
    this.enableTagsSuggestions,
    this.enableTagsTranslate,
    this.starRatingFunc,
    this.archiveDownloader,
  );
}

class AccountConfig {
  final LoginFunction? login;

  final String? loginWebsite;

  final String? registerWebsite;

  final void Function() logout;

  final List<AccountInfoItem> infoItems;

  final bool Function(String url, String title)? checkLoginStatus;

  final void Function()? onLoginWithWebviewSuccess;

  final List<String>? cookieFields;

  final Future<bool> Function(List<String>)? validateCookies;

  const AccountConfig(
    this.login,
    this.loginWebsite,
    this.registerWebsite,
    this.logout,
    this.checkLoginStatus,
    this.onLoginWithWebviewSuccess,
    this.cookieFields,
    this.validateCookies,
  ) : infoItems = const [];
}

class AccountInfoItem {
  final String title;
  final String Function()? data;
  final void Function()? onTap;
  final WidgetBuilder? builder;

  AccountInfoItem({required this.title, this.data, this.onTap, this.builder});
}

class LoadImageRequest {
  String url;

  Map<String, String> headers;

  LoadImageRequest(this.url, this.headers);
}

class ExplorePageData {
  final String title;

  final ExplorePageType type;

  final ComicListBuilder? loadPage;

  final ComicListBuilderWithNext? loadNext;

  final Future<Res<List<ExplorePagePart>>> Function()? loadMultiPart;

  /// return a `List` contains `List<Comic>` or `ExplorePagePart`
  final Future<Res<List<Object>>> Function(int index)? loadMixed;

  ExplorePageData(
    this.title,
    this.type,
    this.loadPage,
    this.loadNext,
    this.loadMultiPart,
    this.loadMixed,
  );
}

class ExplorePagePart {
  final String title;

  final List<Comic> comics;

  /// If this is not null, the [ExplorePagePart] will show a button to jump to new page.
  ///
  /// Value of this field should match the following format:
  ///   - search:keyword
  ///   - category:categoryName
  ///
  /// End with `@`+`param` if the category has a parameter.
  final PageJumpTarget? viewMore;

  const ExplorePagePart(this.title, this.comics, this.viewMore);
}

enum ExplorePageType {
  multiPageComicList,
  singlePageWithMultiPart,
  mixed,
  override,
}

typedef SearchFunction =
    Future<Res<List<Comic>>> Function(
      String keyword,
      int page,
      List<String> searchOption,
    );

typedef SearchNextFunction =
    Future<Res<List<Comic>>> Function(
      String keyword,
      String? next,
      List<String> searchOption,
    );

class SearchPageData {
  /// If this is not null, the default value of search options will be first element.
  final List<SearchOptions>? searchOptions;

  final SearchFunction? loadPage;

  final SearchNextFunction? loadNext;

  const SearchPageData(this.searchOptions, this.loadPage, this.loadNext);
}

class SearchOptions {
  final LinkedHashMap<String, String> options;

  final String label;

  final String type;

  final String? defaultVal;

  const SearchOptions(this.options, this.label, this.type, this.defaultVal);

  String get defaultValue => defaultVal ?? options.keys.firstOrNull ?? "";
}

typedef CategoryComicsLoader =
    Future<Res<List<Comic>>> Function(
      String category,
      String? param,
      List<String> options,
      int page,
    );

typedef CategoryOptionsLoader =
    Future<Res<List<CategoryComicsOptions>>> Function(
      String category,
      String? param,
    );

class CategoryComicsData {
  /// options
  final List<CategoryComicsOptions>? options;

  final CategoryOptionsLoader? optionsLoader;

  /// [category] is the one clicked by the user on the category page.
  ///
  /// if [BaseCategoryPart.categoryParams] is not null, [param] will be not null.
  ///
  /// [Res.subData] should be maxPage or null if there is no limit.
  final CategoryComicsLoader load;

  final RankingData? rankingData;

  const CategoryComicsData({
    this.options,
    this.optionsLoader,
    required this.load,
    this.rankingData,
  });
}

class RankingData {
  final Map<String, String> options;

  final Future<Res<List<Comic>>> Function(String option, int page)? load;

  final Future<Res<List<Comic>>> Function(String option, String? next)?
  loadWithNext;

  const RankingData(this.options, this.load, this.loadWithNext);
}

class CategoryComicsOptions {
  // The label will not be displayed if it is empty.
  final String label;

  /// Use a [LinkedHashMap] to describe an option list.
  /// key is for loading comics, value is the name displayed on screen.
  /// Default value will be the first of the Map.
  final LinkedHashMap<String, String> options;

  /// If [notShowWhen] contains category's name, the option will not be shown.
  final List<String> notShowWhen;

  final List<String>? showWhen;

  const CategoryComicsOptions(
    this.label,
    this.options,
    this.notShowWhen,
    this.showWhen,
  );
}

class LinkHandler {
  final List<String> domains;

  final String? Function(String url) linkToId;

  const LinkHandler(this.domains, this.linkToId);
}

class ArchiveDownloader {
  final Future<Res<List<ArchiveInfo>>> Function(String cid) getArchives;

  final Future<Res<String>> Function(String cid, String aid) getDownloadUrl;

  const ArchiveDownloader(this.getArchives, this.getDownloadUrl);
}
