import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:zeitlind/components/components.dart';
import 'package:zeitlind/foundation/app.dart';
import 'package:zeitlind/foundation/comic_source/comic_source.dart';
import 'package:zeitlind/network/app_dio.dart';
import 'package:zeitlind/utils/translations.dart';
import '../domain/suwayomi_bridge.dart';
import 'source_import_error.dart';

class SuwayomiConnectView extends StatefulWidget {
  const SuwayomiConnectView({
    super.key,
    required this.onInstall,
    this.repositoryUri,
  });
  final Uri? repositoryUri;
  final Future<void> Function(
    String script,
    String key,
    String authorization,
    String websiteIdentity,
  )
  onInstall;
  @override
  State<SuwayomiConnectView> createState() => _SuwayomiConnectViewState();
}

class _SuwayomiConnectViewState extends State<SuwayomiConnectView> {
  final address = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  List<SuwayomiRemoteSource> sources = [];
  Uri? server;
  String authorization = '';
  String? error;
  bool loading = false;
  String? installing;
  String query = '';

  @override
  void dispose() {
    address.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    if (loading || installing != null) return;
    setState(() {
      loading = true;
      error = null;
      sources = [];
      server = null;
    });
    try {
      final uri = suwayomiBaseUri(address.text);
      final auth = username.text.isEmpty
          ? ''
          : 'Basic ${base64Encode(utf8.encode('${username.text}:${password.text}'))}';
      final response = await AppDio().get<String>(
        uri.resolve('api/v1/source/list').toString(),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          headers: {if (auth.isNotEmpty) 'Authorization': auth},
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      final result = SuwayomiRemoteSource.parse(response.data ?? '');
      if (!mounted) return;
      setState(() {
        server = uri;
        authorization = auth;
        sources = result;
      });
    } catch (e) {
      if (mounted) setState(() => error = sourceImportError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> install(SuwayomiRemoteSource source) async {
    setState(() {
      installing = source.id;
      error = null;
    });
    try {
      final template = await rootBundle.loadString(
        'assets/sources/suwayomi.js',
      );
      await widget.onInstall(
        buildSuwayomiScript(template, server!, source),
        source.key(server!),
        authorization,
        source.websiteIdentity(server!),
      );
      if (mounted) context.showMessage(message: 'Success'.tl);
    } catch (e) {
      if (mounted) setState(() => error = sourceImportError(e));
    } finally {
      if (mounted) setState(() => installing = null);
    }
  }

  @override
  Widget build(BuildContext context) => PopUpWidgetScaffold(
    title: 'Suwayomi · Mihon'.tl,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Use the extensions installed on your Suwayomi server'.tl),
        if (widget.repositoryUri != null)
          Card.outlined(
            child: ListTile(
              title: Text(
                widget.repositoryUri.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Copy'.tl,
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: widget.repositoryUri.toString()),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: address,
          decoration: InputDecoration(
            labelText: 'Server URL'.tl,
            hintText: 'http://192.168.1.2:4567',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: username,
          decoration: InputDecoration(labelText: 'Username (optional)'.tl),
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          decoration: InputDecoration(labelText: 'Password'.tl),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: loading || installing != null ? null : connect,
          icon: const Icon(Icons.link),
          label: Text('Connect'.tl),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (server != null) ...[
          TextButton.icon(
            onPressed: () => launchUrlString(
              server.toString(),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new),
            label: Text('Manage server extensions'.tl),
          ),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search'.tl,
            ),
          ),
          if (sources.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No extensions installed on this server'.tl),
            ),
          for (final source in sources.where(
            (item) => '${item.name} ${item.language}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          ))
            Card.outlined(
              child: ListTile(
                title: Text(source.name),
                subtitle: Text(source.language),
                trailing: IconButton(
                  tooltip: 'Import'.tl,
                  onPressed:
                      installing == null &&
                          ComicSourceManager().findWebsite(
                                source.websiteIdentity(server!),
                              ) ==
                              null
                      ? () => install(source)
                      : null,
                  icon: installing == source.id
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
