import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/app_scope.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/auth_repository.dart';
import 'data/bidet_repository.dart';
import 'services/location_service.dart';

/// Root widget. Owns the long-lived singletons and wires them into the tree
/// through [AppScope], so no screen constructs its own service.
///
/// Uses `ShadApp.router` rather than `ShadApp`: the shadcn theme is kept, but
/// navigation moves to go_router so the web build gets real URLs and Android
/// can receive App Links.
class SanBidetApp extends StatefulWidget {
  const SanBidetApp({
    super.key,
    required this.bidets,
    required this.auth,
    this.location = const LocationService(),
  });

  final BidetRepository bidets;
  final AuthRepository auth;
  final LocationService location;

  @override
  State<SanBidetApp> createState() => _SanBidetAppState();
}

class _SanBidetAppState extends State<SanBidetApp> {
  late final SessionController _session;
  late final GoRouterConfigHolder _router;

  @override
  void initState() {
    super.initState();
    _session = SessionController(widget.auth);
    _router = GoRouterConfigHolder(buildRouter(_session));
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      bidets: widget.bidets,
      auth: widget.auth,
      session: _session,
      location: widget.location,
      child: ShadApp.router(
        title: 'SanBidet Cebu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: _router.router,
        // Keeps Material widgets (AppBar, SnackBar, dialogs) on the same slate
        // palette as the shadcn ones.
        materialThemeBuilder: AppTheme.materialFrom,
      ),
    );
  }
}

/// Thin holder so the router is built exactly once, in initState.
class GoRouterConfigHolder {
  const GoRouterConfigHolder(this.router);
  final RouterConfig<Object> router;
}
