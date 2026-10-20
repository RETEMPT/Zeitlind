/// Native Venera sources inherit an empty optional minimum from ComicSource.
bool requiresNewerAppVersion(String? minimum, String current) =>
    minimum != null &&
    minimum.trim().isNotEmpty &&
    compareVersions(minimum, current) > 0;

/// Compare numeric releases, prereleases, and legacy source `-hotfix` releases.
int compareVersions(String left, String right) {
  List<String> parts(String value) {
    final normalized = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first;
    if (!RegExp(r'^\d+(\.\d+){0,2}(-[0-9A-Za-z.-]+)?$').hasMatch(normalized)) {
      throw FormatException('Invalid version: $value');
    }
    return normalized.split('-');
  }

  final a = parts(left);
  final b = parts(right);
  final av = a.first.split('.').map(int.parse).toList();
  final bv = b.first.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final difference = (i < av.length ? av[i] : 0).compareTo(
      i < bv.length ? bv[i] : 0,
    );
    if (difference != 0) return difference;
  }
  final ap = a.skip(1).join('-');
  final bp = b.skip(1).join('-');
  if (ap == bp) return 0;
  if (ap == 'hotfix') return 1;
  if (bp == 'hotfix') return -1;
  if (ap.isEmpty) return 1;
  if (bp.isEmpty) return -1;
  final ai = ap.split('.');
  final bi = bp.split('.');
  for (var i = 0; i < ai.length && i < bi.length; i++) {
    final an = int.tryParse(ai[i]);
    final bn = int.tryParse(bi[i]);
    final difference = an != null && bn != null
        ? an.compareTo(bn)
        : an != null
        ? -1
        : bn != null
        ? 1
        : ai[i].compareTo(bi[i]);
    if (difference != 0) return difference;
  }
  return ai.length.compareTo(bi.length);
}
