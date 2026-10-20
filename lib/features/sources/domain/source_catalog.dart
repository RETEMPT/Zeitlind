import 'dart:convert';
import 'source_identity.dart';
import 'package:zeitlind/core/version.dart';

/// A directory entry is metadata. Loading a directory never executes its scripts.
class SourceCatalogEntry {
  const SourceCatalogEntry({
    required this.key,
    required this.name,
    required this.version,
    required this.description,
    required this.scriptUri,
    this.website,
  });

  final String key;
  final String name;
  final String version;
  final String description;
  final Uri scriptUri;
  final String? website;
  String get websiteIdentity => sourceWebsiteIdentity(key, website);

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
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (uri.host == 'github.com' && segments.length == 2) {
    return Uri.https(
      'raw.githubusercontent.com',
      '/${segments.join('/')}/HEAD/index.json',
    );
  }
  if (uri.host == 'github.com' &&
      segments.length >= 5 &&
      (segments[2] == 'blob' ||
          segments[2] == 'raw' ||
          segments[2] == 'tree')) {
    return Uri.https(
      'raw.githubusercontent.com',
      '/${segments[0]}/${segments[1]}/${segments.skip(3).join('/')}${segments[2] == 'tree' ? '/index.json' : ''}',
    );
  }
  return uri;
}

/// Substitute only the identical public GitHub repository, ref, and file path.
/// Arbitrary hosts and URLs with credentials/query parameters are never changed.
List<Uri> sourceFallbackUris(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.hasQuery ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return [uri];
  }
  final parts = uri.pathSegments;
  if (uri.host == 'raw.githubusercontent.com' &&
      parts.length >= 4 &&
      parts[2] != 'refs') {
    return [
      uri,
      Uri.https(
        'cdn.jsdelivr.net',
        '/gh/${parts[0]}/${parts[1]}@${parts[2]}/${parts.skip(3).join('/')}',
      ),
    ];
  }
  if (uri.host == 'cdn.jsdelivr.net' && parts.length >= 4 && parts[0] == 'gh') {
    final repository = parts[2].split('@');
    if (repository.length == 2 &&
        repository.every((value) => value.isNotEmpty)) {
      return [
        uri,
        Uri.https(
          'raw.githubusercontent.com',
          '/${parts[1]}/${repository[0]}/${repository[1]}/${parts.skip(3).join('/')}',
        ),
      ];
    }
  }
  return [uri];
}

List<SourceCatalogEntry> parseSourceCatalog(String content, Uri catalogUri) {
  final decoded = jsonDecode(
    content.replaceFirst(RegExp(r'^\uFEFF'), '').trim(),
  );
  if (decoded is! List) {
    throw const FormatException('The source directory must be a JSON array');
  }
  return List.unmodifiable(
    deduplicateSourceCatalog(
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
        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(key)) {
          throw FormatException('Invalid source key: $key');
        }
        final location = item['url'];
        final relative = location is String && location.trim().isNotEmpty
            ? location.trim()
            : requiredString('fileName');
        final scriptUri = sourceHttpUri(
          catalogUri.resolve(relative).toString(),
        );
        return SourceCatalogEntry(
          key: key,
          name: requiredString('name'),
          version: requiredString('version'),
          description: item['description']?.toString() ?? '',
          scriptUri: scriptUri,
          website: (item['domain'] ?? item['website'] ?? item['siteUrl'])
              ?.toString(),
        );
      }).toList(),
    ),
  );
}

List<SourceCatalogEntry> deduplicateSourceCatalog(
  Iterable<SourceCatalogEntry> entries, {
  Set<String> preferredKeys = const {},
}) {
  final byKey = <String, SourceCatalogEntry>{};
  for (final entry in entries) {
    final previous = byKey[entry.key];
    if (previous == null ||
        compareVersions(entry.version, previous.version) > 0) {
      byKey[entry.key] = entry;
    }
  }
  final byWebsite = <String, SourceCatalogEntry>{};
  for (final entry in byKey.values) {
    final previous = byWebsite[entry.websiteIdentity];
    if (previous == null ||
        (preferredKeys.contains(entry.key) &&
            !preferredKeys.contains(previous.key)) ||
        (preferredKeys.contains(entry.key) ==
                preferredKeys.contains(previous.key) &&
            compareVersions(entry.version, previous.version) > 0)) {
      byWebsite[entry.websiteIdentity] = entry;
    }
  }
  return byWebsite.values.toList();
}

abstract final class SourceCatalogPresets {
  static const community =
      'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/index.json';
  static const direct =
      'https://raw.githubusercontent.com/venera-app/venera-configs/main/index.json';
}
