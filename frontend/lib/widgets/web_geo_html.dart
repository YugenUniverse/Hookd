import 'dart:async';
import 'dart:html' as html;
import 'package:latlong2/latlong.dart';

/// Web implementation using the browser Geolocation API.
Future<LatLng?> webGetCurrentLatLng() async {
  final geo = html.window.navigator.geolocation;
  if (geo == null) return null;

  final completer = Completer<LatLng?>();
  try {
    geo.getCurrentPosition().then((pos) {
      final lat = pos.coords?.latitude;
      final lon = pos.coords?.longitude;
      if (lat != null && lon != null) {
        completer.complete(LatLng(lat.toDouble(), lon.toDouble()));
      } else {
        completer.complete(null);
      }
    }).catchError((e) {
      completer.completeError(e);
    });
  } catch (e) {
    completer.completeError(e);
  }

  return completer.future;
}
