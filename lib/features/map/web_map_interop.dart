// Picks the real Mapbox GL JS implementation on web, and a no-op stub elsewhere.
export 'web_map_stub.dart' if (dart.library.js_interop) 'web_map.dart';
