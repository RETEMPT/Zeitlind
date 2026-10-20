import 'package:flutter/foundation.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/appdata.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/foundation/log.dart';
import '../data/source_transport.dart';
import '../domain/source_identity.dart';
import '../domain/starter_sources.dart';
import 'source_registration.dart';

class StarterSourceSetup extends ChangeNotifier {
  Future<void>? _running;
  bool get loading => _running != null;
  Map<String, Object> errors = {};

  Future<void> configure({bool restore = false}) {
    if (_running != null) return _running!;
    _running = _configure(restore).whenComplete(() {
      _running = null;
      notifyListeners();
    });
    notifyListeners();
    return _running!;
  }

  Future<void> _configure(bool restore) async {
    try {
      final saved = appdata.implicitData['starterSourceKeys'];
      final completed = !restore && saved is List
          ? saved.whereType<String>().toSet()
          : <String>{};
      final result = await const StarterSourceInstaller(loadSourceText).run(
        completed: completed,
        isInstalled: (spec) {
          final source =
              ComicSource.find(spec.key) ??
              ComicSourceManager().findWebsite(sourceWebsiteIdentity(spec.key));
          if (source == null) return false;
          registerSourcePages(source);
          return true;
        },
        install: (spec, script) async {
          final existing = ComicSourceManager().findWebsite(
            resolveSourceWebsiteIdentity(spec.key, script),
          );
          if (existing != null) {
            registerSourcePages(existing);
            return;
          }
          final source = await ComicSourceManager().install(
            script,
            '${spec.key}.js',
            expectedKey: spec.key,
          );
          registerSourcePages(source);
        },
        onProgress: (completedKeys) async {
          await appdata.saveData(false);
          appdata.implicitData['starterSourceKeys'] = completedKeys.toList();
          await appdata.writeImplicitData();
          App.forceRebuild();
        },
      );
      errors = result.errors;
      appdata.implicitData['starterSourceKeys'] = result.completed.toList();
      await appdata.writeImplicitData();
      for (final error in errors.entries) {
        Log.error('Default source ${error.key}', error.value);
      }
    } catch (e, s) {
      Log.error('Default sources', e, s);
    }
  }
}

final starterSourceSetup = StarterSourceSetup();
