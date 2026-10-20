import 'package:zeitlind/app/theme.dart';
import 'package:zeitlind/features/appearance/domain/theme_tuning.dart';
import 'package:zeitlind/features/sources/application/starter_source_setup.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zeitlind/foundation/log.dart';
import 'package:zeitlind/pages/auth_page.dart';
import 'package:zeitlind/pages/main_page.dart';
import 'package:zeitlind/utils/io.dart';
import 'package:window_manager/window_manager.dart';
import 'components/components.dart';
import 'components/window_frame.dart';
import 'foundation/app.dart';
import 'foundation/appdata.dart';
import 'headless.dart';
import 'init.dart';

void main(List<String> args) {
  if (args.contains('--headless')) {
    runHeadlessMode(args);
    return;
  }
  if (runWebViewTitleBarWidget(args)) return;
  overrideIO(() {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        LicenseRegistry.addLicense(() async* {
          yield LicenseEntryWithLineBreaks([
            'manga-source-index',
          ], await rootBundle.loadString('assets/sources/INDEX-LICENSE'));
          yield LicenseEntryWithLineBreaks([
            'Zeitlind',
          ], await rootBundle.loadString('NOTICE'));
          yield LicenseEntryWithLineBreaks([
            'Zeitlind',
          ], await rootBundle.loadString('LICENSE'));
        });
        await init();
        runApp(const MyApp());
        if (App.isDesktop) {
          await windowManager.ensureInitialized();
          windowManager.waitUntilReadyToShow().then((_) async {
            await windowManager.setTitleBarStyle(
              TitleBarStyle.hidden,
              windowButtonVisibility: App.isMacOS,
            );
            if (App.isLinux) {
              await windowManager.setBackgroundColor(Colors.transparent);
            }
            await windowManager.setMinimumSize(const Size(500, 600));
            var placement = await WindowPlacement.loadFromFile();
            if (App.isLinux) {
              await windowManager.show();
              await placement.applyToWindow();
            } else {
              await placement.applyToWindow();
              await windowManager.show();
            }

            WindowPlacement.loop();
          });
        }
      },
      (error, stack) {
        Log.error("Unhandled Exception", error, stack);
      },
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    App.registerForceRebuild(forceRebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addObserver(this);
    checkUpdates();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => starterSourceSetup.configure(),
    );
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    hideContentOverlay?.remove();
    App.registerForceRebuild(() {});
    super.dispose();
  }

  bool isAuthPageActive = false;

  OverlayEntry? hideContentOverlay;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!App.isMobile || !appdata.settings['authorizationRequired']) {
      return;
    }
    if (state == AppLifecycleState.inactive && hideContentOverlay == null) {
      hideContentOverlay = OverlayEntry(
        builder: (context) {
          return Positioned.fill(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: App.rootContext.colorScheme.surface,
            ),
          );
        },
      );
      Overlay.of(App.rootContext).insert(hideContentOverlay!);
    } else if (hideContentOverlay != null &&
        state == AppLifecycleState.resumed) {
      hideContentOverlay!.remove();
      hideContentOverlay = null;
    }
    if (state == AppLifecycleState.hidden &&
        !isAuthPageActive &&
        !IO.isSelectingFiles) {
      isAuthPageActive = true;
      App.rootContext.to(
        () => AuthPage(
          onSuccessfulAuth: () {
            App.rootContext.pop();
            isAuthPageActive = false;
          },
        ),
      );
    }
    super.didChangeAppLifecycleState(state);
  }

  void forceRebuild() {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
  }

  Color translateColorSetting() {
    return switch (appdata.settings['color']) {
      'red' => Colors.red,
      'pink' => Colors.pink,
      'purple' => Colors.purple,
      'monochrome' => ZeitlindTheme.accent,
      'green' => const Color(0xFF426A5A),
      'custom' => _themeTuning.seed,
      'orange' => Colors.orange,
      'blue' => Colors.blue,
      'yellow' => Colors.yellow,
      'cyan' => Colors.cyan,
      _ => ZeitlindTheme.accent,
    };
  }

  ThemeTuning get _themeTuning => ThemeTuning.fromValues(
    appdata.settings['customThemeHue'],
    appdata.settings['customThemeSaturation'],
    appdata.settings['themeSurfaceTint'],
  );

  ThemeData getTheme(
    Color primary,
    Color? secondary,
    Color? tertiary,
    Brightness brightness,
  ) {
    String? font;
    List<String>? fallback;
    if (App.isLinux || App.isWindows) {
      font = 'Noto Sans CJK';
      fallback = [
        'Segoe UI',
        'Noto Sans SC',
        'Noto Sans TC',
        'Noto Sans',
        'Microsoft YaHei',
        'PingFang SC',
        'Arial',
        'sans-serif',
      ];
    }
    return ZeitlindTheme.create(
      primary: primary,
      monochrome: appdata.settings['color'] == 'monochrome',
      brightness: brightness,
      tuning: _themeTuning,
      fontFamily: font,
      fontFamilyFallback: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (appdata.settings['authorizationRequired']) {
      home = AuthPage(
        onSuccessfulAuth: () {
          App.rootContext.toReplacement(() => const MainPage());
        },
      );
    } else {
      home = const MainPage();
    }
    return DynamicColorBuilder(
      builder: (light, dark) {
        Color? primary, secondary, tertiary;
        if (appdata.settings['color'] != 'system' ||
            light == null ||
            dark == null) {
          primary = translateColorSetting();
        } else {
          primary = light.primary;
          secondary = light.secondary;
          tertiary = light.tertiary;
        }
        return MaterialApp(
          title: "Zeitlind",
          home: home,
          debugShowCheckedModeBanner: false,
          theme: getTheme(primary, secondary, tertiary, Brightness.light),
          navigatorKey: App.rootNavigatorKey,
          darkTheme: getTheme(primary, secondary, tertiary, Brightness.dark),
          themeMode: switch (appdata.settings['theme_mode']) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          color: Colors.transparent,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: () {
            var lang = appdata.settings['language'];
            if (lang == 'system') {
              return null;
            }
            return switch (lang) {
              'zh-CN' => const Locale('zh', 'CN'),
              'zh-TW' => const Locale('zh', 'TW'),
              'en-US' => const Locale('en'),
              _ => null,
            };
          }(),
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('zh', 'TW'),
            Locale('en'),
          ],
          builder: (context, widget) {
            ErrorWidget.builder = (details) {
              Log.error(
                "Unhandled Exception",
                "${details.exception}\n${details.stack}",
              );
              return Material(
                child: Center(child: Text(details.exception.toString())),
              );
            };
            if (widget != null) {
              /// 如果无法检测到状态栏高度设定指定高度
              /// https://github.com/flutter/flutter/issues/161086
              var isPaddingCheckError =
                  MediaQuery.of(context).viewPadding.top <= 0 ||
                  MediaQuery.of(context).viewPadding.top > 200;

              if (isPaddingCheckError && Platform.isAndroid) {
                widget = MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    viewPadding: const EdgeInsets.only(top: 15, bottom: 15),
                    padding: const EdgeInsets.only(top: 15, bottom: 15),
                  ),
                  child: widget,
                );
              }

              widget = OverlayWidget(widget);
              if (App.isDesktop) {
                widget = Shortcuts(
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.escape):
                        VoidCallbackIntent(App.pop),
                  },
                  child: MouseBackDetector(
                    onTapDown: App.pop,
                    child: WindowFrame(widget),
                  ),
                );
              }
              return _SystemUiProvider(
                Material(
                  color: App.isLinux ? Colors.transparent : null,
                  child: widget,
                ),
              );
            }
            throw ('widget is null');
          },
        );
      },
    );
  }
}

class _SystemUiProvider extends StatelessWidget {
  const _SystemUiProvider(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    SystemUiOverlayStyle systemUiStyle;
    if (brightness == Brightness.light) {
      systemUiStyle = SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    } else {
      systemUiStyle = SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: child,
    );
  }
}
