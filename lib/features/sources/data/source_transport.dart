import 'dart:async';
import 'package:zeitlind/network/app_dio.dart';
import '../domain/source_diagnostics.dart';
import 'resilient_source_loader.dart';

Future<SourceTextResponse> fetchSourceText(Uri uri) =>
    const ResilientSourceLoader(_requestSourceText).load(uri);

Future<String> loadSourceText(Uri uri) async =>
    (await fetchSourceText(uri)).content;

Future<String> _requestSourceText(Uri uri) async {
  final token = CancelToken();
  final deadline = Timer(
    const Duration(seconds: 20),
    () => token.cancel('Source request timed out'),
  );
  try {
    final response = await AppDio().get<String>(
      uri.toString(),
      cancelToken: token,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'cache-time': 'no'},
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('HTTP ${response.statusCode}: ${uri.host}');
    }
    return response.data!;
  } finally {
    deadline.cancel();
  }
}
