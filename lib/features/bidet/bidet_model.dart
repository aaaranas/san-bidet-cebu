import 'package:cloud_firestore/cloud_firestore.dart';

class Bidet {
  final String id;
  final String placeName;
  final String floor;
  final String type;
  final GeoPoint location;
  final double rating;
  final int ratingCount;
  final DateTime createdAt;

  Bidet({
    required this.id,
    required this.placeName,
    required this.floor,
    required this.type,
    required this.location,
    required this.rating,
    required this.ratingCount,
    required this.createdAt,
  });

  factory Bidet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bidet(
      id: doc.id,
      placeName: data['placeName'] ?? '',
      floor: data['floor'] ?? '',
      type: data['type'] ?? 'spray_hose',
      location: data['location'] as GeoPoint,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'placeName': placeName,
        'floor': floor,
        'type': type,
        'location': location,
        'rating': rating,
        'ratingCount': ratingCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  // Display helper
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

  String get distanceLabel => ''; // filled in by location service later
}