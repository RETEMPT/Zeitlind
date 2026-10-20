import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/components/components.dart';
import 'package:zeitlind/foundation/res.dart';

class DelayedPage extends StatefulWidget {
  const DelayedPage({super.key, required this.response, this.afterLoad});
  final Future<Res<String>> response;
  final Future<void>? afterLoad;
  @override
  State<DelayedPage> createState() => _DelayedPageState();
}

class _DelayedPageState extends LoadingState<DelayedPage, String> {
  @override
  Future<Res<String>> loadData() => widget.response;
  @override
  Future<void> onDataLoaded() async => await widget.afterLoad;
  @override
  Widget buildContent(BuildContext context, String data) => Text(data);
}

void main() {
  testWidgets(
    'leaving before a request completes never updates a disposed page',
    (tester) async {
      final response = Completer<Res<String>>();
      await tester.pumpWidget(
        MaterialApp(home: DelayedPage(response: response.future)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(const Res('done'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('leaving during asynchronous post-processing is also safe', (
    tester,
  ) async {
    final afterLoad = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: DelayedPage(
          response: Future.value(const Res('done')),
          afterLoad: afterLoad.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    afterLoad.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
