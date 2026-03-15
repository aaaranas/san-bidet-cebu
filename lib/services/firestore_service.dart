import '../features/bidet/bidet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  // Dummy local data so the app runs without Firebase
  final List<Bidet> _mockBidets = [
    Bidet(
      id: '1',
      placeName: 'SM City Cebu — 3F',
      floor: '3rd floor, near cinemas',
      type: 'spray_hose',
      location: const GeoPoint(10.3110, 123.9180),
      rating: 4.8,
      ratingCount: 32,
      createdAt: DateTime.now(),
    ),
    Bidet(
      id: '2',
      placeName: 'Ayala Center Cebu — LG',
      floor: 'Lower ground, near food court',
      type: 'bidet_seat',
      location: const GeoPoint(10.3185, 123.9054),
      rating: 4.2,
      ratingCount: 18,
      createdAt: DateTime.now(),
    ),
    Bidet(
      id: '3',
      placeName: 'Waterfront Hotel',
      floor: 'Lobby level restroom',
      type: 'bidet_seat',
      location: const GeoPoint(10.2934, 123.9020),
      rating: 4.5,
      ratingCount: 11,
      createdAt: DateTime.now(),
    ),
  ];

  Stream<List<Bidet>> getBidets() {
    return Stream.value(_mockBidets);
  }

  Future<void> addBidet(Bidet bidet) async {
    // No-op until Firebase is connected
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> rateBidet(String bidetId, double newRating) async {
    // No-op until Firebase is connected
    await Future.delayed(const Duration(milliseconds: 300));
  }
}