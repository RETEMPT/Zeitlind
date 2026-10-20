import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/core/version.dart';

void main() {
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
