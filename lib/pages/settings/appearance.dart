part of 'settings_page.dart';

class AppearanceSettings extends StatefulWidget {
  const AppearanceSettings({super.key});

  @override
  State<AppearanceSettings> createState() => _AppearanceSettingsState();
}

class _AppearanceSettingsState extends State<AppearanceSettings> {
  late ThemeTuning tuning = ThemeTuning.fromValues(
    appdata.settings['customThemeHue'],
    appdata.settings['customThemeSaturation'],
    appdata.settings['themeSurfaceTint'],
  );

  void commit(ThemeTuning value, bool changeAccent) {
    setState(() => tuning = value);
    appdata.settings['customThemeHue'] = value.hue;
    appdata.settings['customThemeSaturation'] = value.saturation;
    appdata.settings['themeSurfaceTint'] = value.surfaceTint;
    if (changeAccent) appdata.settings['color'] = 'custom';
    appdata.saveData();
    App.forceRebuild();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Appearance".tl)),
        SelectSetting(
          title: "Theme Mode".tl,
          settingKey: "theme_mode",
          optionTranslation: {
            "system": "System".tl,
            "light": "Light".tl,
            "dark": "Dark".tl,
          },
          onChanged: () async {
            App.forceRebuild();
          },
        ).toSliver(),
        SelectSetting(
          title: "Theme Color".tl,
          settingKey: "color",
          optionTranslation: {
            "monochrome": "Black and white".tl,
            "system": "System".tl,
            "red": "Red".tl,
            "pink": "Pink".tl,
            "purple": "Purple".tl,
            "green": "Green".tl,
            "custom": "Custom".tl,
            "orange": "Orange".tl,
            "blue": "Blue".tl,
          },
          onChanged: () async {
            App.forceRebuild();
          },
        ).toSliver(),
        ThemeTuningControls(
          value: tuning,
          onChanged: (value) => setState(() => tuning = value),
          onCommit: commit,
        ).toSliver(),
        TextButton.icon(
          onPressed: () {
            appdata.settings['color'] = 'monochrome';
            commit(const ThemeTuning(), false);
          },
          icon: const Icon(Icons.restart_alt),
          label: Text('Reset theme'.tl),
        ).toSliver(),
        if (App.isAndroid)
          ListTile(
            leading: const Icon(Icons.add_to_home_screen),
            title: Text('Add to home screen'.tl),
            onTap: () async {
              try {
                final result = await const MethodChannel(
                  'zeitlind/method_channel',
                ).invokeMethod<String>('requestLauncherShortcut');
                if (!context.mounted) return;
                context.showMessage(
                  message: switch (result) {
                    'requested' => 'Confirm the shortcut in your launcher'.tl,
                    'alreadyAdded' =>
                      'The home screen shortcut already exists'.tl,
                    _ =>
                      'Your launcher does not support pinning. Find Zeitlind in the app drawer'
                          .tl,
                  },
                );
              } catch (e) {
                if (context.mounted) context.showMessage(message: e.toString());
              }
            },
          ).toSliver(),
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
        ),
      ],
    );
  }
}
