import 'package:flutter/material.dart';
import 'package:zeitlind/components/components.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/utils/translations.dart';
import '../domain/source_diagnostics.dart';
import '../data/source_transport.dart';

class SourceDiagnosticsView extends StatefulWidget {
  const SourceDiagnosticsView({super.key});

  @override
  State<SourceDiagnosticsView> createState() => _SourceDiagnosticsViewState();
}

class _SourceDiagnosticsViewState extends State<SourceDiagnosticsView> {
  final results = <SourceDiagnostic>[];
  bool checking = false;
  int total = 0;
  int request = 0;

  @override
  void initState() {
    super.initState();
    runChecks();
  }

  @override
  void dispose() {
    request++;
    super.dispose();
  }

  Future<void> runChecks() async {
    if (checking) return;
    final targets = ComicSource.all()
        .map(
          (source) => SourceProbeTarget(
            key: source.key,
            name: source.name,
            url: source.url,
          ),
        )
        .toList();
    final generation = ++request;
    setState(() {
      checking = true;
      results.clear();
      total = targets.length;
    });
    // Keep probes bounded, so checking many sources cannot flood the network.
    for (var i = 0; i < targets.length; i += 2) {
      if (!mounted || generation != request) return;
      await Future.wait(
        targets.skip(i).take(2).map((target) async {
          final result = await const SourceDiagnostics(
            fetchSourceText,
          ).check(target);
          if (mounted && generation == request) {
            setState(() => results.add(result));
          }
        }),
      );
    }
    if (mounted && generation == request) setState(() => checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: 'Source self-check'.tl,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Checks script links and metadata. Login, search and chapter reading must be tested separately.'
                .tl,
          ),
          const SizedBox(height: 16),
          if (checking)
            LinearProgressIndicator(
              value: total == 0 ? null : results.length / total,
            ),
          const SizedBox(height: 8),
          Text('${results.length} / $total'),
          if (total == 0) Text('No sources installed yet'.tl),
          for (final result in results)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          switch (result.health) {
                            SourceHealth.reachable =>
                              Icons.check_circle_outline,
                            SourceHealth.warning => Icons.info_outline,
                            SourceHealth.failed => Icons.error_outline,
                          },
                          color: result.health == SourceHealth.failed
                              ? context.colorScheme.error
                              : context.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.target.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(result.message.tl),
                    if (result.resolvedUri != null)
                      Text(
                        '${result.resolvedUri!.host}${result.resolvedUri!.path}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text('${result.elapsed.inMilliseconds} ms'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: checking ? null : runChecks,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: Text('Run self-check'.tl),
          ),
        ],
      ),
    );
  }
}
