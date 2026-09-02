import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models/bidet.dart';

class BidetCard extends StatelessWidget {
  const BidetCard({
    super.key,
    required this.bidet,
    required this.distance,
    required this.onTap,
    this.selected = false,
    this.rated = false,
  });

  final Bidet bidet;
  final String distance;
  final VoidCallback onTap;
  final bool selected;

  /// True when the signed-in user has already rated this one.
  final bool rated;

  /// Icon per bidet type. The previous version switched on a 'hotel' type that
  /// does not exist, so bidet seats silently fell through to the default.
  static IconData _iconFor(BidetType type) => switch (type) {
        BidetType.bidetSeat => Icons.event_seat_outlined,
        BidetType.tabo => Icons.water_drop_outlined,
        BidetType.sprayHose => Icons.shower_outlined,
      };

  /// One hue per type, shared with the map pin and the landing-page legend.
  static Color _colorFor(BidetType type) => switch (type) {
        BidetType.bidetSeat => AppColors.typeSeat,
        BidetType.tabo => AppColors.typeTabo,
        BidetType.sprayHose => AppColors.typeSpray,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.shad;
    final color = _colorFor(bidet.type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: Insets.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? p.muted : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border(
            bottom: BorderSide(color: p.border),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm + 2),
              ),
              child: Icon(_iconFor(bidet.type), color: color, size: 20),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bidet.placeName,
                    style: AppType.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: p.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: bidet.ratingCount > 0
                            ? AppColors.amber
                            : p.mutedForeground,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        bidet.ratingCount > 0
                            ? bidet.rating.toStringAsFixed(1)
                            : 'Unrated',
                        style: AppType.body(
                            size: 12.5, color: p.mutedForeground),
                      ),
                      if (rated) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle,
                            size: 12, color: AppColors.green),
                        const SizedBox(width: 2),
                        Text(
                          'Rated',
                          style: AppType.body(
                              size: 11.5, color: AppColors.green),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          bidet.typeLabel,
                          style: context.texts.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (distance.isNotEmpty)
              Text(
                distance,
                style: AppType.figure(size: 12.5, color: p.foreground),
              ),
          ],
        ),
      ),
    );
  }
}
