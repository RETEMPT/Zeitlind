import 'package:zeitlind/features/sources/data/source_catalog_repository.dart';
import 'package:zeitlind/features/sources/data/source_transport.dart';
import 'package:zeitlind/features/sources/domain/source_catalog.dart';
import 'package:zeitlind/features/sources/domain/source_import.dart';
import 'package:zeitlind/features/sources/presentation/source_catalog_view.dart';
import 'package:zeitlind/features/sources/presentation/source_diagnostics_view.dart';
import 'package:zeitlind/features/sources/presentation/source_import_error.dart';
import 'package:zeitlind/features/sources/presentation/suwayomi_connect_view.dart';
import 'package:zeitlind/features/sources/application/starter_source_setup.dart';
import 'package:zeitlind/features/sources/application/source_registration.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:zeitlind/components/components.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/foundation/log.dart';
import 'package:zeitlind/network/cookie_jar.dart';
import 'package:zeitlind/pages/webview.dart';
import 'package:zeitlind/utils/io.dart';
import 'package:zeitlind/utils/translations.dart';

class ComicSourcePage extends StatelessWidget {
  const ComicSourcePage({super.key, this.initialInput = ''});
  final String initialInput;

  static Future<void> update(
    ComicSource source, [
    bool showLoading = true,
  ]) async {
    bool cancelled = false;
    LoadingDialogController? controller;
    if (showLoading) {
      controller = showLoadingDialog(
        App.rootContext,
        onCancel: () => cancelled = true,
        barrierDismissible: false,
      );
    }
    try {
      final script = await loadSourceText(sourceHttpUri(source.url));
      if (cancelled) return;
      await ComicSourceManager().install(
        script,
        source.filePath,
        replacing: source,
      );
      _addAllPagesWithComicSource(ComicSource.find(source.key)!);
      App.forceRebuild();
    } catch (e, s) {
      Log.error('Update source', e, s);
      if (cancelled) return;
      if (!showLoading) rethrow;
      App.rootContext.showMessage(message: e.toString());
    } finally {
      controller?.close();
    }
  }

  static Future<int> checkComicSourceUpdate() async {
    if (ComicSource.all().isEmpty) return 0;
    final entries = await const SourceCatalogRepository(loadSourceText)
        .loadMany([
          appdata.settings['comicSourceListUrl'] as String,
          ...(appdata.settings['comicSourceRepositories'] as List)
              .whereType<String>(),
        ]);
    final updates = <String, String>{};
    for (final entry in entries) {
      final source = ComicSource.find(entry.key);
      if (source != null && compareSemVer(entry.version, source.version)) {
        updates[entry.key] = entry.version;
      }
    }
    ComicSourceManager().updateAvailableUpdates(updates);
    return updates.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _Body(initialInput: initialInput));
  }
}

class _Body extends StatefulWidget {
  const _Body({this.initialInput = ''});
  final String initialInput;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final input = TextEditingController(text: widget.initialInput);
  var query = '';
  bool adding = false;

