import 'package:flutter/foundation.dart';
import '../data/source_catalog_repository.dart';
import '../domain/source_catalog.dart';

enum SourceCatalogStatus { idle, loading, ready, failed }

class SourceCatalogController extends ChangeNotifier {
  SourceCatalogController(this.repository);

  final SourceCatalogRepository repository;
  SourceCatalogStatus status = SourceCatalogStatus.idle;
  List<SourceCatalogEntry> entries = const [];
  String? error;
  String query = '';
  String? loadedAddress;
  int _request = 0;
  bool _disposed = false;

  List<SourceCatalogEntry> get filtered =>
      entries.where((entry) => entry.matches(query)).toList(growable: false);

  void search(String value) {
    query = value;
    notifyListeners();
  }

  Future<bool> load(String address) async {
    final request = ++_request;
    status = SourceCatalogStatus.loading;
    error = null;
    notifyListeners();
    try {
      final result = await repository.load(address);
      if (_disposed || request != _request) return false;
      entries = result;
      loadedAddress = address.trim();
      status = SourceCatalogStatus.ready;
      notifyListeners();
      return true;
    } catch (e) {
      if (_disposed || request != _request) return false;
      error = e.toString();
      status = SourceCatalogStatus.failed;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
