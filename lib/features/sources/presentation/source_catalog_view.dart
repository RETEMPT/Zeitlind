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

class SourceCatalogView extends StatefulWidget {
  const SourceCatalogView({
    super.key,
    required this.onInstall,
    this.repository,
    this.onDirectoryLoaded,
  });

  final Future<void> Function(SourceCatalogEntry entry) onInstall;
  final SourceCatalogRepository? repository;
  final Future<void> Function(String address)? onDirectoryLoaded;

  @override
  State<SourceCatalogView> createState() => _SourceCatalogViewState();
}

class _SourceCatalogViewState extends State<SourceCatalogView> {
  late final catalog = SourceCatalogController(
    widget.repository ?? const SourceCatalogRepository(loadSourceText),
  );
  late final address = TextEditingController(
    text: appdata.settings['comicSourceListUrl'],
  );
  String? installing;
  String? installError;
  int filter = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (await catalog.load(address.text)) {
      if (widget.onDirectoryLoaded != null) {
        await widget.onDirectoryLoaded!(catalog.loadedAddress!);
        return;
      }
      appdata.settings['comicSourceListUrl'] = catalog.loadedAddress;
      await appdata.saveData();
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
      if (mounted) setState(() => installError = e.toString());
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
                  1 => ComicSource.find(entry.key) == null,
                  2 => const {
                    'komga',
                    'kavita',
                    'lanraragi',
                  }.contains(entry.key),
                  _ => true,
                },
              )
              .toList();
          final loading = catalog.status == SourceCatalogStatus.loading;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Find your next story'.tl,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Browse community sources or connect your own library. Scripts run only after you install them.'
                    .tl,
              ),
              const SizedBox(height: 16),
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
                  catalog.error!,
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
              for (final entry in entries)
                Card.outlined(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: Theme.of(context).textTheme.titleMedium,
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
                          child: ComicSource.find(entry.key) != null
                              ? Chip(
                                  avatar: const Icon(Icons.check, size: 18),
                                  label: Text('Installed'.tl),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: installing == null
                                      ? () => install(entry)
                                      : null,
                                  icon: installing == entry.key
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add),
                                  label: Text('Add'.tl),
                                ),
                        ),
                      ],
                    ),
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
