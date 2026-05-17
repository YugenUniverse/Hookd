import 'package:latlong2/latlong.dart';

/// Stub for non-web platforms. Returns null so callers can fallback.
Future<LatLng?> webGetCurrentLatLng() async => null;
