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
      } else {
        index++;
      }
    }
    return String.fromCharCodes(result);
  }
}
