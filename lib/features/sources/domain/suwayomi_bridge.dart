import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'source_catalog.dart';
import 'source_identity.dart';

Uri suwayomiBaseUri(String address) {
  final uri = sourceHttpUri(address);
  if (uri.hasQuery || uri.hasFragment) {
    throw const FormatException(
      'Enter the server base URL without query parameters',
    );
  }
  var path = uri.path
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/api/v1$'), '');
  return uri.replace(path: '$path/');
}

class SuwayomiRemoteSource {
  const SuwayomiRemoteSource(this.id, this.name, this.language, {this.website});
  final String id;
  final String name;
  final String language;
  final String? website;
  String websiteIdentity(Uri server) =>
      sourceWebsiteIdentity(key(server), website);

  static List<SuwayomiRemoteSource> parse(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException(
        'The server did not return a Suwayomi source list',
      );
    }
    final entries = decoded.map((item) {
      if (item is! Map || item['id'] == null || item['name'] is! String) {
        throw const FormatException('The server returned an invalid source');
      }
      final id = item['id'].toString();
      if (!RegExp(r'^-?\d+$').hasMatch(id)) {
        throw const FormatException('The server returned an invalid source ID');
      }
      return SuwayomiRemoteSource(
        id,
        item['displayName']?.toString() ?? item['name'],
        item['lang']?.toString() ?? '',
        website: item['baseUrl']?.toString(),
      );
    }).toList();
    final unique = <String, SuwayomiRemoteSource>{};
    for (final entry in entries) {
      final identity = entry.website == null
          ? 'id:${entry.id}'
          : sourceWebsiteIdentity(entry.id, entry.website);
      unique.putIfAbsent(identity, () => entry);
    }
    return unique.values.toList();
  }

  String key(Uri server) =>
      'suwayomi_${sha256.convert(utf8.encode('$server|$id')).toString().substring(0, 20)}';
}

/// JSON-encode replacements so server/source names cannot inject JavaScript.
String buildSuwayomiScript(
  String template,
  Uri server,
  SuwayomiRemoteSource source,
) => template
    .replaceAll(
      '__ZEITLIND_SERVER__',
      jsonEncode(server.toString().replaceFirst(RegExp(r'/$'), '')),
    )
    .replaceAll('__ZEITLIND_SOURCE_ID__', jsonEncode(source.id))
    .replaceAll('__ZEITLIND_SOURCE_KEY__', jsonEncode(source.key(server)))
    .replaceAll(
      '__ZEITLIND_SOURCE_NAME__',
      jsonEncode('${source.name} · ${source.language}'),
    );
