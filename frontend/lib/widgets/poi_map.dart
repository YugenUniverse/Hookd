import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        // Permissions are denied, we won't be able to get the location
        setState(() {
          _locating = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _userLocation = LatLng(pos.latitude, pos.longitude);
      // center map on user location if controller is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(_userLocation!, _defaultZoom);
        } catch (_) {}
      });
    } catch (e) {
      // ignore and continue with default center
    } finally {
      setState(() {
        _locating = false;
      });
    }
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
    final center = _userLocation ?? const LatLng(51.5, -0.09);
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
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'recenter-map',
            tooltip: 'Center on my position',
            onPressed: _userLocation == null
                ? null
                : () {
                    _mapController.move(_userLocation!, _defaultZoom);
                  },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
