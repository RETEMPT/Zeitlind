import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/core/version.dart';
import 'package:zeitlind/app/app_identity.dart';
import 'dart:io';

void main() {
  test('runtime identity matches the package release version', () {
    final package = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(package)!.group(1);
    expect(AppIdentity.version, version);
  });
  test('an omitted native minimum version is compatible', () {
    for (final minimum in [null, '', '  ', '1.0', '2.1.0']) {
      expect(requiresNewerAppVersion(minimum, '2.1.0'), isFalse);
    }
    expect(requiresNewerAppVersion('2.2.0', '2.1.0'), isTrue);
    expect(
      () => requiresNewerAppVersion('bad', '2.1.0'),
      throwsFormatException,
    );
  });
  test('handles shorter versions and build metadata without range errors', () {
    expect(compareVersions('2', '1.6.3'), greaterThan(0));
    expect(compareVersions('v2.0.0+200', '2.0'), 0);
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
  });
  test(
    'orders prereleases numerically and preserves legacy hotfix ordering',
    () {
      expect(compareVersions('2.0.0-rc.10', '2.0.0-rc.2'), greaterThan(0));
      expect(compareVersions('2.0.0', '2.0.0-rc.10'), greaterThan(0));
      expect(compareVersions('1.0.0-hotfix', '1.0.0'), greaterThan(0));
    },
  );
  test('invalid manifests produce an actionable format error', () {
    expect(() => compareVersions('garbage', '2.0.0'), throwsFormatException);
  });
}
