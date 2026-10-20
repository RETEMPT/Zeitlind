import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../data/source_catalog_repository.dart';

class StarterSource {
  const StarterSource(this.key, this.name, this.sha256, {this.fileName});
  final String key;
  final String name;
  final String sha256;
  final String? fileName;
  Uri get uri => Uri.parse(
    'https://git.nyne.dev/nyne/venera-configs/raw/commit/$nativeStarterRevision/${fileName ?? '$key.js'}',
  );
}

const nativeStarterRevision = 'af42a9b39575117212ca163bc4ea7de388a094aa';

/// Links to fixed, audited upstream revisions; no remote scripts are bundled.
const starterSources = [
  StarterSource(
    "copy_manga",
    "拷贝漫画",
    "5c37869baaed569b5806e7179c8a7b65e85f09d1427dac2d4c42e8db43893a75",
    fileName: "copy_manga.js",
  ),
  StarterSource(
    "Komiic",
    "Komiic",
    "a467325b6be833afc676099e66563a9af849641ef9e548d1f2304cd2d883d1e8",
    fileName: "komiic.js",
  ),
  StarterSource(
    "baozi",
    "包子漫画",
    "6ccb52e7734e54c6dfcfcb9729adb46409f1e5c9d83bbda54313b066013e4255",
    fileName: "baozi.js",
  ),
  StarterSource(
    "picacg",
    "Picacg",
    "fed53c55e2f66fa10302f89b9e39c837e267ebb61d40a1c722033caddb400f86",
    fileName: "picacg.js",
  ),
  StarterSource(
    "nhentai",
    "nhentai",
    "b7e4ce84998cab398be3ec45bd16a40ef1c25e3a267afbebfea0020e7b9ac237",
    fileName: "nhentai.js",
  ),
  StarterSource(
    "wnacg",
    "紳士漫畫",
    "21ec0499b632e02243bf801bfc3eef5d0bb4abc7c5b37595687f50708184cede",
    fileName: "wnacg.js",
  ),
  StarterSource(
    "ehentai",
    "ehentai",
    "a6af9c97e6c5cbf81bf39f5b2729ee2c1a45ecb738e43b7182c234ce50ce5439",
    fileName: "ehentai.js",
  ),
  StarterSource(
    "jm",
    "禁漫天堂",
    "a91bc8cc8b1a69eda20cdf2a04deea3fe0522baf2de84caa0c851211cb5f78ad",
    fileName: "jm.js",
  ),
  StarterSource(
    "manga_dex",
    "MangaDex",
    "5c0e59731aa37853c5f07920f3251978046b5a60138ef3d39613040121da8386",
    fileName: "manga_dex.js",
  ),
  StarterSource(
    "ikmmh",
    "爱看漫",
    "d2797d9747df97dbbb1ef25a50bef82c989e43b132314d8eea0063aa98d52ae5",
    fileName: "ikmmh.js",
  ),
  StarterSource(
    "shonen_jump_plus",
    "少年ジャンプ＋",
    "a8a18249a4f30d907b82eec276d9bda0631c975118ae75dfcb252a6a9cdbe264",
    fileName: "shonen_jump_plus.js",
  ),
  StarterSource(
    "hitomi",
    "hitomi.la",
    "af174079e017718268c1e55b4c955228aab80e97813fe5da15798050840c5d92",
    fileName: "hitomi.js",
  ),
  StarterSource(
    "comick",
    "comick",
    "8e775b2381419d6cc8f912abb11158ee8ab5fb216b68441c6ea18e7bab135562",
    fileName: "comick.js",
  ),
  StarterSource(
    "ykmh",
    "优酷漫画",
    "c03ea3696420c3e71b0a638c9d8a3a3666d20ce0d0095e6b13970a27186fea4b",
    fileName: "ykmh.js",
  ),
  StarterSource(
    "zaimanhua",
    "再漫画",
    "96b89df7bcdaa2f3c1a02d15ce19575c5fdffceb768083dff552c8afc5969f1b",
    fileName: "zaimanhua.js",
  ),
  StarterSource(
    "ManHuaGui",
    "漫画柜",
    "a5bf6c633e0ce728361dded097424b829134d618128f72b571e42525e8950128",
    fileName: "manhuagui.js",
  ),
  StarterSource(
    "manwaba",
    "漫蛙吧",
    "233d888b6b286aa43731f1b887de9c75c1d633e85caa123c9758eca712b16a46",
    fileName: "manwaba.js",
  ),
  StarterSource(
    "lanraragi",
    "Lanraragi",
    "360c68843b8a04153a12411af1a9648078ed42939a57290b3c85539b62dab7d6",
    fileName: "lanraragi.js",
  ),
  StarterSource(
    "komga",
    "Komga",
    "2aa5b4e7d4b32bf282f86168b22af091d7436f4e3ad603defb7b6df738a36908",
    fileName: "komga.js",
  ),
  StarterSource(
    "comic_walker",
    "カドコミ",
    "fa353ab61baba196e0a5375925caf04f4d258adf146f8d750e9ac3c305926b06",
    fileName: "comic_walker.js",
  ),
  StarterSource(
    "mh1234",
    "漫画1234",
    "17d910952f7de6d47b10cca2302193e84b7ae1873219f91dfa927d0cc4e8897e",
    fileName: "mh1234.js",
  ),
  StarterSource(
    "ccc",
    "CCC追漫台",
    "d7db634cd6a66782fb69787d8f0209a39f47e814a1abba7c9ebdb5e4fca3fde9",
    fileName: "ccc.js",
  ),
  StarterSource(
    "goda",
    "GoDa漫画",
    "cf9dc9815dc5544cb5f9cf5cc48f894d0aefb684ee17801cdef63264becd1d75",
    fileName: "goda.js",
  ),
  StarterSource(
    "mh18",
    "18漫画",
    "88ba802dbc33988702b9cc3b9e8d2b669acc46d3f76d2040fd91832504a637ee",
    fileName: "mh18.js",
  ),
  StarterSource(
    "mxs",
    "漫小肆",
    "da2c222eda825b77eb3b67ac09ec33b70bc2512cd5fc867fbe9b958df55037f8",
    fileName: "mxs.js",
  ),
  StarterSource(
    "manhuaren",
    "漫画人",
    "6ec9b7ca3f843698625fed1291b25708638a506be486f6f113af71dcd71b3bf8",
    fileName: "manhuaren.js",
  ),
  StarterSource(
    "hcomic",
    "H-Comic",
    "0490859b636ca796a8a16b044724fed556bcfcfcdefae02e6b1e81fd6d8393d2",
    fileName: "hcomic.js",
  ),
  StarterSource(
    "jcomic",
    "jcomic.net",
    "afd7dc75ac1216eec39350ca7a7228d836183b9ec61751f3064dcc53a97422b1",
    fileName: "jcomic.js",
  ),
  StarterSource(
    "hot_manga",
    "热辣漫画",
    "d5f440d1a2e5d41e53189eb8d3e7ba19864c43b1d6592e20eb65ef326a410fd4",
    fileName: "hot_manga.js",
  ),
  StarterSource(
    "kavita",
    "Kavita",
    "65173ae4eb4a57f33f867a67f9030078b49b7386b8a02ab5829e1966f4d47763",
    fileName: "kavita.js",
  ),
  StarterSource(
    "happy",
    "嗨皮漫画",
    "656f038a7b134135bca51e1eaca1c3e1ba761d2daa8d89e26d085b1bd8950180",
    fileName: "happy.js",
  ),
];

class StarterSourceResult {
  const StarterSourceResult(this.completed, this.errors);
  final Set<String> completed;
  final Map<String, Object> errors;
}

class StarterSourceInstaller {
  const StarterSourceInstaller(this.load);
  final SourceTextLoader load;

  Future<StarterSourceResult> run({
    Set<String> completed = const {},
    required bool Function(StarterSource source) isInstalled,
    required Future<void> Function(StarterSource source, String script) install,
    Future<void> Function(Set<String> completed)? onProgress,
    List<StarterSource> sources = starterSources,
  }) async {
    final done = Set<String>.of(completed);
    final errors = <String, Object>{};
    for (final source in sources) {
      if (done.contains(source.key)) continue;
      try {
        if (!isInstalled(source)) {
          final script = await load(
            source.uri,
          ).timeout(const Duration(seconds: 45));
          if (sha256.convert(utf8.encode(script)).toString() != source.sha256) {
            throw const FormatException(
              'The basic source checksum does not match the audited version',
            );
          }
          await install(source, script);
        }
        done.add(source.key);
        await onProgress?.call(Set.unmodifiable(done));
      } catch (e) {
        done.remove(source.key);
        errors[source.key] = e;
      }
    }
    return StarterSourceResult(done, errors);
  }
}
