import 'package:flutter/material.dart';
import 'package:zeitlind/features/appearance/domain/theme_tuning.dart';

abstract final class ZeitlindTheme {
  static const accent = Color(0xFF426A5A);

  static ThemeData create({
    Brightness brightness = Brightness.light,
    Color primary = accent,
    ThemeTuning tuning = const ThemeTuning(),
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    final dark = brightness == Brightness.dark;
    final neutral = dark ? const Color(0xFF171A18) : const Color(0xFFFAF9F6);
    Color surface(double amount) {
      final base = Color.lerp(
        neutral,
        dark ? const Color(0xFF41473F) : const Color(0xFFDFE4DC),
        amount * .3,
      )!;
      return Color.alphaBlend(
        primary.withValues(
          alpha: tuning.surfaceTint * amount * (dark ? .18 : .14),
        ),
        base,
      );
    }

    final generated = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );
    final colors = generated.copyWith(
      surface: surface(.12),
      onSurface: dark ? const Color(0xFFE6E8E2) : const Color(0xFF252C28),
      onSurfaceVariant: dark
          ? const Color(0xFFB1B9B0)
          : const Color(0xFF6E776F),
      surfaceContainerLowest: dark
          ? const Color(0xFF121512)
          : const Color(0xFFFFFEFC),
      surfaceContainerLow: surface(.32),
      surfaceContainer: surface(.5),
      surfaceContainerHigh: surface(.7),
      surfaceContainerHighest: surface(.9),
      outlineVariant: dark ? const Color(0xFF343C35) : const Color(0xFFE0E4DB),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.surface,
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: 25,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 21,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.6),
        bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.5),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: .6,
        space: 24,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 3,
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
    );
  }
}
