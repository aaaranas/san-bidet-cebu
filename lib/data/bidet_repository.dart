import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import 'models/bidet.dart';

/// Everything the app can do with bidet records.
///
/// Screens depend on this interface rather than on Supabase directly, which is
/// what makes them testable (see `test/`) and what would make a future backend
/// swap a single-class change.
abstract interface class BidetRepository {
  /// Live stream of approved bidets.
  Stream<List<Bidet>> watchApproved();

  Future<List<Bidet>> fetchAll();

  Future<List<Bidet>> fetchPending();

  Future<Bidet> fetchById(String id);

  Future<int> countApproved();

  /// Returns the created row so the caller has the server-assigned id.
  Future<Bidet> add(Bidet bidet, {String? userId});

  Future<String?> uploadImage(Uint8List bytes, String bidetId, String fileName);

  Future<void> setImageUrl(String id, String imageUrl);

  Future<void> approve(String id);

  Future<void> delete(String id);

  /// Records one user's rating. Averaging happens in the database so
  /// concurrent raters cannot clobber each other.
  Future<void> rate(String bidetId, BidetRating rating);
}

class SupabaseBidetRepository implements BidetRepository {
  SupabaseBidetRepository(this._db);

  final SupabaseClient _db;

  static const _table = 'bidets';

  @override
  Stream<List<Bidet>> watchApproved() {
    // Realtime replaces the old 5-second Stream.periodic poll: the server
    // pushes changes, so there is no fixed-interval traffic and no rebuild
    // storm. Filtering by status happens client-side because Supabase's
    // realtime stream builder does not support .eq() alongside .order().
    return _db
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows
            .map(Bidet.fromMap)
            .where((b) => b.status == BidetStatus.approved)
            .toList(growable: false));
  }

  @override
  Future<List<Bidet>> fetchAll() async {
    final data = await _db.from(_table).select().order('created_at');
    return data.map(Bidet.fromMap).toList();
  }

  @override
  Future<List<Bidet>> fetchPending() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('status', BidetStatus.pending.id)
        .order('created_at');
    return data.map(Bidet.fromMap).toList();
  }

  @override
  Future<Bidet> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).single();
    return Bidet.fromMap(data);
  }

  @override
  Future<int> countApproved() async {
    final rows = await _db
        .from(_table)
        .select('id')
        .eq('status', BidetStatus.approved.id)
        .count(CountOption.exact);
    return rows.count;
  }

  @override
  Future<Bidet> add(Bidet bidet, {String? userId}) async {
    final data = await _db
        .from(_table)
        .insert(bidet.toInsert(userId: userId))
        .select()
        .single();
    return Bidet.fromMap(data);
  }

  @override
  Future<String?> uploadImage(
    Uint8List bytes,
    String bidetId,
    String fileName,
  ) async {
    // Derive the extension from the picker-supplied *file name*, never from
    // XFile.path: on web that path is a blob: URL whose host contains dots, so
    // splitting it yielded a bogus extension and a corrupt content type.
    final dot = fileName.lastIndexOf('.');
    final ext = dot > 0 && dot < fileName.length - 1
        ? fileName.substring(dot + 1).toLowerCase()
        : 'jpg';
    final safeExt = _allowedExtensions.contains(ext) ? ext : 'jpg';
    final contentType = safeExt == 'jpg' ? 'jpeg' : safeExt;

    final storageName =
        '${bidetId}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';

    final storage = _db.storage.from(AppConfig.storageBucket);
    await storage.uploadBinary(
      storageName,
      bytes,
      fileOptions: FileOptions(contentType: 'image/$contentType'),
    );
    return storage.getPublicUrl(storageName);
  }

  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

  @override
  Future<void> setImageUrl(String id, String imageUrl) =>
      _db.from(_table).update({'image_url': imageUrl}).eq('id', id);

  @override
  Future<void> approve(String id) => _db
      .from(_table)
      .update({'status': BidetStatus.approved.id}).eq('id', id);

  @override
  Future<void> delete(String id) => _db.from(_table).delete().eq('id', id);

  @override
  Future<void> rate(String bidetId, BidetRating rating) async {
    // submit_bidet_rating() upserts into `bidet_ratings` and recomputes the
    // averages atomically inside one transaction. See
    // supabase/migrations/0001_ratings_and_policies.sql.
    await _db.rpc('submit_bidet_rating', params: {
      'p_bidet_id': bidetId,
      'p_cleanliness': rating.cleanliness,
      'p_pressure': rating.pressure,
      'p_accessibility': rating.accessibility,
      'p_privacy': rating.privacy,
    });
  }
}
