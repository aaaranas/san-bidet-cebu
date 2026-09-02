import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/auth_repository.dart';
import '../data/bidet_repository.dart';
import '../services/location_service.dart';

/// Dependency injection without a third-party container.
///
/// Previously every screen did `final _service = SupabaseService()`, creating a
/// fresh client wrapper per screen (and, in one case, inside a button
/// callback). Nothing could be substituted, so nothing could be tested.
/// Widget tests now wrap the subject in an AppScope carrying fakes.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.bidets,
    required this.auth,
    required this.session,
    required this.location,
    required super.child,
  });

  final BidetRepository bidets;
  final AuthRepository auth;
  final SessionController session;
  final LocationService location;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      bidets != oldWidget.bidets ||
      auth != oldWidget.auth ||
      session != oldWidget.session ||
      location != oldWidget.location;
}

extension AppScopeContext on BuildContext {
  BidetRepository get bidets => AppScope.of(this).bidets;
  AuthRepository get auth => AppScope.of(this).auth;
  SessionController get session => AppScope.of(this).session;
  LocationService get location => AppScope.of(this).location;
}

/// Holds the signed-in user for the whole app.
///
/// Also acts as the router's `refreshListenable`, so navigating away from a
/// guarded route on sign-out is automatic rather than a manual pushReplacement
/// at every call site.
class SessionController extends ChangeNotifier {
  SessionController(this._auth) {
    _sub = _auth.watchUser().listen((user) {
      _user = user;
      if (!_ready) _ready = true;
      notifyListeners();
    }, onError: (_) {
      _user = null;
      _ready = true;
      notifyListeners();
    });
  }

  final AuthRepository _auth;
  late final StreamSubscription<AppUser?> _sub;

  AppUser? _user;
  bool _ready = false;

  AppUser? get user => _user;

  /// False until the persisted session has been restored. The router shows a
  /// splash during this window instead of flashing the landing page.
  bool get isReady => _ready;

  bool get isSignedIn => _user != null;

  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
