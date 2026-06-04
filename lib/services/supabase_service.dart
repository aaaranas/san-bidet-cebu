import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/bidet/bidet_model.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  Stream<List<Bidet>> getBidets() {
    return Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _fetchApproved())
        .distinct();
  }

  Future<List<Bidet>> _fetchApproved() async {
    final data = await _supabase
        .from('bidets')
        .select()
        .eq('status', 'approved');
    return (data as List).map((e) => Bidet.fromMap(e)).toList();
  }

  // All bidets regardless of status — used for GIS export.
  Future<List<Bidet>> getAllBidets() async {
    final data = await _supabase
        .from('bidets')
        .select()
        .order('created_at', ascending: true);
    return (data as List).map((e) => Bidet.fromMap(e)).toList();
  }

  Future<List<Bidet>> getPendingBidets() async {
    final data = await _supabase
        .from('bidets')
        .select()
        .eq('status', 'pending');
    return (data as List).map((e) => Bidet.fromMap(e)).toList();
  }

  // Returns the new bidet's ID so the caller can attach an image.
  Future<String> addBidet(Bidet bidet) async {
    final data = await _supabase
        .from('bidets')
        .insert(bidet.toMap())
        .select('id')
        .single();
    return data['id'] as String;
  }

  // Requires a 'bidet-images' public storage bucket in Supabase.
  Future<String?> uploadBidetImage(
      Uint8List bytes, String bidetId, String extension) async {
    try {
      final fileName =
          '${bidetId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage.from('bidet-images').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$extension'),
          );
      return _supabase.storage.from('bidet-images').getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateBidetImage(String id, String imageUrl) async {
    await _supabase
        .from('bidets')
        .update({'image_url': imageUrl})
        .eq('id', id);
  }

  Future<void> approveBidet(String id) async {
    await _supabase
        .from('bidets')
        .update({'status': 'approved'})
        .eq('id', id);
  }

  Future<void> deleteBidet(String id) async {
    await _supabase.from('bidets').delete().eq('id', id);
  }

  // Rates a bidet across 4 qualification criteria.
  // Requires columns: cleanliness_rating, pressure_rating,
  // accessibility_rating, privacy_rating in the bidets table.
  Future<void> rateBidet(String id, double cleanliness, double pressure,
      double accessibility, double privacy) async {
    final data = await _supabase
        .from('bidets')
        .select(
            'rating, rating_count, cleanliness_rating, pressure_rating, accessibility_rating, privacy_rating')
        .eq('id', id)
        .single();

    final oldCount = (data['rating_count'] ?? 0) as int;
    final newCount = oldCount + 1;

    double avg(String field, double newVal) =>
        (((data[field] ?? 0.0) as num).toDouble() * oldCount + newVal) /
        newCount;

    final overall = (cleanliness + pressure + accessibility + privacy) / 4;

    await _supabase.from('bidets').update({
      'rating': avg('rating', overall),
      'rating_count': newCount,
      'cleanliness_rating': avg('cleanliness_rating', cleanliness),
      'pressure_rating': avg('pressure_rating', pressure),
      'accessibility_rating': avg('accessibility_rating', accessibility),
      'privacy_rating': avg('privacy_rating', privacy),
    }).eq('id', id);
  }
}
