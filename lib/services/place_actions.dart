import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../data/models/bidet.dart';

/// Handing a bidet off to the rest of the phone: directions, and sharing.
///
/// Both were missing. Finding a bidet on a map is not the same as getting to
/// it, and a community directory with no way to send someone a listing has no
/// way to spread.
class PlaceActions {
  const PlaceActions();

  /// Public URL for a listing. The route already exists and is registered as
  /// an Android App Link, so on a device with the app installed this opens the
  /// app rather than the browser.
  String shareUrl(Bidet bidet) => '${AppConfig.webOrigin}/bidet/${bidet.id}';

  /// Opens the platform's map app with directions to the bidet.
  ///
  /// Uses the cross-platform Google Maps URL rather than a `geo:` URI: `geo:`
  /// is Android-only, and this form also works on iOS and in a desktop
  /// browser, falling back to the web map when no app is installed.
  Future<bool> openDirections(Bidet bidet) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${bidet.latitude},${bidet.longitude}',
      'destination_place_id': '',
    }..removeWhere((_, v) => v.isEmpty));

    return launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  /// Opens the share sheet with a link to the listing.
  Future<void> share(Bidet bidet) async {
    final where = bidet.floor.trim().isEmpty
        ? bidet.placeName
        : '${bidet.placeName} — ${bidet.floor}';

    await Share.share(
      '$where\n${shareUrl(bidet)}',
      subject: '${bidet.placeName} on SanBidet Cebu',
    );
  }
}