  void updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ComicSourceManager().addListener(updateUI);
    starterSourceSetup.addListener(updateUI);
  }

  @override
  void dispose() {
    ComicSourceManager().removeListener(updateUI);
    starterSourceSetup.removeListener(updateUI);
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources =
        ComicSource.all()
            .where(
              (source) => '${source.name} ${source.key}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SmoothCustomScrollView(
          slivers: [
            SliverAppbar(
              title: Text('Comic Source'.tl),
              style: AppbarStyle.shadow,
            ),
            buildCard(context),
            if (ComicSource.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_stories_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No sources installed yet'.tl,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            if (!ComicSource.isEmpty)
              SliverToBoxAdapter(
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: 'Search installed sources'.tl,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ).paddingHorizontal(16).paddingVertical(8),
              ),
            for (var source in sources)
              _SliverComicSource(
                key: ValueKey(source.key),
                source: source,
                edit: edit,
                update: update,
                delete: delete,
              ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: context.padding.bottom),
            ),
          ],
        ),
      ),
    );
  }

  void delete(ComicSource source) {
    showConfirmDialog(
      context: App.rootContext,
      title: "Delete".tl,
      content: "Delete comic source '@n' ?".tlParams({"n": source.name}),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        var file = File(source.filePath);
        file.deleteSync();
        ComicSourceManager().remove(source.key);
        _validatePages();
        App.forceRebuild();
      },
    );
  }

  void edit(ComicSource source) async {
    if (App.isDesktop) {
      try {
        final result = await Process.run("code", [
          source.filePath,
        ], runInShell: true);
        if (result.exitCode != 0) throw StateError('Editor is unavailable');
        await showDialog(
          context: App.rootContext,
          builder: (context) => AlertDialog(
            title: const Text("Reload Configs"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("cancel"),
              ),
              TextButton(
                onPressed: () async {
                  await ComicSourceManager().reload();
                  App.forceRebuild();
                },
                child: const Text("continue"),
              ),
            ],
          ),
        );
        return;
      } catch (e) {
        //
      }
    }
    context.to(
      () => _EditFilePage(source.filePath, () async {
        await ComicSourceManager().reload();
        setState(() {});
      }),
    );
  }

  void update(ComicSource source, [bool showLoading = true]) {
    ComicSourcePage.update(source, showLoading);
  }

  Widget buildCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        child: Card.outlined(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text("Add comic source".tl),
                  leading: const Icon(Icons.dashboard_customize),
                ),
                TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: 3,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Source or directory URL'.tl,
                    suffixIcon: IconButton(
                      tooltip: "Add comic source".tl,
                      onPressed: adding
                          ? null
                          : () => handleAddSource(input.text),
                      icon: adding
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                    ),
                  ),
                ).paddingHorizontal(16).paddingBottom(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      icon: Icon(Icons.article_outlined),
                      label: Text("Comic Source list".tl),
                      onPressed: () {
                        openDirectory();
                      },
                    ),
                    FilledButton.tonalIcon(
                      icon: Icon(Icons.file_open_outlined),
                      label: Text("Use a config file".tl),
                      onPressed: adding ? null : _selectFile,
                    ),
                    IconButton(
                      tooltip: 'Paste'.tl,
                      icon: const Icon(Icons.content_paste),
                      onPressed: adding
                          ? null
                          : () async {
                              final data = await Clipboard.getData(
                                Clipboard.kTextPlain,
                              );
                              if (mounted && data?.text != null) {
                                input.text = data!.text!;
                              }
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.hub_outlined),
                      tooltip: 'Suwayomi',
                      onPressed: openSuwayomi,
                    ),
                    IconButton(
                      icon: Icon(Icons.help_outline),
                      tooltip: "Help".tl,
                      onPressed: help,
                    ),
                    _CheckUpdatesButton(),
                    IconButton(
                      tooltip: 'Restore default sources'.tl,
                      onPressed: starterSourceSetup.loading
                          ? null
                          : () => starterSourceSetup.configure(restore: true),
                      icon: starterSourceSetup.loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                    ),
                    IconButton(
                      icon: const Icon(Icons.health_and_safety_outlined),
                      tooltip: 'Source self-check'.tl,
                      onPressed: () => showPopUpWidget(
                        App.rootContext,
                        const SourceDiagnosticsView(),
                      ),
                    ),
                  ],
                ).paddingHorizontal(12).paddingVertical(8),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectFile() async {
    final file = await selectFile(ext: ["js", "json", "txt"]);
    if (file == null || !mounted) return;
    setState(() => adding = true);
    try {
      var fileName = file.name;
      var bytes = await file.readAsBytes();
      var content = decodeSourceBytes(bytes);
      await importContent(content, fileName);
    } catch (e, s) {
      App.rootContext.showMessage(message: sourceImportError(e));
      Log.error("Add comic source", "$e\n$s");
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  void help() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comic Source'.tl),
        content: Text(
          'Import Venera JavaScript sources or JSON source directories. Mihon APK extensions and Legado rules use different engines.'
              .tl,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text('Close'.tl)),
        ],
      ),
    );
  }

  Future<void> handleAddSource(String url) async {
    if (adding || url.trim().isEmpty) return;
    setState(() => adding = true);
    bool cancelled = false;
    final loading = showLoadingDialog(
      App.rootContext,
      onCancel: () => cancelled = true,
      barrierDismissible: false,
    );
    try {
      Uri? uri;
      var script = url;
      if (RegExp(
        r'^\s*(?:https?://|venera:|zeitlind:|\[[^\]]*\]\(https?://)',
        caseSensitive: false,
      ).hasMatch(url)) {
        uri = sourceImportUri(url);
        if (uri.path.endsWith('.apk') || uri.path.endsWith('.pb')) {
          loading.close();
          openSuwayomi(uri);
          return;
        }
        final response = await fetchSourceText(uri);
        script = response.content;
        uri = response.uri;
      }
      if (cancelled || !mounted) return;
      final fileName = uri == null || uri.pathSegments.isEmpty
          ? 'source.js'
          : uri.pathSegments.last;
      final document = SourceImportDocument.parse(script, origin: uri);
      loading.close();
      await importDocument(document, fileName);
    } catch (e, s) {
      Log.error('Add comic source', e, s);
      if (!cancelled && mounted) {
        context.showMessage(message: sourceImportError(e));
      }
    } finally {
      loading.close();
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> importContent(String content, String name) async {
    await importDocument(SourceImportDocument.parse(content), name);
  }

  Future<void> importDocument(
    SourceImportDocument document,
    String name,
  ) async {
    if (document.kind == SourceImportKind.mihonRepository) {
      openSuwayomi(document.origin);
    } else if (document.kind == SourceImportKind.directory) {
      openDirectory(document);
    } else {
      await addSource(document.content, name);
      if (mounted) context.showMessage(message: 'Success'.tl);
    }
  }

  void openDirectory([SourceImportDocument? document]) {
    showPopUpWidget(
      App.rootContext,
      SourceCatalogView(
        initialAddress: document?.origin?.toString(),
        initialEntries: document?.entries,
        onInstall: (entry) async {
          final script = await loadSourceText(entry.scriptUri);
          await addSource(
            script,
            entry.scriptUri.pathSegments.last,
            expectedKey: entry.key,
            websiteIdentity: entry.websiteIdentity,
          );
        },
      ),
      maxWidth: 900,
    );
  }

  void openSuwayomi([Uri? repositoryUri]) {
    showPopUpWidget(
      App.rootContext,
      SuwayomiConnectView(
        repositoryUri: repositoryUri,
        onInstall: (script, key, authorization, websiteIdentity) async {
          await addSource(
            script,
            '$key.js',
            expectedKey: key,
            websiteIdentity: websiteIdentity,
          );
          final source = ComicSource.find(key)!;
          source.data['bridgeAuthorization'] = authorization;
          await source.saveData();
        },
      ),
    );
  }

  Future<void> addSource(
    String js,
    String fileName, {
    String? expectedKey,
    String? websiteIdentity,
  }) async {
    final source = await ComicSourceManager().install(
      js,
      fileName,
      expectedKey: expectedKey,
      websiteIdentity: websiteIdentity,
      replacing: expectedKey == null ? null : ComicSource.find(expectedKey),
    );
    _addAllPagesWithComicSource(source);
    await appdata.saveData();
    App.forceRebuild();
  }
}

void _validatePages() {
  List explorePages = appdata.settings['explore_pages'];
  List categoryPages = appdata.settings['categories'];
  List networkFavorites = appdata.settings['favorites'];

  var totalExplorePages = ComicSource.all()
      .map((e) => e.explorePages.map((e) => e.title))
      .expand((element) => element)
      .toList();
  var totalCategoryPages = ComicSource.all()
      .map((e) => e.categoryData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
  var totalNetworkFavorites = ComicSource.all()
      .map((e) => e.favoriteData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();

  for (var page in List.from(explorePages)) {
    if (!totalExplorePages.contains(page)) {
      explorePages.remove(page);
    }
  }
  for (var page in List.from(categoryPages)) {
    if (!totalCategoryPages.contains(page)) {
      categoryPages.remove(page);
    }
  }
  for (var page in List.from(networkFavorites)) {
    if (!totalNetworkFavorites.contains(page)) {
      networkFavorites.remove(page);
    }
  }

  appdata.settings['explore_pages'] = explorePages.toSet().toList();
  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();
  appdata.settings['searchSources'] =
      (appdata.settings['searchSources'] as List)
          .where((key) => ComicSource.find(key)?.searchPageData != null)
          .toSet()
          .toList();

  appdata.saveData();
}

void _addAllPagesWithComicSource(ComicSource source) {
  registerSourcePages(source);
  appdata.saveData();
}

class _EditFilePage extends StatefulWidget {
  const _EditFilePage(this.path, this.onExit);

  final String path;

  final void Function() onExit;

  @override
  State<_EditFilePage> createState() => __EditFilePageState();
}

class __EditFilePageState extends State<_EditFilePage> {
  var current = '';

  @override
  void initState() {
    super.initState();
    current = File(widget.path).readAsStringSync();
  }

  @override
  void dispose() {
    File(widget.path).writeAsStringSync(current);
    widget.onExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text("Edit".tl)),
      body: Column(
        children: [
          Container(height: 0.6, color: context.colorScheme.outlineVariant),
          Expanded(
            child: CodeEditor(
              initialValue: current,
              onChanged: (value) => current = value,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckUpdatesButton extends StatefulWidget {
  const _CheckUpdatesButton();

  @override
  State<_CheckUpdatesButton> createState() => _CheckUpdatesButtonState();
}

class _CheckUpdatesButtonState extends State<_CheckUpdatesButton> {
  bool isLoading = false;

  void check() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final count = await ComicSourcePage.checkComicSourceUpdate();
      if (!mounted) return;
      if (count == 0) {
        context.showMessage(message: 'No updates'.tl);
      } else {
        showUpdateDialog();
      }
    } catch (e) {
      if (mounted) context.showMessage(message: e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showUpdateDialog() async {
    var text = ComicSourceManager().availableUpdates.entries
        .map((e) {
          return "${ComicSource.find(e.key)?.name ?? e.key}: ${e.value}";
        })
        .join("\n");
    bool doUpdate = false;
    await showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: "Updates".tl,
          content: Text(text).paddingHorizontal(16),
          actions: [
            FilledButton(
              onPressed: () {
                doUpdate = true;
                context.pop();
              },
              child: Text("Update".tl),
            ),
          ],
        );
      },
    );
    if (doUpdate) {
      var loadingController = showLoadingDialog(
        context,
        message: "Updating".tl,
        withProgress: true,
      );
      int current = 0;
      int total = ComicSourceManager().availableUpdates.length;
      try {
        var shouldUpdate = ComicSourceManager().availableUpdates.keys.toList();
        for (var key in shouldUpdate) {
          var source = ComicSource.find(key)!;
          await ComicSourcePage.update(source, false);
          current++;
          loadingController.setProgress(current / total);
        }
      } catch (e) {
        context.showMessage(message: e.toString());
      }
      loadingController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.update),
      tooltip: "Check updates".tl,
      onPressed: isLoading ? null : check,
    );
  }
}

class _CallbackSetting extends StatefulWidget {
  const _CallbackSetting({required this.setting, required this.sourceKey});

  final MapEntry<String, Map<String, dynamic>> setting;

  final String sourceKey;

  @override
  State<_CallbackSetting> createState() => _CallbackSettingState();
}

class _CallbackSettingState extends State<_CallbackSetting> {
  String get key => widget.setting.key;

  String get buttonText => widget.setting.value['buttonText'] ?? "Click";

  String get title => widget.setting.value['title'] ?? key;

  bool isLoading = false;

  Future<void> onClick() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      var func = widget.setting.value['callback'];
      await Future.sync(() => func([]));
    } catch (e, s) {
      Log.error('Source callback', e, s);
      if (mounted) context.showMessage(message: e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title.ts(widget.sourceKey)),
      trailing: Button.normal(
        onPressed: onClick,
        isLoading: isLoading,
        child: Text(buttonText.ts(widget.sourceKey)),
      ).fixHeight(32),
    );
  }
}

class _SliverComicSource extends StatefulWidget {
  const _SliverComicSource({
    super.key,
    required this.source,
    required this.edit,
    required this.update,
    required this.delete,
  });

  final ComicSource source;

  final void Function(ComicSource source) edit;
  final void Function(ComicSource source) update;
  final void Function(ComicSource source) delete;

  @override
  State<_SliverComicSource> createState() => _SliverComicSourceState();
}

class _SliverComicSourceState extends State<_SliverComicSource> {
  ComicSource get source => widget.source;
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    var newVersion = ComicSourceManager().availableUpdates[source.key];
    bool hasUpdate =
        newVersion != null && compareSemVer(newVersion, source.version);

    return SliverToBoxAdapter(
      child: Card.outlined(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            ListTile(
              onTap: () => setState(() => expanded = !expanded),
              leading: CircleAvatar(
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                foregroundColor: context.colorScheme.onSurface,
                child: Text(
                  source.name.isEmpty ? 'S' : source.name.characters.first,
                ),
              ),
              title: Text(source.name, style: ts.s18),
              subtitle: Text(
                '${source.version}${hasUpdate ? ' · ${"New Version".tl}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Source settings'.tl,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () => setState(() => expanded = !expanded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Manage'.tl,
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          widget.edit(source);
                        case 'update':
                          widget.update(source);
                        case 'delete':
                          widget.delete(source);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text('Edit'.tl)),
                      if (source.url.isNotEmpty)
                        PopupMenuItem(
                          value: 'update',
                          child: Text('Update'.tl),
                        ),
                      PopupMenuItem(value: 'delete', child: Text('Delete'.tl)),
                    ],
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const Divider(height: 1),
              ...buildSourceSettings(),
              ..._buildAccount(),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Iterable<Widget> buildSourceSettings() sync* {
    // Try to get dynamic settings first (for getters), fall back to cached settings
    var settingsMap = source.getSettingsDynamic() ?? source.settings;

    if (settingsMap == null) {
      return;
    } else if (source.data['settings'] == null) {
      source.data['settings'] = {};
    }
    for (var item in settingsMap.entries) {
      var key = item.key;
      try {
        final type = item.value['type'];
        if (type == "select") {
          final options = (item.value['options'] as List)
              .whereType<Map>()
              .toList();
          if (options.isEmpty) continue;
          final value = source.data['settings'][key] ?? item.value['default'];
          final current = options.indexWhere(
            (option) => option['value'] == value,
          );
          yield ListTile(
            title: Text(
              (item.value['title']?.toString() ?? key).ts(source.key),
            ),
            subtitle: DropdownButton<int>(
              isExpanded: true,
              value: current < 0 ? null : current,
              hint: Text(value?.toString() ?? 'Select'.tl),
              underline: const SizedBox.shrink(),
              items: [
                for (var index = 0; index < options.length; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Text(
                      (options[index]['text'] ?? options[index]['value'])
                          .toString()
                          .ts(source.key),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (i) {
                if (i == null) return;
                source.data['settings'][key] = options[i]['value'];
                source.saveData();
                setState(() {});
              },
            ),
          );
        } else if (type == "switch") {
          var current = source.data['settings'][key] ?? item.value['default'];
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            trailing: Switch(
              value: current == true,
              onChanged: (v) {
                source.data['settings'][key] = v;
                source.saveData();
                setState(() {});
              },
            ),
          );
        } else if (type == "input") {
          var current =
              (source.data['settings'][key] ?? item.value['default'] ?? '')
                  .toString();
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            subtitle: Text(
              current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showInputDialog(
                  context: context,
                  title: (item.value['title'] as String).ts(source.key),
                  initialValue: current,
                  inputValidator: item.value['validator'] == null
                      ? null
                      : RegExp(item.value['validator']),
                  onConfirm: (value) {
                    source.data['settings'][key] = value;
                    source.saveData();
                    setState(() {});
                    return null;
                  },
                );
              },
            ),
          );
        } else if (type == "callback") {
          yield _CallbackSetting(setting: item, sourceKey: source.key);
        }
      } catch (e, s) {
        Log.error("ComicSourcePage", "Failed to build a setting\n$e\n$s");
      }
    }
  }

  final _reLogin = <String, bool>{};

  Iterable<Widget> _buildAccount() sync* {
    if (source.account == null) return;
    final bool logged = source.isLogged;
    if (!logged) {
      yield ListTile(
        title: Text("Log in".tl),
        trailing: const Icon(Icons.arrow_right),
        onTap: () async {
          await context.to(
            () => _LoginPage(config: source.account!, source: source),
          );
          source.saveData();
          if (mounted) setState(() {});
        },
      );
    }
    if (logged) {
      for (var item in source.account!.infoItems) {
        if (item.builder != null) {
          yield item.builder!(context);
        } else {
          yield ListTile(
            title: Text(item.title.tl),
            subtitle: item.data == null ? null : Text(item.data!()),
            onTap: item.onTap,
          );
        }
      }
      if (source.data["account"] is List &&
          (source.data["account"] as List).length >= 2 &&
          source.account?.login != null) {
        bool loading = _reLogin[source.key] == true;
        yield ListTile(
          title: Text("Re-login".tl),
          subtitle: Text("Click if login expired".tl),
          onTap: () async {
            if (source.data["account"] == null) {
              context.showMessage(message: "No data".tl);
              return;
            }
            setState(() {
              _reLogin[source.key] = true;
            });
            final List account = source.data["account"];
            try {
              var res = await source.account!.login!(account[0], account[1]);
              if (!mounted) return;
              context.showMessage(
                message: res.error ? res.errorMessage! : 'Success'.tl,
              );
            } catch (e) {
              if (mounted) context.showMessage(message: e.toString());
            } finally {
              if (mounted) setState(() => _reLogin[source.key] = false);
            }
          },
          trailing: loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        );
      }
      yield ListTile(
        title: Text("Log out".tl),
        onTap: () {
          source.data["account"] = null;
          source.account?.logout();
          source.saveData();
          ComicSourceManager().notifyStateChange();
          setState(() {});
        },
        trailing: const Icon(Icons.logout),
      );
    }
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.config, required this.source});

  final AccountConfig config;

  final ComicSource source;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  String username = "";
  String password = "";
  bool loading = false;

  final Map<String, String> _cookies = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Appbar(title: Text('')),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Login".tl, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 32),
                if (widget.config.cookieFields == null)
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Username".tl,
                      border: const OutlineInputBorder(),
                    ),
                    enabled: widget.config.login != null,
                    onChanged: (s) {
                      username = s;
                    },
                    autofillHints: const [AutofillHints.username],
                  ).paddingBottom(16),
                if (widget.config.cookieFields == null)
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Password".tl,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: widget.config.login != null,
                    onChanged: (s) {
                      password = s;
                    },
                    onSubmitted: (s) => login(),
                    autofillHints: const [AutofillHints.password],
                  ).paddingBottom(16),
                for (var field in widget.config.cookieFields ?? <String>[])
                  TextField(
                    decoration: InputDecoration(
                      labelText: field,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: widget.config.validateCookies != null,
                    onChanged: (s) {
                      _cookies[field] = s;
                    },
                  ).paddingBottom(16),
                if (widget.config.login == null &&
                    widget.config.cookieFields == null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Text("Login with password is disabled".tl),
                    ],
                  )
                else
                  Button.filled(
                    isLoading: loading,
                    onPressed: login,
                    child: Text("Continue".tl),
                  ),
                const SizedBox(height: 24),
                if (widget.config.loginWebsite != null)
                  TextButton(
                    onPressed: () {
                      if (App.isLinux) {
                        loginWithWebview2();
                      } else {
                        loginWithWebview();
                      }
                    },
                    child: Text("Login with webview".tl),
                  ),
                const SizedBox(height: 8),
                if (widget.config.registerWebsite != null)
                  TextButton(
                    onPressed: () =>
                        launchUrlString(widget.config.registerWebsite!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link),
                        const SizedBox(width: 8),
                        Text("Create Account".tl),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void login() {
    if (widget.config.login != null) {
      if (username.isEmpty || password.isEmpty) {
        showToast(
          message: "Cannot be empty".tl,
          icon: const Icon(Icons.error_outline),
          context: context,
        );
        return;
      }
      setState(() {
        loading = true;
      });
      widget.config.login!(username, password).then((value) {
        if (value.error) {
          context.showMessage(message: value.errorMessage!);
          setState(() {
            loading = false;
          });
        } else {
          if (mounted) {
            context.pop();
          }
        }
      });
    } else if (widget.config.validateCookies != null) {
      setState(() {
        loading = true;
      });
      var cookies = widget.config.cookieFields!
          .map((e) => _cookies[e] ?? '')
          .toList();
      widget.config.validateCookies!(cookies).then((value) {
        if (value) {
          widget.source.data['account'] = 'ok';
          widget.source.saveData();
          context.pop();
        } else {
          context.showMessage(message: "Invalid cookies".tl);
          setState(() {
            loading = false;
          });
        }
      });
    }
  }

  void loginWithWebview() async {
    var url = widget.config.loginWebsite!;
    var title = '';
    bool success = false;

    void validate(InAppWebViewController c) async {
      if (widget.config.checkLoginStatus != null &&
          widget.config.checkLoginStatus!(url, title)) {
        var cookies = (await c.getCookies(url)) ?? [];
        var localStorageItems = await c.webStorage.localStorage.getItems();
        var mappedLocalStorage = <String, dynamic>{};
        for (var item in localStorageItems) {
          if (item.key != null) {
            mappedLocalStorage[item.key!] = item.value;
          }
        }
        widget.source.data['_localStorage'] = mappedLocalStorage;
        await widget.source.saveData();
        SingleInstanceCookieJar.instance?.saveFromResponse(
          Uri.parse(url),
          cookies,
        );
        success = true;
        widget.config.onLoginWithWebviewSuccess?.call();
        App.mainNavigatorKey?.currentContext?.pop();
      }
    }

    await context.to(
      () => AppWebview(
        initialUrl: widget.config.loginWebsite!,
        onNavigation: (u, c) {
          url = u;
          validate(c);
          return false;
        },
        onTitleChange: (t, c) {
          title = t;
          validate(c);
        },
      ),
    );
    if (success) {
      widget.source.data['account'] = 'ok';
      widget.source.saveData();
      context.pop();
    }
  }

  // for linux
  void loginWithWebview2() async {
    if (!await DesktopWebview.isAvailable()) {
      context.showMessage(message: "Webview is not available".tl);
    }

    var url = widget.config.loginWebsite!;
    var title = '';
    bool success = false;

    void onClose() {
      if (success) {
        widget.source.data['account'] = 'ok';
        widget.source.saveData();
        context.pop();
      }
    }

    void validate(DesktopWebview webview) async {
      if (widget.config.checkLoginStatus != null &&
          widget.config.checkLoginStatus!(url, title)) {
        var cookiesMap = await webview.getCookies(url);
        var cookies = <io.Cookie>[];
        cookiesMap.forEach((key, value) {
          cookies.add(io.Cookie(key, value));
        });
        SingleInstanceCookieJar.instance?.saveFromResponse(
          Uri.parse(url),
          cookies,
        );
        var localStorageJson = await webview.evaluateJavascript(
          "JSON.stringify(window.localStorage);",
        );
        var localStorage = <String, dynamic>{};
        try {
          var decoded = jsonDecode(localStorageJson ?? '');
          if (decoded is Map<String, dynamic>) {
            localStorage = decoded;
          }
        } catch (e) {
          Log.error("ComicSourcePage", "Failed to parse localStorage JSON\n$e");
        }
        widget.source.data['_localStorage'] = localStorage;
        await widget.source.saveData();
        success = true;
        widget.config.onLoginWithWebviewSuccess?.call();
        webview.close();
        onClose();
      }
    }

    var webview = DesktopWebview(
      initialUrl: widget.config.loginWebsite!,
      onTitleChange: (t, webview) {
        title = t;
        validate(webview);
      },
      onNavigation: (u, webview) {
        url = u;
        validate(webview);
      },
      onClose: onClose,
    );

    webview.open();
  }
}
