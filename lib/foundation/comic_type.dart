import 'package:zeitlind/foundation/comic_source/comic_source.dart';

class ComicType {
  final int value;

  const ComicType(this.value);

  @override
  bool operator ==(Object other) => other is ComicType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  String get sourceKey {
    if (this == local) {
      return "local";
    } else {
      return comicSource?.key ?? 'Unknown:$value';
    }
  }

  ComicSource? get comicSource {
    if (this == local) {
      return null;
    } else {
      return ComicSource.fromIntKey(value);
    }
  }

  static const local = ComicType(0);

  factory ComicType.fromKey(String key) {
    if (key.startsWith('Unknown:')) {
      return ComicType(int.parse(key.substring('Unknown:'.length)));
    }
    if (key == "local") {
      return local;
    } else {
      return ComicType(key.hashCode);
    }
  }
}
