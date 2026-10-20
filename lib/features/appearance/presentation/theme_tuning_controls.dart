import 'package:flutter/material.dart';
import 'package:zeitlind/utils/translations.dart';
import '../domain/theme_tuning.dart';

class ThemeTuningControls extends StatelessWidget {
  const ThemeTuningControls({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });
  final ThemeTuning value;
  final ValueChanged<ThemeTuning> onChanged;
  final void Function(ThemeTuning tuning, bool changeAccent) onCommit;

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String title,
      double current,
      double max,
      ThemeTuning Function(double) change,
      bool accent,
    ) => Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title.tl)),
            Text(
              max == 360
                  ? '${current.round()}°'
                  : '${(current * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Slider(
          value: current,
          min: 0,
          max: max,
          label: max == 360
              ? '${current.round()}°'
              : '${(current * 100).round()}%',
          onChanged: (number) => onChanged(change(number)),
          onChangeEnd: (number) => onCommit(change(number), accent),
        ),
      ],
    );
    return Card.outlined(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (hue, label) in [
                  (150.0, 'Green'),
                  (210.0, 'Blue'),
                  (280.0, 'Purple'),
                  (340.0, 'Pink'),
                  (25.0, 'Orange'),
                ])
                  Tooltip(
                    message: label.tl,
                    child: Semantics(
                      label: label.tl,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          final next = value.copyWith(hue: hue, saturation: .3);
                          onChanged(next);
                          onCommit(next, true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: HSLColor.fromAHSL(
                              1,
                              hue,
                              .3,
                              .4,
                            ).toColor(),
                            child: (value.hue - hue).abs() < 1
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            slider('Hue', value.hue, 360, (v) => value.copyWith(hue: v), true),
            slider(
              'Saturation',
              value.saturation,
              1,
              (v) => value.copyWith(saturation: v),
              true,
            ),
            slider(
              'Background tint',
              value.surfaceTint,
              1,
              (v) => value.copyWith(surfaceTint: v),
              false,
            ),
          ],
        ),
      ),
    );
  }
}
