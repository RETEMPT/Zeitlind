import 'package:flutter/material.dart';
import 'package:zeitlind/app/app_identity.dart';
import 'package:zeitlind/utils/translations.dart';

/// Home actions use callbacks so this view does not depend on storage or routing.
class LibraryDashboard extends StatelessWidget {
  const LibraryDashboard({
    super.key,
    required this.sourceCount,
    required this.onSearch,
    required this.onSources,
    required this.onLocal,
    required this.onDownloads,
    required this.onHistory,
    required this.onSettings,
  });

  final int sourceCount;
  final VoidCallback onSearch;
  final VoidCallback onSources;
  final VoidCallback onLocal;
  final VoidCallback onDownloads;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Z',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppIdentity.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settings'.tl,
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Material(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Search all your sources'.tl)),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 620 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              final actions = [
                (Icons.hub_outlined, 'Comic Source'.tl, onSources),
                (Icons.library_books_outlined, 'Local'.tl, onLocal),
                (Icons.download_outlined, 'Downloads'.tl, onDownloads),
                (Icons.history_rounded, 'History'.tl, onHistory),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final action in actions)
                    SizedBox(
                      width: width,
                      child: Material(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: action.$3,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(action.$1, color: colors.primary),
                                const SizedBox(height: 12),
                                Text(
                                  action.$2,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (sourceCount == 0) ...[
            const SizedBox(height: 16),
            Card.filled(
              color: colors.surfaceContainer,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make room for your first story'.tl,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a comic source or import a local comic to start reading.'
                          .tl,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onSources,
                      icon: const Icon(Icons.add),
                      label: Text('Add comic source'.tl),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
