import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/features/sources/data/source_install_transaction.dart';

void main() {
  late Directory directory;
  late File script;
  var restored = false;
  var released = false;
  const transaction = SourceInstallTransaction();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zeitlind-source-');
    script = File('${directory.path}/source.js');
    await script.writeAsString('old source');
    restored = false;
    released = false;
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'parse failure preserves the installed file and restores runtime',
    () async {
      await expectLater(
        transaction.run(
          destination: script,
          script: 'invalid source',
          snapshot: () {},
          parse: () async => throw const FormatException('bad source'),
          restore: () => restored = true,
          release: () => released = true,
        ),
        throwsFormatException,
      );
      expect(await script.readAsString(), 'old source');
      expect(restored, isTrue);
      expect(released, isTrue);
      expect(await File('${script.path}.pending').exists(), isFalse);
    },
  );

  test('successful validation atomically replaces the existing file', () async {
    final result = await transaction.run(
      destination: script,
      script: 'new source',
      snapshot: () {},
      parse: () async => 'validated',
      restore: () => restored = true,
      release: () => released = true,
    );
    expect(result, 'validated');
    expect(await script.readAsString(), 'new source');
    expect(restored, isFalse);
    expect(released, isTrue);
    expect(await File('${script.path}.pending').exists(), isFalse);
  });

  test(
    'commit failure also restores runtime and removes staging files',
    () async {
      final target = Directory('${directory.path}/blocked.js');
      await target.create();
      await expectLater(
        transaction.run(
          destination: File(target.path),
          script: 'new source',
          snapshot: () {},
          parse: () async => 'validated',
          restore: () => restored = true,
          release: () => released = true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(restored, isTrue);
      expect(await target.exists(), isTrue);
      expect(await File('${target.path}.pending').exists(), isFalse);
    },
  );
}
