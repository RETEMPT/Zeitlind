import 'package:flutter/material.dart';

class ThemeTuning {
  const ThemeTuning({this.hue = 0, this.saturation = 0, this.surfaceTint = 0});
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
      hue: read(hue, 0, 360),
      saturation: read(saturation, 0, 1),
      surfaceTint: read(tint, 0, 1),
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
