/// A partial image manifest must never be treated as a completed download.
abstract final class DownloadManifest {
  static bool isComplete(
    Map<String, List<String>> images,
    Iterable<String> expectedChapters,
  ) {
    final expected = expectedChapters.toSet();
    return expected.isNotEmpty &&
        images.length == expected.length &&
        expected.every((key) => images[key]?.isNotEmpty ?? false);
  }
}
