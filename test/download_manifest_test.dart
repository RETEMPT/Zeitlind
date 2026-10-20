import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/downloads/domain/download_manifest.dart';

void main() {
  test(
    'issue 813: a persisted partial image list is not complete on resume',
    () {
      expect(
        DownloadManifest.isComplete(
          {
            'chapter1': ['page1'],
          },
          ['chapter1', 'chapter2'],
        ),
        isFalse,
      );
    },
  );
  test('empty chapters and an empty selection cannot complete a download', () {
    expect(
      DownloadManifest.isComplete({'chapter1': []}, ['chapter1']),
      isFalse,
    );
    expect(DownloadManifest.isComplete({}, []), isFalse);
  });
  test('single chapter comics and selected subsets can complete', () {
    expect(
      DownloadManifest.isComplete(
        {
          '': ['page1'],
        },
        [''],
      ),
      isTrue,
    );
    expect(
      DownloadManifest.isComplete(
        {
          'chapter2': ['page1', 'page2'],
        },
        ['chapter2'],
      ),
      isTrue,
    );
  });
  test(
    'a manifest for different chapters cannot mark a selection complete',
    () {
      expect(
        DownloadManifest.isComplete(
          {
            'old': ['page'],
          },
          ['new'],
        ),
        isFalse,
      );
    },
  );
}
