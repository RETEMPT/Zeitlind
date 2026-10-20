part of 'settings_page.dart';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  bool isCheckingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final updatesConfigured =
        AppIdentity.updateManifest.isNotEmpty &&
        AppIdentity.releases.isNotEmpty;
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text('About'.tl)),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppIdentity.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(App.version),
              const SizedBox(height: 12),
              Text('Your library, your pace.'.tl),
            ],
          ),
        ).toSliver(),
        if (updatesConfigured) ...[
          ListTile(
            title: Text('Check for updates'.tl),
            trailing: Button.filled(
              isLoading: isCheckingUpdate,
              child: Text('Check'.tl),
              onPressed: () async {
                if (isCheckingUpdate) return;
                setState(() => isCheckingUpdate = true);
                try {
                  await checkUpdateUi();
                } finally {
                  if (mounted) setState(() => isCheckingUpdate = false);
                }
              },
            ),
          ).toSliver(),
          _SwitchSetting(
            title: 'Check for updates on startup'.tl,
            settingKey: 'checkUpdateOnStart',
          ).toSliver(),
        ],
        if (AppIdentity.repository.isNotEmpty)
          ListTile(
            title: Text('Project repository'.tl),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrlString(AppIdentity.repository),
          ).toSliver(),
        ListTile(
          title: Text('Open-source licenses'.tl),
          subtitle: const Text('GPL-3.0'),
          leading: const Icon(Icons.policy_outlined),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppIdentity.name,
            applicationVersion: App.version,
          ),
        ).toSliver(),
      ],
    );
  }
}

Future<bool> checkUpdate() async {
  if (AppIdentity.updateManifest.isEmpty || AppIdentity.releases.isEmpty) {
    return false;
  }
  final response = await AppDio().get<String>(
    AppIdentity.updateManifest,
    options: Options(
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final data = loadYaml(response.data ?? '');
  return data is Map &&
      data['version'] is String &&
      compareVersions(data['version'] as String, App.version) > 0;
}

Future<void> checkUpdateUi([
  bool showMessageIfNoUpdate = true,
  bool delay = false,
]) async {
  try {
    if (await checkUpdate()) {
      if (delay) await Future.delayed(const Duration(seconds: 2));
      await showDialog<void>(
        context: App.rootContext,
        builder: (context) => AlertDialog(
          title: Text('New version available'.tl),
          content: Text(
            'A new version is available. Do you want to update now?'.tl,
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
                launchUrlString(AppIdentity.releases);
              },
              child: Text('Update'.tl),
            ),
          ],
        ),
      );
    } else if (showMessageIfNoUpdate) {
      App.rootContext.showMessage(message: 'No new version available'.tl);
    }
  } catch (e, s) {
    Log.error('Check Update', e, s);
    if (showMessageIfNoUpdate) {
      App.rootContext.showMessage(message: e.toString());
    }
  }
}
