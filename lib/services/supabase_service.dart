import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/bidet/bidet_model.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Stream approved bidets (polls every 5 seconds for web)
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

  // Get pending bidets (admin only)
  Future<List<Bidet>> getPendingBidets() async {
    final data = await _supabase
        .from('bidets')
        .select()
        .eq('status', 'pending');
    return (data as List).map((e) => Bidet.fromMap(e)).toList();
  }

  // Submit a new bidet
  Future<void> addBidet(Bidet bidet) async {
    await _supabase.from('bidets').insert(bidet.toMap());
  }

  // Approve a bidet
  Future<void> approveBidet(String id) async {
    await _supabase
        .from('bidets')
        .update({'status': 'approved'})
        .eq('id', id);
  }

  // Delete/reject a bidet
  Future<void> deleteBidet(String id) async {
    await _supabase.from('bidets').delete().eq('id', id);
  }

  // Rate a bidet
  Future<void> rateBidet(String id, double newRating) async {
    final data = await _supabase
        .from('bidets')
        .select('rating, rating_count')
        .eq('id', id)
        .single();

    final oldRating = (data['rating'] ?? 0.0).toDouble();
    final oldCount = (data['rating_count'] ?? 0) as int;
    final updatedCount = oldCount + 1;
    final updatedRating =
        ((oldRating * oldCount) + newRating) / updatedCount;

    await _supabase.from('bidets').update({
      'rating': updatedRating,
      'rating_count': updatedCount,
    }).eq('id', id);
  }
}