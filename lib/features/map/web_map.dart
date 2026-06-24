// Web-only Mapbox GL JS v3 map (Standard style, 3D buildings + pitch).
//
// This talks to the `window.SanBidetMap` helper defined in web/index.html via
// dart:js_interop. It is compiled only on web (see web_map_interop.dart); the
// mobile build uses web_map_stub.dart instead.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../bidet/bidet_model.dart';

JSObject get _helper => globalContext.getProperty('SanBidetMap'.toJS);

/// Handle the map screen uses to drive the camera (fly-to).
class WebMapController {
  void flyTo(double lat, double lng, double zoom) {
    final h = globalContext.getProperty<JSAny?>('SanBidetMap'.toJS);
    if (h.isUndefinedOrNull) return;
    (h as JSObject).callMethod('flyTo'.toJS, lng.toJS, lat.toJS, zoom.toJS);
  }
}

class WebMapboxMap extends StatefulWidget {
  final WebMapController controller;
  final String token;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final double pitch;
  final List<Bidet> bidets;
  final double? userLat;
  final double? userLng;
  final void Function(String bidetId) onMarkerTap;

  const WebMapboxMap({
    super.key,
    required this.controller,
    required this.token,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.pitch,
    required this.bidets,
    required this.onMarkerTap,
    this.userLat,
    this.userLng,
  });

  @override
  State<WebMapboxMap> createState() => _WebMapboxMapState();
}

class _WebMapboxMapState extends State<WebMapboxMap> {
  static int _counter = 0;
  late final String _viewType;
  late final web.HTMLDivElement _host;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'sanbidet-map-${_counter++}';
    _host = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _host);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initMap());
  }

  void _initMap() {
    final opts = JSObject()
      ..setProperty('token'.toJS, widget.token.toJS)
      ..setProperty('lng'.toJS, widget.centerLng.toJS)
      ..setProperty('lat'.toJS, widget.centerLat.toJS)
      ..setProperty('zoom'.toJS, widget.zoom.toJS)
      ..setProperty('pitch'.toJS, widget.pitch.toJS);

    _helper.callMethod('init'.toJS, _host, opts);
    _helper.setProperty(
      'onMarkerTap'.toJS,
      ((JSString id) => widget.onMarkerTap(id.toDart)).toJS,
    );
    _inited = true;
    _pushMarkers();
    _pushUser();
  }

  void _pushMarkers() {
    if (!_inited) return;
    final arr = <JSObject>[
      for (final b in widget.bidets)
        JSObject()
          ..setProperty('id'.toJS, b.id.toJS)
          ..setProperty('lng'.toJS, b.longitude.toJS)
          ..setProperty('lat'.toJS, b.latitude.toJS),
    ].toJS;
    _helper.callMethod('setMarkers'.toJS, arr);
  }

  void _pushUser() {
    if (!_inited) return;
    _helper.callMethod(
      'setUser'.toJS,
      widget.userLng?.toJS,
      widget.userLat?.toJS,
    );
  }

  @override
  void didUpdateWidget(WebMapboxMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bidets != widget.bidets) _pushMarkers();
    if (oldWidget.userLat != widget.userLat ||
        oldWidget.userLng != widget.userLng) {
      _pushUser();
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
