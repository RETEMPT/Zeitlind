import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/foundation/comic_type.dart';

void main() {
  test('a removed source keeps its downloaded comics identity', () {
    const type = ComicType(789012);
    expect(type.sourceKey, 'Unknown:789012');
    expect(ComicType.fromKey(type.sourceKey), type);
  });
  test('local identity stays compatible with existing backups', () {
    expect(ComicType.fromKey('local'), ComicType.local);
    expect(ComicType.local.sourceKey, 'local');
  });
}
