import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Conditional web geolocation helper. Uses browser API on web, stub elsewhere.
import 'web_geo_stub.dart'
  if (dart.library.html) 'web_geo_html.dart' as web_geo;

class POIMap extends StatefulWidget {
  const POIMap({super.key});

  @override
  State<POIMap> createState() => _POIMapState();
}

class _POIMapState extends State<POIMap> {
  final MapController _mapController = MapController();
  bool _locating = true;
  LatLng? _userLocation;
  static const double _defaultZoom = 11;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    // Retry up to 3 times to handle intermittent geolocation failures
    const maxRetries = 3;

    if (kIsWeb) {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          print('Requesting web geolocation... (attempt $attempt/$maxRetries)');
          final latlng = await web_geo.webGetCurrentLatLng();
          if (latlng != null) {
            _userLocation = latlng;
            setState(() {
              _locating = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                print('Moving map to user location (web)');
                _mapController.move(_userLocation!, _defaultZoom);
              } catch (e) {
                print('Error moving map: $e');
              }
            });
            return;
          } else {
            throw Exception('Web geolocation returned null');
          }
        } catch (e) {
          print('Web geolocation attempt $attempt/$maxRetries failed: $e');
          if (attempt == maxRetries) {
            print('Web geolocation failed after $maxRetries attempts. Using default center.');
            setState(() {
              _locating = false;
            });
          } else {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Requesting geolocation... (attempt $attempt/$maxRetries)');
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        print('Got location: ${pos.latitude}, ${pos.longitude}');
        _userLocation = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _locating = false;
        });
        // center map on user location if controller is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            print('Moving map to user location');
            _mapController.move(_userLocation!, _defaultZoom);
          } catch (e) {
            print('Error moving map: $e');
          }
        });
        return; // Success, exit retry loop
      } catch (e) {
        print('Geolocation attempt $attempt/$maxRetries failed: $e');
        if (attempt == maxRetries) {
          // All retries exhausted
          print('Geolocation failed after $maxRetries attempts. Using default center.');
          setState(() {
            _locating = false;
          });
        } else {
          // Wait before retrying
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
  }

  void retryLocation() {
    setState(() {
      _locating = true;
    });
    _initLocation();
  }

  Marker? _buildUserMarker() {
    final u = _userLocation;
    if (u == null) return null;

    return Marker(
      width: 26,
      height: 26,
      point: u,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default center: 46°04′N 11°07′E / 46.067°N 11.117°E
    final center = _userLocation ?? const LatLng(46.067, 11.117);
    final maptilerKey = dotenv.env['MAPTILER_KEY'];
    final maptilerStyle = (dotenv.env['MAPTILER_STYLE'] ?? 'basic-v2').trim();
    final useMapTiler = maptilerKey != null && maptilerKey.isNotEmpty;
    final tileUrl = useMapTiler
        ? 'https://api.maptiler.com/maps/$maptilerStyle/{z}/{x}/{y}.png?key=$maptilerKey'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // flutter_map 8.x uses initialCenter/initialZoom
            initialCenter: center,
            initialZoom: _defaultZoom,
          ),
          children: [
            TileLayer(
              // Prefer MapTiler if `MAPTILER_KEY` is set in frontend/.env.
              // Default style is a simpler `basic-v2` (override with MAPTILER_STYLE).
              urlTemplate: tileUrl,
              subdomains: const [],
              tileProvider: NetworkTileProvider(),
            ),
            if (_buildUserMarker() != null)
              MarkerLayer(markers: [_buildUserMarker()!]),
          ],
        ),

        if (_locating)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Locating...'),
                ],
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: 100, // positioned above the nav bar (which is 70px + 16px padding)
          child: FloatingActionButton.small(
            heroTag: 'recenter-map',
            tooltip: 'Center on my position / Retry location',
            onPressed: () {
              retryLocation();
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
