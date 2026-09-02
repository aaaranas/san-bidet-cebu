import 'package:flutter/foundation.dart';

enum BidetType {
  sprayHose('spray_hose', 'Spray hose'),
  bidetSeat('bidet_seat', 'Bidet seat'),
  tabo('tabo', 'Tabo');

  const BidetType(this.id, this.label);

  final String id;
  final String label;

  static BidetType fromId(String? id) => BidetType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => BidetType.sprayHose,
      );
}

/// Who can actually walk in. "3rd floor, near the cinemas" does not answer
/// this, and it is usually the deciding factor before walking there.
enum AccessType {
  public('public', 'Open to anyone'),
  customer('customer', 'Customers only'),
  staff('staff', 'Ask staff first');

  const AccessType(this.id, this.label);

  final String id;
  final String label;

  static AccessType fromId(String? id) => AccessType.values.firstWhere(
        (a) => a.id == id,
        orElse: () => AccessType.public,
      );
}

enum BidetStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const BidetStatus(this.id);

  final String id;

  static BidetStatus fromId(String? id) => BidetStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => BidetStatus.pending,
      );
}

/// A single mapped bidet.
///
/// Value equality matters here: the map screen diffs snapshots to decide
/// whether to rebuild, and the old `Stream.distinct()` silently never
/// de-duplicated because the previous model relied on identity.
@immutable
class Bidet {
  final String id;
  final String placeName;
  final String floor;
  final BidetType type;
  final double latitude;
  final double longitude;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final BidetStatus status;
  final String? imageUrl;
  final double cleanlinessRating;
  final double pressureRating;
  final double accessibilityRating;
  final double privacyRating;

  final AccessType accessType;
  final String? hoursNote;
  final String? feeNote;

  /// Set when a moderator rejects the submission, so the contributor learns
  /// why instead of watching the row disappear.
  final String? rejectionReason;

  /// Username of whoever submitted it, embedded from `profiles`.
  final String? submittedByUsername;

  const Bidet({
    required this.id,
    required this.placeName,
    required this.floor,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.rating = 0,
    this.ratingCount = 0,
    required this.createdAt,
    this.status = BidetStatus.pending,
    this.imageUrl,
    this.cleanlinessRating = 0,
    this.pressureRating = 0,
    this.accessibilityRating = 0,
    this.privacyRating = 0,
    this.accessType = AccessType.public,
    this.hoursNote,
    this.feeNote,
    this.rejectionReason,
    this.submittedByUsername,
  });

  String get typeLabel => type.label;

