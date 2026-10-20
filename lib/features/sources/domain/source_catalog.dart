import 'dart:convert';

/// A directory entry is metadata. Loading a directory never executes its scripts.
class SourceCatalogEntry {
  const SourceCatalogEntry({
    required this.key,
    required this.name,
    required this.version,
    required this.description,
    required this.scriptUri,
  });

  final String key;
  final String name;
  final String version;
  final String description;
  final Uri scriptUri;

  bool matches(String query) => '$name $key $description'
      .toLowerCase()
      .contains(query.trim().toLowerCase());
}

Uri sourceHttpUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !const ['https', 'http'].contains(uri.scheme)) {
    throw const FormatException('Enter a valid HTTP or HTTPS URL');
  }
  // A copied GitHub file page is HTML, not an installable source script.
  final segments = uri.pathSegments;
  if (uri.host == 'github.com' &&
      segments.length >= 5 &&
      (segments[2] == 'blob' || segments[2] == 'raw')) {
    return Uri.https(
      'raw.githubusercontent.com',
      '/${segments[0]}/${segments[1]}/${segments.skip(3).join('/')}',
    );
  }
  return uri;
}

/// Only known equivalent community mirrors may be substituted automatically.
List<Uri> sourceFallbackUris(Uri uri) {
  const rawPrefix =
      'https://raw.githubusercontent.com/venera-app/venera-configs/main/';
  const cdnPrefix =
      'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/';
  final address = uri.toString();
  if (address.startsWith(rawPrefix)) {
    return [uri, Uri.parse(address.replaceFirst(rawPrefix, cdnPrefix))];
  }
  if (address.startsWith(cdnPrefix)) {
    return [uri, Uri.parse(address.replaceFirst(cdnPrefix, rawPrefix))];
  }
  return [uri];
}

List<SourceCatalogEntry> parseSourceCatalog(String content, Uri catalogUri) {
  final decoded = jsonDecode(content);
  if (decoded is! List) {
    throw const FormatException('The source directory must be a JSON array');
  }
  final keys = <String>{};
  return List.unmodifiable(
    decoded.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid source directory entry');
      }
      String requiredString(String field) {
        final value = item[field];
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('Missing source field: $field');
        }
        return value.trim();
      }

      final key = requiredString('key');
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key) || !keys.add(key)) {
        throw FormatException('Invalid or duplicate source key: $key');
      }
      final location = item['url'];
      final relative = location is String && location.trim().isNotEmpty
          ? location.trim()
          : requiredString('fileName');
      final scriptUri = sourceHttpUri(catalogUri.resolve(relative).toString());
      return SourceCatalogEntry(
        key: key,
        name: requiredString('name'),
        version: requiredString('version'),
        description: item['description']?.toString() ?? '',
        scriptUri: scriptUri,
      );
    }),
  );
}

abstract final class SourceCatalogPresets {
  static const community =
      'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json';
  static const direct =
      'https://raw.githubusercontent.com/venera-app/venera-configs/main/index.json';
}
