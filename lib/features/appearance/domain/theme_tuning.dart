import 'package:flutter/material.dart';

class ThemeTuning {
  const ThemeTuning({
    this.hue = 150,
    this.saturation = .26,
    this.surfaceTint = .12,
  });
  final double hue;
  final double saturation;
  final double surfaceTint;

  factory ThemeTuning.fromValues(
    dynamic hue,
    dynamic saturation,
    dynamic tint,
  ) {
    double read(dynamic value, double fallback, double max) =>
        value is num && value.isFinite
        ? value.toDouble().clamp(0, max)
        : fallback;
    return ThemeTuning(
      hue: read(hue, 150, 360),
      saturation: read(saturation, .26, 1),
      surfaceTint: read(tint, .12, 1),
    );
  }

  Color get seed => HSLColor.fromAHSL(1, hue, saturation, .36).toColor();

  ThemeTuning copyWith({
    double? hue,
    double? saturation,
    double? surfaceTint,
  }) => ThemeTuning(
    hue: hue ?? this.hue,
    saturation: saturation ?? this.saturation,
    surfaceTint: surfaceTint ?? this.surfaceTint,
  );
}
