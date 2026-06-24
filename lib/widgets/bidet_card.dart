import 'package:flutter/material.dart';
import '../features/bidet/bidet_model.dart';

class BidetCard extends StatelessWidget {
  final Bidet bidet;
  final String distance;
  final VoidCallback onTap;

  const BidetCard({
    super.key,
    required this.bidet,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconData(), color: _iconColor(), size: 20),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bidet.placeName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 13, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text(
                        bidet.rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bidet.typeLabel,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Distance
            Text(
              distance,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconData() {
    switch (bidet.type) {
      case 'hotel':
        return Icons.hotel;
      case 'tabo':
        return Icons.water_drop;
      default:
        return Icons.wc;
    }
  }

  Color _iconColor() {
    switch (bidet.type) {
      case 'hotel':
        return Colors.purple;
      case 'tabo':
        return Colors.blue;
      default:
        return const Color(0xFF0F172A);
    }
  }
}