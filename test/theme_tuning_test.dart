import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeitlind/app/theme.dart';
import 'package:zeitlind/features/appearance/domain/theme_tuning.dart';

void main() {
  test('default light and dark palettes contain no green tint', () {
    for (final brightness in Brightness.values) {
      final colors = ZeitlindTheme.create(brightness: brightness).colorScheme;
      for (final color in [
        colors.primary,
        colors.onPrimary,
        colors.primaryContainer,
        colors.secondary,
        colors.surface,
        colors.surfaceContainerHigh,
        colors.onSurface,
      ]) {
        expect(color.r, closeTo(color.g, 1 / 255));
        expect(color.g, closeTo(color.b, 1 / 255));
      }
    }
  });
  test('invalid imported theme values safely fall back or clamp', () {
    final tuning = ThemeTuning.fromValues(double.nan, 'bad', 9);
    expect(tuning.hue, 0);
    expect(tuning.saturation, 0);
    expect(tuning.surfaceTint, 1);
  });
  test('background tint changes surfaces independently of the accent', () {
    final plain = ZeitlindTheme.create(
      tuning: const ThemeTuning(surfaceTint: 0),
    );
    final tinted = ZeitlindTheme.create(
      tuning: const ThemeTuning(surfaceTint: 1),
    );
    expect(plain.colorScheme.primary, tinted.colorScheme.primary);
    expect(
      plain.colorScheme.surfaceContainerHigh,
      isNot(tinted.colorScheme.surfaceContainerHigh),
    );
  });
  test('dark mode keeps readable light text on dark surfaces', () {
    final theme = ZeitlindTheme.create(brightness: Brightness.dark);
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(.6));
    expect(theme.colorScheme.surface.computeLuminance(), lessThan(.05));
  });
  test('maximum background tint preserves readable text in both modes', () {
    for (final brightness in Brightness.values) {
      final theme = ZeitlindTheme.create(
        brightness: brightness,
        primary: Colors.deepPurple,
        tuning: const ThemeTuning(surfaceTint: 1),
      );
      final fg = theme.colorScheme.onSurface.computeLuminance();
      final bg = theme.colorScheme.surfaceContainerHighest.computeLuminance();
      final contrast =
          ((fg > bg ? fg : bg) + .05) / ((fg < bg ? fg : bg) + .05);
      expect(contrast, greaterThan(4.5));
    }
  });
}
