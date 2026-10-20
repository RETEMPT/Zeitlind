import 'package:flutter/material.dart';
import 'package:zeitlind/components/components.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/utils/translations.dart';
import '../application/source_catalog_controller.dart';
import '../data/source_catalog_repository.dart';
import '../data/source_transport.dart';
import '../domain/source_catalog.dart';
import 'package:zeitlind/core/version.dart';
import 'source_import_error.dart';

class SourceCatalogView extends StatefulWidget {
  const SourceCatalogView({
    super.key,
    required this.onInstall,
    this.repository,
    this.onDirectoryLoaded,
    this.initialAddress,
    this.initialEntries,
  });

  final Future<void> Function(SourceCatalogEntry entry) onInstall;
  final SourceCatalogRepository? repository;
  final Future<void> Function(String address)? onDirectoryLoaded;
  final String? initialAddress;
  final List<SourceCatalogEntry>? initialEntries;

  @override
  State<SourceCatalogView> createState() => _SourceCatalogViewState();
}

class _SourceCatalogViewState extends State<SourceCatalogView> {
  late final catalog = SourceCatalogController(
    widget.repository ?? const SourceCatalogRepository(loadSourceText),
  );
  late final address = TextEditingController(
    text:
        widget.initialAddress ??
        (widget.initialEntries == null
            ? appdata.settings['comicSourceListUrl']
            : ''),
  );
  String? installing;
  String? installError;
  int filter = 0;
  ComicSource? installedSource(SourceCatalogEntry entry) =>
      ComicSource.find(entry.key) ??
      ComicSourceManager().findWebsite(entry.websiteIdentity);
  bool isCurrent(SourceCatalogEntry entry) {
    final source = installedSource(entry);
    return source != null &&
        (source.key != entry.key ||
            compareVersions(entry.version, source.version) <= 0);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEntries != null) {
      catalog.setEntries(
        widget.initialEntries!,
        address: widget.initialAddress,
      );
      if (widget.initialAddress != null) {
        rememberDirectory(widget.initialAddress!);
      }
    } else {
      load();
    }
  }

  Future<void> rememberDirectory(String value) async {
    if (widget.onDirectoryLoaded != null) {
      await widget.onDirectoryLoaded!(value);
      return;
    }
    appdata.settings['comicSourceListUrl'] = value;
    final saved = (appdata.settings['comicSourceRepositories'] as List)
        .whereType<String>()
        .toList();
    saved.remove(value);
    saved.insert(0, value);
    appdata.settings['comicSourceRepositories'] = saved.take(12).toList();
    try {
      await appdata.saveData();
    } catch (e) {
      if (mounted) setState(() => installError = sourceImportError(e));
    }
  }

  Future<void> load() async {
    if (await catalog.load(address.text)) {
      await rememberDirectory(catalog.loadedAddress!);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    address.dispose();
    catalog.dispose();
    super.dispose();
  }

  Future<void> install(SourceCatalogEntry entry) async {
    setState(() {
      installing = entry.key;
      installError = null;
    });
    try {
      await widget.onInstall(entry);
    } catch (e) {
      if (mounted) setState(() => installError = sourceImportError(e));
    } finally {
      if (mounted) setState(() => installing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: 'Source directory'.tl,
      body: AnimatedBuilder(
        animation: catalog,
        builder: (context, _) {
          final entries = catalog.filtered
              .where(
                (entry) => switch (filter) {
                  1 => installedSource(entry) == null,
                  2 => const {
                    'komga',
                    'kavita',
                    'lanraragi',
                  }.contains(entry.key),
                  3 => installedSource(entry) != null,
                  _ => true,
                },
              )
              .toList();
          final loading = catalog.status == SourceCatalogStatus.loading;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Repo URL'.tl,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Refresh'.tl,
                    onPressed: loading ? null : load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                onSubmitted: (_) => load(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text('Community CDN'.tl),
                    onPressed: () {
                      address.text = SourceCatalogPresets.community;
                      load();
                    },
                  ),
                  if ((appdata.settings['comicSourceRepositories'] as List)
                      .isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Saved repositories'.tl,
                      icon: const Icon(Icons.history),
                      onSelected: (value) {
                        address.text = value;
                        load();
                      },
                      itemBuilder: (_) =>
                          (appdata.settings['comicSourceRepositories'] as List)
                              .whereType<String>()
                              .map(
                                (value) => PopupMenuItem(
                                  value: value,
                                  child: Text(
                                    value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ActionChip(
                    label: Text('GitHub direct'.tl),
                    onPressed: () {
                      address.text = SourceCatalogPresets.direct;
                      load();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: catalog.search,
                decoration: InputDecoration(
                  hintText: 'Search sources, languages, Komga or Kavita'.tl,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final (index, label) in [
                    (0, 'All'),
                    (1, 'Not installed'),
                    (2, 'Self-hosted'),
                    (3, 'Installed'),
                  ])
                    ChoiceChip(
                      label: Text(label.tl),
                      selected: filter == index,
                      onSelected: (_) => setState(() => filter = index),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (loading) const LinearProgressIndicator(),
              if (catalog.error != null) ...[
                Text(
                  catalog.error!.tl,
                  style: TextStyle(color: context.colorScheme.error),
                ),
                TextButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: Text('Retry'.tl),
                ),
              ],
              if (installError != null)
                Text(
                  installError!,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              if (!loading &&
                  catalog.status == SourceCatalogStatus.ready &&
                  entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No matching sources'.tl,
                    textAlign: TextAlign.center,
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  children: [
                    for (final entry in entries)
                      SizedBox(
                        width: constraints.maxWidth >= 720
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth,
                        child: Card.outlined(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '${entry.version} · ${entry.scriptUri.host}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (entry.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(entry.description),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: isCurrent(entry)
                                      ? Chip(
                                          avatar: const Icon(
                                            Icons.check,
                                            size: 18,
                                          ),
                                          label: Text('Installed'.tl),
                                        )
                                      : FilledButton.tonalIcon(
                                          onPressed: installing == null
                                              ? () => install(entry)
                                              : null,
                                          icon: installing == entry.key
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.add),
                                          label: Text(
                                            (ComicSource.find(entry.key) == null
                                                    ? 'Add'
                                                    : 'Update')
                                                .tl,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
