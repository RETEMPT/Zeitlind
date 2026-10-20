import 'dart:convert';
import 'source_catalog.dart';
import 'source_script.dart';

enum SourceImportKind { script, directory, mihonRepository }

class SourceImportDocument {
  const SourceImportDocument._(
    this.kind,
    this.content,
    this.origin,
    this.entries,
  );
  final SourceImportKind kind;
  final String content;
  final Uri? origin;
  final List<SourceCatalogEntry> entries;

  factory SourceImportDocument.parse(String input, {Uri? origin}) {
    final content = input.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (content.isEmpty) {
      throw const FormatException('The source file is empty');
    }
    if (RegExp(
      r'^\s*(?:<!doctype\s+html|<html|<head|<body)',
      caseSensitive: false,
    ).hasMatch(content)) {
      throw const FormatException(
        'The link returned a web page. Use a source script or directory URL',
      );
    }
    if (content.startsWith('[') || content.startsWith('{')) {
      dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } on FormatException {
        throw const FormatException(
          'The source JSON is incomplete or malformed',
        );
      }
      final items = decoded is Map
          ? (decoded['sources'] ??
                decoded['items'] ??
                decoded['data'] ??
                [decoded])
          : decoded;
      if (items is List && items.isNotEmpty && items.first is Map) {
        final first = items.first as Map;
        if (first.containsKey('apk') || first.containsKey('pkg')) {
          return SourceImportDocument._(
            SourceImportKind.mihonRepository,
            content,
            origin,
            const [],
          );
        }
        if (first.containsKey('bookSourceUrl') ||
            first.containsKey('ruleSearch')) {
          throw const FormatException(
            'This is a Legado rule source. Import a Venera JavaScript source instead',
          );
        }
      }
      final entries = parseSourceCatalog(
        jsonEncode(items),
        origin ?? Uri.parse('file:///source-index.json'),
      );
      return SourceImportDocument._(
        SourceImportKind.directory,
        content,
        origin,
        entries,
      );
    }
    if (content.startsWith('PK\u0003\u0004')) {
      throw const FormatException(
        'APK and ZIP extensions are not Venera JavaScript sources',
      );
    }
    final script = SourceScript.parse(content);
    return SourceImportDocument._(
      SourceImportKind.script,
      script.content,
      origin,
      const [],
    );
  }
}

/// Accept a copied Markdown link, URL, or a Venera/Zeitlind source deep link.
Uri sourceImportUri(String input) {
  var value = input.trim();
  final markdown = RegExp(
    r'^\[[^\]]*\]\((https?://[^\s)]+)\)$',
  ).firstMatch(value);
  value = markdown?.group(1) ?? value;
  var uri = Uri.tryParse(value);
  if (uri != null && const ['venera', 'zeitlind'].contains(uri.scheme)) {
    final address = uri.queryParameters['url'] ?? uri.queryParameters['repo'];
    if (address == null) {
      throw const FormatException('The source link has no URL');
    }
    value = address;
  }
  return sourceHttpUri(value);
}

String decodeSourceBytes(List<int> bytes) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    if (bytes.length.isOdd) {
      throw const FormatException('The source file encoding is incomplete');
    }
    final littleEndian = bytes[0] == 0xFF;
    return String.fromCharCodes([
      for (var index = 2; index < bytes.length; index += 2)
        littleEndian
            ? bytes[index] | bytes[index + 1] << 8
            : bytes[index] << 8 | bytes[index + 1],
    ]);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('Save the source file as UTF-8 or UTF-16');
  }
}
