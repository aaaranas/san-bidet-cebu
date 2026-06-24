import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import 'bidet_model.dart';

class BidetDetailScreen extends StatelessWidget {
  final Bidet bidet;
  final String distance;

  const BidetDetailScreen({
    super.key,
    required this.bidet,
    required this.distance,
  });

  static const _green = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(bidet.placeName,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        children: [
          if (bidet.imageUrl != null)
            CachedNetworkImage(
              imageUrl: bidet.imageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 200,
                color: Colors.grey.shade100,
                child: Icon(Icons.image_not_supported,
                    color: Colors.grey.shade400, size: 40),
              ),
            ),
          Container(
            color: _green,
            padding: EdgeInsets.fromLTRB(
                20, bidet.imageUrl != null ? 16 : 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bidet.floor,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      bidet.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    _starRow(bidet.rating),
                    const SizedBox(width: 8),
                    Text('${bidet.ratingCount} ratings',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _badge(bidet.typeLabel),
                    if (distance.isNotEmpty) _badge(distance),
                    _badge('Free'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bidet.ratingCount > 0) ...[
                  const Text('Ratings breakdown',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _ratingBar('Cleanliness', bidet.cleanlinessRating),
                  _ratingBar('Water Pressure', bidet.pressureRating),
                  _ratingBar('Accessibility', bidet.accessibilityRating),
                  _ratingBar('Privacy', bidet.privacyRating),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                ],
                _detailRow('Location', bidet.floor),
                _detailRow('Type', bidet.typeLabel),
                _detailRow('Added',
                    '${bidet.createdAt.day}/${bidet.createdAt.month}/${bidet.createdAt.year}'),
                _detailRow('Total ratings', '${bidet.ratingCount}'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showRatingDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Rate this bidet',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 5,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation(_green),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _green)),
        ],
      ),
    );
  }

  Widget _starRow(double rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round()
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          color: Colors.amber.shade300,
          size: 18,
        );
      }),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int cleanliness = 0;
    int pressure = 0;
    int accessibility = 0;
    int privacy = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rate this bidet',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _criteriaRow('Cleanliness', cleanliness,
                  (v) => setDialogState(() => cleanliness = v)),
              const SizedBox(height: 12),
              _criteriaRow('Water Pressure', pressure,
                  (v) => setDialogState(() => pressure = v)),
              const SizedBox(height: 12),
              _criteriaRow('Accessibility', accessibility,
                  (v) => setDialogState(() => accessibility = v)),
              const SizedBox(height: 12),
              _criteriaRow('Privacy', privacy,
                  (v) => setDialogState(() => privacy = v)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (cleanliness == 0 ||
                      pressure == 0 ||
                      accessibility == 0 ||
                      privacy == 0)
                  ? null
                  : () async {
                      await SupabaseService().rateBidet(
                        bidet.id,
                        cleanliness.toDouble(),
                        pressure.toDouble(),
                        accessibility.toDouble(),
                        privacy.toDouble(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Rating submitted!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _criteriaRow(
      String label, int selected, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => onChanged(i + 1),
                child: Icon(
                  i < selected
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade500,
                  size: 26,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
