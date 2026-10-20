import 'package:flutter/material.dart';
import 'package:zeitlind/utils/translations.dart';

class ResumeReadingCard extends StatelessWidget {
  const ResumeReadingCard({
    super.key,
    required this.title,
    required this.position,
    required this.onResume,
    this.isLoading = false,
  });

  final String title;
  final String position;
  final VoidCallback onResume;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue reading'.tl,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(position),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isLoading ? null : onResume,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text('Resume'.tl),
          ),
        ],
      ),
    ),
  );
}
