import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import 'models/bidet.dart';

/// Everything the app can do with bidet records.
///
/// Screens depend on this interface rather than on Supabase directly, which is
/// what makes them testable (see `test/`) and what would make a future backend
/// swap a single-class change.
/// Raised for write failures the UI should show verbatim. Row-level security
/// rejections in particular are worth naming: they look like a network error
/// but are really "you are not allowed to do that", and the generic message
/// sent people looking in the wrong place.
class BidetFailure implements Exception {
  final String message;
  const BidetFailure(this.message);

  @override
  String toString() => message;
}

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

  /// Bidets this user submitted, any status — so a contributor can see that
  /// something is still pending, or why it was turned down.
  Future<List<Bidet>> fetchMine(String userId);

  /// Every approved bidet, for the moderator's browse view.
  Future<List<Bidet>> fetchApproved();

  Future<void> approve(String id);

  /// Rejects with a reason instead of deleting, so the contributor gets an
  /// explanation and cannot silently resubmit the same place.
  Future<void> reject(String id, String reason);

  Future<void> delete(String id);

  /// This user's own rating for a bidet, if they have rated it.
  Future<BidetRating?> fetchMyRating(String bidetId);

  /// Ids of bidets this user has already rated, for marking the list and map.
  Future<Set<String>> fetchRatedIds();

  /// Existing bidets within [radiusMeters] of a point, nearest first — used to
  /// catch duplicates before they are created.
  Future<List<NearbyBidet>> findNearby(
    double latitude,
    double longitude, {
    double radiusMeters,
  });

  /// Flags a listing as gone, broken or wrong.
  Future<void> report(String bidetId, ReportKind kind, String? note);

  /// Open report counts keyed by bidet id, for the moderation queue.
  Future<Map<String, int>> fetchOpenReportCounts();

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

  /// Embeds the contributor's username through the profiles foreign key added
  /// in migration 0003.
  static const _withProfile = '*, profiles!bidets_submitted_by_profile_fkey(username)';

  @override
  Future<Bidet> fetchById(String id) async {
    final data = await _db.from(_table).select(_withProfile).eq('id', id).single();
    return Bidet.fromMap(data);
  }

  @override
  Future<List<Bidet>> fetchMine(String userId) async {
    final data = await _db
        .from(_table)
        .select(_withProfile)
        .eq('submitted_by', userId)
        .order('created_at', ascending: false);
    return data.map(Bidet.fromMap).toList();
  }

  @override
  Future<List<Bidet>> fetchApproved() async {
    final data = await _db
        .from(_table)
        .select(_withProfile)
        .eq('status', BidetStatus.approved.id)
        .order('created_at', ascending: false);
    return data.map(Bidet.fromMap).toList();
  }

  @override
  Future<BidetRating?> fetchMyRating(String bidetId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _db
        .from('bidet_ratings')
        .select('cleanliness, pressure, accessibility, privacy')
        .eq('bidet_id', bidetId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : BidetRating.fromMap(row);
  }

  @override
  Future<Set<String>> fetchRatedIds() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return <String>{};
    final rows = await _db
        .from('bidet_ratings')
        .select('bidet_id')
        .eq('user_id', userId);
    return rows.map((r) => r['bidet_id'].toString()).toSet();
  }

  @override
  Future<List<NearbyBidet>> findNearby(
    double latitude,
    double longitude, {
    double radiusMeters = 120,
  }) async {
    final rows = await _db.rpc('bidets_near', params: {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_radius_m': radiusMeters,
    });
    return (rows as List)
        .map((r) => NearbyBidet.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> report(String bidetId, ReportKind kind, String? note) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw const BidetFailure('Sign in to report a problem.');
    }
    try {
      await _db.from('bidet_reports').insert({
        'bidet_id': bidetId,
        'user_id': userId,
        'kind': kind.id,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
    } on PostgrestException catch (e) {
      throw BidetFailure(_friendly(e));
    }
  }

  @override
  Future<Map<String, int>> fetchOpenReportCounts() async {
    final rows = await _db.rpc('open_report_counts');
    return {
      for (final r in (rows as List))
        (r as Map<String, dynamic>)['bidet_id'].toString():
            (r['open_reports'] as num).toInt(),
    };
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
    // Without an id the row cannot satisfy the insert policy
    // (`submitted_by = auth.uid()`), and Postgres reports that as a generic
    // RLS violation. Fail here instead, where the cause is obvious.
    if (userId == null || userId.isEmpty) {
      throw const BidetFailure(
        'You need to be signed in to add a bidet. Sign in and try again.',
      );
    }

    try {
      final data = await _db
          .from(_table)
          .insert(bidet.toInsert(userId: userId))
          .select()
          .single();
      return Bidet.fromMap(data);
    } on PostgrestException catch (e) {
      throw BidetFailure(_friendly(e));
    }
  }

  /// Turns Postgres error codes into something a person can act on.
  String _friendly(PostgrestException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();

    // 42501 = insufficient privilege, which is what a row-level-security
    // rejection surfaces as.
    if (code == '42501' || msg.contains('row-level security')) {
      return 'The database rejected this submission. Your session may have '
          'expired — sign out and back in, then try again.';
    }
    if (code == '23505') {
      return 'That bidet already exists.';
    }
    if (code == '23502') {
      return 'Something required was missing from the submission.';
    }
    if (code == '23503') {
      return 'Your account is not fully set up yet. Sign out and back in.';
    }
    return 'Could not save this bidet: ${e.message}';
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
  Future<void> approve(String id) async {
    // The RPC stamps reviewed_by/reviewed_at, which a plain update cannot.
    try {
      await _db.rpc('approve_bidet', params: {'p_bidet_id': id});
    } on PostgrestException catch (e) {
      throw BidetFailure(_friendly(e));
    }
  }

  @override
  Future<void> reject(String id, String reason) async {
    try {
      await _db.rpc('reject_bidet', params: {
        'p_bidet_id': id,
        'p_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw BidetFailure(_friendly(e));
    }
  }

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