  factory Bidet.fromMap(Map<String, dynamic> data) {
    double toDouble(Object? v) => (v as num?)?.toDouble() ?? 0.0;

    return Bidet(
      id: data['id']?.toString() ?? '',
      placeName: data['place_name'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      type: BidetType.fromId(data['type'] as String?),
      latitude: toDouble(data['latitude']),
      longitude: toDouble(data['longitude']),
      rating: toDouble(data['rating']),
      ratingCount: (data['rating_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
      status: BidetStatus.fromId(data['status'] as String?),
      imageUrl: data['image_url'] as String?,
      cleanlinessRating: toDouble(data['cleanliness_rating']),
      pressureRating: toDouble(data['pressure_rating']),
      accessibilityRating: toDouble(data['accessibility_rating']),
      privacyRating: toDouble(data['privacy_rating']),
      accessType: AccessType.fromId(data['access_type'] as String?),
      hoursNote: data['hours_note'] as String?,
      feeNote: data['fee_note'] as String?,
      rejectionReason: data['rejection_reason'] as String?,
      // PostgREST embeds the related profile as a nested object when the
      // query asks for it; absent on plain selects.
      submittedByUsername: switch (data['profiles']) {
        {'username': final String u} => u,
        _ => null,
      },
    );
  }

  /// Insert payload. Server-managed columns (id, created_at, ratings) are
  /// deliberately omitted so the database owns them.
  Map<String, dynamic> toInsert({String? userId}) => {
        'place_name': placeName,
        'floor': floor,
        'type': type.id,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.id,
        'access_type': accessType.id,
        if (hoursNote != null && hoursNote!.isNotEmpty) 'hours_note': hoursNote,
        if (feeNote != null && feeNote!.isNotEmpty) 'fee_note': feeNote,
        if (imageUrl != null) 'image_url': imageUrl,
        // Column is `submitted_by`, not `user_id` — it predates this refactor.
        if (userId != null) 'submitted_by': userId,
      };

  Bidet copyWith({
    String? id,
    String? placeName,
    String? floor,
    BidetType? type,
    double? latitude,
    double? longitude,
    double? rating,
    int? ratingCount,
    DateTime? createdAt,
    BidetStatus? status,
    String? imageUrl,
    double? cleanlinessRating,
    double? pressureRating,
    double? accessibilityRating,
    double? privacyRating,
    AccessType? accessType,
    String? hoursNote,
    String? feeNote,
    String? rejectionReason,
    String? submittedByUsername,
  }) {
    return Bidet(
      id: id ?? this.id,
      placeName: placeName ?? this.placeName,
      floor: floor ?? this.floor,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      cleanlinessRating: cleanlinessRating ?? this.cleanlinessRating,
      pressureRating: pressureRating ?? this.pressureRating,
      accessibilityRating: accessibilityRating ?? this.accessibilityRating,
      privacyRating: privacyRating ?? this.privacyRating,
      accessType: accessType ?? this.accessType,
      hoursNote: hoursNote ?? this.hoursNote,
      feeNote: feeNote ?? this.feeNote,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedByUsername: submittedByUsername ?? this.submittedByUsername,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bidet &&
          other.id == id &&
          other.placeName == placeName &&
          other.floor == floor &&
          other.type == type &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.rating == rating &&
          other.ratingCount == ratingCount &&
          other.createdAt == createdAt &&
          other.status == status &&
          other.imageUrl == imageUrl &&
          other.cleanlinessRating == cleanlinessRating &&
          other.pressureRating == pressureRating &&
          other.accessibilityRating == accessibilityRating &&
          other.privacyRating == privacyRating &&
          other.accessType == accessType &&
          other.hoursNote == hoursNote &&
          other.feeNote == feeNote &&
          other.rejectionReason == rejectionReason &&
          other.submittedByUsername == submittedByUsername;

  @override
  int get hashCode => Object.hash(
        id,
        placeName,
        floor,
        type,
        latitude,
        longitude,
        rating,
        ratingCount,
        createdAt,
        status,
        imageUrl,
        cleanlinessRating,
        pressureRating,
        accessibilityRating,
        privacyRating,
        accessType,
        hoursNote,
        feeNote,
        rejectionReason,
        submittedByUsername,
      );
}

/// One user's scores for a bidet, before averaging.
@immutable
class BidetRating {
  final double cleanliness;
  final double pressure;
  final double accessibility;
  final double privacy;

  const BidetRating({
    required this.cleanliness,
    required this.pressure,
    required this.accessibility,
    required this.privacy,
  });

  double get overall =>
      (cleanliness + pressure + accessibility + privacy) / 4;

  bool get isComplete =>
      cleanliness > 0 && pressure > 0 && accessibility > 0 && privacy > 0;

  /// Reads a row back out of `bidet_ratings`, so the rating sheet can open
  /// pre-filled with what this user said last time instead of blank.
  factory BidetRating.fromMap(Map<String, dynamic> data) {
    double v(String k) => (data[k] as num?)?.toDouble() ?? 0;
    return BidetRating(
      cleanliness: v('cleanliness'),
      pressure: v('pressure'),
      accessibility: v('accessibility'),
      privacy: v('privacy'),
    );
  }
}

/// A problem someone reported with a listing. The app catalogues physical
/// things that close and break, so this is how the data stays true.
enum ReportKind {
  gone('gone', 'It is gone', 'The bidet or the whole restroom no longer exists'),
  broken('broken', 'It is broken', 'There, but not usable right now'),
  inaccurate(
    'inaccurate',
    'Details are wrong',
    'Wrong floor, wrong type, wrong place name',
  ),
  duplicate('duplicate', 'Already listed', 'The same bidet appears twice'),
  other('other', 'Something else', 'Tell us what is off');

  const ReportKind(this.id, this.label, this.hint);

  final String id;
  final String label;
  final String hint;

  static ReportKind fromId(String? id) => ReportKind.values.firstWhere(
        (r) => r.id == id,
        orElse: () => ReportKind.other,
      );
}

/// A candidate duplicate found near a proposed location.
@immutable
class NearbyBidet {
  final String id;
  final String placeName;
  final String floor;
  final double distanceMeters;

  const NearbyBidet({
    required this.id,
    required this.placeName,
    required this.floor,
    required this.distanceMeters,
  });

  factory NearbyBidet.fromMap(Map<String, dynamic> data) => NearbyBidet(
        id: data['id']?.toString() ?? '',
        placeName: data['place_name'] as String? ?? '',
        floor: data['floor'] as String? ?? '',
        distanceMeters: (data['distance_m'] as num?)?.toDouble() ?? 0,
      );
}
