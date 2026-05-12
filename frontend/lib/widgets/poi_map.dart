import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/wall.dart';
import '../services/api_service.dart';
import '../dialogs/wall_details_dialog.dart';
// Conditional web geolocation helper. Uses browser API on web, stub elsewhere.
import 'web_geo_stub.dart'
  if (dart.library.html) 'web_geo_html.dart' as web_geo;

class WallMapController extends ChangeNotifier {
  LatLng? _target;
  Wall? _selectedWall;

  LatLng? get target => _target;
  Wall? get selectedWall => _selectedWall;

  void focusOnWall(Wall wall) {
    _selectedWall = wall;
    _target = LatLng(wall.latitude, wall.longitude);
    notifyListeners();
  }
}

class POIMap extends StatefulWidget {
  const POIMap({super.key, this.controller});

  final WallMapController? controller;

  @override
  State<POIMap> createState() => _POIMapState();
}

class _POIMapState extends State<POIMap> {
  final MapController _mapController = MapController();
  bool _locating = true;
  LatLng? _userLocation;
  List<Wall> _walls = [];
  static const double _defaultZoom = 11;
  static const double _wallLoadRadius = 30000; // Load walls within 30km
  double _currentZoom = _defaultZoom;
  LatLng? _lastMapCenter;
  static const double _mapMoveThreshold = 2000; // Reload walls if map center moves >2km
  static const double _focusZoom = 16.0;
  bool _skipNextMoveFetch = false;

  void _handleControllerCommand() {
    final controller = widget.controller;
    final target = controller?.target;
    final wall = controller?.selectedWall;
    if (controller == null || target == null) return;

    _skipNextMoveFetch = true;
    _currentZoom = _focusZoom;
    _lastMapCenter = target;
    _mapController.move(target, _currentZoom);
    _fetchWallsForLocation(target.longitude, target.latitude, zoom: _currentZoom);
    
    // Show wall info if a wall was selected
    if (wall != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWallInfo(wall);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _setupMapListener();
    widget.controller?.addListener(_handleControllerCommand);
  }

  @override
  void didUpdateWidget(covariant POIMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerCommand);
      widget.controller?.addListener(_handleControllerCommand);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerCommand);
    super.dispose();
  }

  void _setupMapListener() {
    // Listen to map position changes
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        _onMapMoved();
      }
    });
  }

  void _onMapMoved() {
    if (_skipNextMoveFetch) {
      _skipNextMoveFetch = false;
      return;
    }
    final currentCenter = _mapController.camera.center;
    _currentZoom = _mapController.camera.zoom;
    print('Map moved to: ${currentCenter.latitude}, ${currentCenter.longitude}');
    print('Map zoom: $_currentZoom');
    
    // Check if we've moved far enough to reload walls
    if (_lastMapCenter == null || _shouldReloadWalls(currentCenter)) {
      print('Reloading walls for new map center');
      _lastMapCenter = currentCenter;
      _fetchWallsForLocation(
        currentCenter.longitude,
        currentCenter.latitude,
        zoom: _currentZoom,
      );
    }
  }

  bool _shouldReloadWalls(LatLng newCenter) {
    if (_lastMapCenter == null) return true;
    
    // Use latlong2 Distance calculator
    final distance = const Distance().as(LengthUnit.Meter, _lastMapCenter!, newCenter);
    print('Distance from last load: ${distance.toStringAsFixed(0)}m');
    return distance > _mapMoveThreshold;
  }

  double _radiusForZoom(double zoom) {
    // More zoomed out -> larger radius, zoomed in -> smaller radius.
    return (_wallLoadRadius * (12 / zoom)).clamp(1500.0, 80000.0);
  }

  Future<void> _fetchWallsForLocation(double lng, double lat, {double? zoom}) async {
    try {
      final effectiveZoom = zoom ?? _currentZoom;
      final radius = _radiusForZoom(effectiveZoom);
      print('Fetching nearby walls for location $lng, $lat at zoom $effectiveZoom => radius ${radius.toStringAsFixed(0)}m');
      final walls = await ApiService().getNearbyWalls(lng, lat, radius: radius);
      print('Got ${walls.length} walls for location $lng, $lat');
      setState(() {
        _walls = walls;
      });
    } catch (e) {
      print('Error fetching walls for location: $e');
    }
  }

  Future<void> _fetchWalls() async {
    print('_fetchWalls called, userLocation: $_userLocation');
    if (_userLocation == null) {
      try {
        print('Fetching all walls (no user location)');
        final walls = await ApiService().getAllWalls();
        print('Got ${walls.length} walls from getAllWalls');
        setState(() {
          _walls = walls;
        });
      } catch (e) {
        print('Error fetching all walls: $e');
      }
    } else {
      try {
        final radius = _radiusForZoom(_currentZoom);
        print('Fetching nearby walls at zoom $_currentZoom => radius ${radius.toStringAsFixed(0)}m');
        final walls = await ApiService().getNearbyWalls(
          _userLocation!.longitude,
          _userLocation!.latitude,
          radius: radius,
        );
        print('Got ${walls.length} walls from getNearbyWalls');
        setState(() {
          _walls = walls;
        });
      } catch (e) {
        print('Error fetching nearby walls: $e');
      }
    }
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
            _fetchWallsForLocation(latlng.longitude, latlng.latitude, zoom: _currentZoom);
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
            _fetchWalls();
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
        _fetchWallsForLocation(pos.longitude, pos.latitude, zoom: _currentZoom);
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
          _fetchWalls();
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

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toUpperCase()) {
      case 'BEGINNER':
        return Colors.green;
      case 'INTERMEDIATE':
        return Colors.amber;
      case 'ADVANCED':
        return Colors.orange;
      case 'EXPERT':
        return Colors.red.shade700;
      case 'UNKNOWN':
      default:
        return Colors.grey;
    }
  }

  List<Marker> _buildWallMarkers() {
    print('_buildWallMarkers called with ${_walls.length} walls');
    return _walls.map((wall) {
      print('Building marker for wall: ${wall.name} at (${wall.latitude}, ${wall.longitude})');
      final markerColor = _getDifficultyColor(wall.difficulty);
      return Marker(
        width: 32,
        height: 32,
        point: LatLng(wall.latitude, wall.longitude),
        child: GestureDetector(
          onTap: () {
            _showWallInfo(wall);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerColor,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showWallInfo(Wall wall) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => WallDetailsDialog(wall: wall),
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
            onPositionChanged: (position, hasGesture) {
              _currentZoom = position.zoom;
            },
          ),
          children: [
            TileLayer(
              // Prefer MapTiler if `MAPTILER_KEY` is set in frontend/.env.
              // Default style is a simpler `basic-v2` (override with MAPTILER_STYLE).
              urlTemplate: tileUrl,
              subdomains: const [],
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                if (_buildUserMarker() != null) _buildUserMarker()!,
                ..._buildWallMarkers(),
              ],
            ),
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
