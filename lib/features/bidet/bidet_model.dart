class Bidet {
  final String id;
  final String placeName;
  final String floor;
  final String type;
  final double latitude;
  final double longitude;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;
  final String status;
  final String? imageUrl;
  final double cleanlinessRating;
  final double pressureRating;
  final double accessibilityRating;
  final double privacyRating;

  Bidet({
    required this.id,
    required this.placeName,
    required this.floor,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.ratingCount,
    required this.createdAt,
    this.status = 'pending',
    this.imageUrl,
    this.cleanlinessRating = 0.0,
    this.pressureRating = 0.0,
    this.accessibilityRating = 0.0,
    this.privacyRating = 0.0,
  });

  factory Bidet.fromMap(Map<String, dynamic> data) {
    return Bidet(
      id: data['id'] ?? '',
      placeName: data['place_name'] ?? '',
      floor: data['floor'] ?? '',
      type: data['type'] ?? 'spray_hose',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['rating_count'] ?? 0,
      createdAt: DateTime.parse(
          data['created_at'] ?? DateTime.now().toIso8601String()),
      status: data['status'] ?? 'pending',
      imageUrl: data['image_url'] as String?,
      cleanlinessRating: (data['cleanliness_rating'] ?? 0.0).toDouble(),
      pressureRating: (data['pressure_rating'] ?? 0.0).toDouble(),
      accessibilityRating: (data['accessibility_rating'] ?? 0.0).toDouble(),
      privacyRating: (data['privacy_rating'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'place_name': placeName,
        'floor': floor,
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'rating': rating,
        'rating_count': ratingCount,
        'status': status,
        if (imageUrl != null) 'image_url': imageUrl,
      };

  String get typeLabel {
    switch (type) {
      case 'bidet_seat':
        return 'Bidet seat';
      case 'tabo':
        return 'Tabo';
      default:
        return 'Spray hose';
    }
  }
}
