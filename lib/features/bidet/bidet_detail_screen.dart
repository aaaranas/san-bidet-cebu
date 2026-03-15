import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'bidet_model.dart';

class BidetDetailScreen extends StatelessWidget {
  final Bidet bidet;
  final String distance;

  const BidetDetailScreen({
    super.key,
    required this.bidet,
    required this.distance,
  });

  static const _green = Color(0xFF1A6B3C);

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
          // Green header
          Container(
            color: _green,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                    _badge(distance),
                    _badge('Free'),
                  ],
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Location', bidet.floor),
                _detailRow('Type', bidet.typeLabel),
                _detailRow('Added',
                    '${bidet.createdAt.day}/${bidet.createdAt.month}/${bidet.createdAt.year}'),
                _detailRow('Total ratings', '${bidet.ratingCount}'),
                const SizedBox(height: 20),

                // Rate button
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

  Widget _starRow(double rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
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
        color: Colors.white.withOpacity(0.2),
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
    int selected = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rate this bidet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => selected = i + 1),
                child: Icon(
                  i < selected
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade500,
                  size: 36,
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == 0
                  ? null
                  : () async {
                      await FirestoreService()
                          .rateBidet(bidet.id, selected.toDouble());
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
}