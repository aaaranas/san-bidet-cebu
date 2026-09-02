import 'dart:async';
import 'dart:typed_data';

import 'package:san_bidet_cebu/data/auth_repository.dart';
import 'package:san_bidet_cebu/data/bidet_repository.dart';
import 'package:san_bidet_cebu/data/models/bidet.dart';

Bidet makeBidet({
  String id = 'b1',
  String placeName = 'SM City Cebu',
  String floor = '3rd floor',
  BidetType type = BidetType.sprayHose,
  double latitude = 10.3157,
  double longitude = 123.8854,
  double rating = 0,
  int ratingCount = 0,
  BidetStatus status = BidetStatus.approved,
}) {
  return Bidet(
    id: id,
    placeName: placeName,
    floor: floor,
    type: type,
    latitude: latitude,
    longitude: longitude,
    rating: rating,
    ratingCount: ratingCount,
    createdAt: DateTime(2026, 1, 1),
    status: status,
  );
}

class FakeBidetRepository implements BidetRepository {
  FakeBidetRepository({List<Bidet> bidets = const []}) : _bidets = [...bidets];

  final List<Bidet> _bidets;
  final _controller = StreamController<List<Bidet>>.broadcast();

  /// Set to make the next read throw, so error states can be exercised.
  Object? failWith;

  int rateCalls = 0;
  int approveCalls = 0;
  int deleteCalls = 0;
  Bidet? lastAdded;
  String? lastUploadedFileName;

  void emit(List<Bidet> bidets) {
    _bidets
      ..clear()
      ..addAll(bidets);
    _controller.add(List.unmodifiable(_bidets));
  }

  void dispose() => _controller.close();

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Stream<List<Bidet>> watchApproved() async* {
    yield _bidets
        .where((b) => b.status == BidetStatus.approved)
        .toList(growable: false);
    yield* _controller.stream.map(
      (list) => list
          .where((b) => b.status == BidetStatus.approved)
          .toList(growable: false),
    );
  }

  @override
  Future<List<Bidet>> fetchAll() async {
    _maybeFail();
    return List.unmodifiable(_bidets);
  }

  @override
  Future<List<Bidet>> fetchPending() async {
    _maybeFail();
    return _bidets.where((b) => b.status == BidetStatus.pending).toList();
  }

  @override
  Future<Bidet> fetchById(String id) async {
    _maybeFail();
    return _bidets.firstWhere((b) => b.id == id);
  }

  @override
  Future<int> countApproved() async {
    _maybeFail();
    return _bidets.where((b) => b.status == BidetStatus.approved).length;
  }

  @override
  Future<Bidet> add(Bidet bidet, {String? userId}) async {
    _maybeFail();
    lastAdded = bidet;
    final created = bidet.copyWith(id: 'generated-id');
    _bidets.add(created);
    return created;
  }

  @override
  Future<String?> uploadImage(
    Uint8List bytes,
    String bidetId,
    String fileName,
  ) async {
    _maybeFail();
    lastUploadedFileName = fileName;
    return 'https://example.test/$bidetId.jpg';
  }

  @override
  Future<void> setImageUrl(String id, String imageUrl) async {}

  @override
  Future<void> approve(String id) async {
    _maybeFail();
    approveCalls++;
  }

  @override
  Future<void> delete(String id) async {
    _maybeFail();
    deleteCalls++;
  }

  @override
  Future<void> rate(String bidetId, BidetRating rating) async {
    _maybeFail();
    rateCalls++;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : _user = user;

  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  /// Set to make the next sign-in fail.
  AuthFailure? failure;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (failure != null) throw failure!;
    _user = AppUser(id: 'u1', email: email, username: 'tester');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AppUser> signUp(
    String email,
    String password, {
    required String username,
  }) async {
    if (failure != null) throw failure!;
    _user = AppUser(id: 'u1', email: email, username: username);
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (failure != null) throw failure!;
    _user = const AppUser(
      id: 'u-google',
      email: 'tester@gmail.com',
      username: 'tester',
    );
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<AppUser?> refresh() async => _user;

  void dispose() => _controller.close();
}
