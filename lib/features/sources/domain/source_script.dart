/// Inspects declarations without executing third-party JavaScript.
class SourceScript {
  const SourceScript(this.content, this.className);
  final String content;
  final String className;

  factory SourceScript.parse(String input) {
    final content = input
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .replaceAll('\r\n', '\n');
    final code = _maskCommentsAndStrings(content);
    final declarations = RegExp(
      r'\bclass\s+([A-Za-z_$][\w$]*)\s+extends\s+ComicSource\s*\{',
    ).allMatches(code).toList();
    if (declarations.isEmpty) {
      throw const FormatException(
        'No Venera ComicSource class found in this script',
      );
    }
    if (declarations.length != 1) {
      throw const FormatException('Import one ComicSource class per script');
    }
    return SourceScript(content, declarations.single.group(1)!);
  }

  static String _maskCommentsAndStrings(String input) {
    final result = input.codeUnits.toList();
    var index = 0;
    var canStartRegex = true;
    bool identifierStart(int c) =>
        c == 36 || c == 95 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    bool identifierPart(int c) => identifierStart(c) || (c >= 48 && c <= 57);
    void blank(int start, int end) {
      for (var i = start; i < end; i++) {
        if (result[i] != 10 && result[i] != 13) result[i] = 32;
      }
    }

    while (index < input.length) {
      final start = index;
      if (input.startsWith('//', index)) {
        while (index < input.length && input.codeUnitAt(index) != 10) {
          index++;
        }
        blank(start, index);
      } else if (input.startsWith('/*', index)) {
        final end = input.indexOf('*/', index + 2);
        index = end < 0 ? input.length : end + 2;
        blank(start, index);
      } else if (const [34, 39, 96].contains(input.codeUnitAt(index))) {
        final quote = input.codeUnitAt(index++);
        while (index < input.length) {
          final character = input.codeUnitAt(index++);
          if (character == 92 && index < input.length) {
            index++;
          } else if (character == quote) {
            break;
          }
        }
        blank(start, index);
        canStartRegex = false;
      } else if (input.codeUnitAt(index) == 47 && canStartRegex) {
        var cursor = index + 1;
        var inCharacterClass = false;
        var closed = false;
        while (cursor < input.length) {
          final c = input.codeUnitAt(cursor++);
          if (c == 10 || c == 13) break;
          if (c == 92) {
            cursor++;
          } else if (c == 91) {
            inCharacterClass = true;
          } else if (c == 93) {
            inCharacterClass = false;
          } else if (c == 47 && !inCharacterClass) {
            closed = true;
            break;
          }
        }
        if (closed) {
          while (cursor < input.length &&
              identifierPart(input.codeUnitAt(cursor))) {
            cursor++;
          }
          blank(start, cursor);
          index = cursor;
          canStartRegex = false;
        } else {
          index++;
        }
      } else if (identifierStart(input.codeUnitAt(index))) {
        while (index < input.length &&
            identifierPart(input.codeUnitAt(index))) {
          index++;
        }
        canStartRegex = const {
          'return',
          'throw',
          'case',
          'yield',
          'await',
          'void',
          'typeof',
          'delete',
          'in',
          'of',
        }.contains(input.substring(start, index));
      } else {
        final c = input.codeUnitAt(index);
        if (!const [9, 10, 13, 32].contains(c)) {
          canStartRegex = const [
            40,
            61,
            58,
            91,
            44,
            33,
            38,
            124,
            63,
            59,
            123,
            125,
            43,
            45,
            42,
            37,
            94,
            126,
            60,
            62,
            47,
          ].contains(c);
        }
        index++;
      }
    }
    return String.fromCharCodes(result);
  }
}
