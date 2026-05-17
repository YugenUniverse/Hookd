import 'dart:async';
import 'dart:html' as html;
import 'package:latlong2/latlong.dart';

/// Web implementation using the browser Geolocation API.
Future<LatLng?> webGetCurrentLatLng() async {
  final geo = html.window.navigator.geolocation;

  try {
    final pos = await geo.getCurrentPosition().timeout(
      const Duration(seconds: 10),
    );
    final lat = pos.coords?.latitude;
    final lon = pos.coords?.longitude;
    if (lat != null && lon != null) {
      return LatLng(lat.toDouble(), lon.toDouble());
    }
    return null;
  } catch (e) {
    return null;
  }
}
