import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/poi.dart';
import '../models/wall.dart';
import '../services/api_service.dart';
import '../dialogs/wall_details_dialog.dart';
import '../dialogs/facility_details_dialog.dart';
// Conditional web geolocation helper. Uses browser API on web, stub elsewhere.
import 'web_geo_stub.dart'
    if (dart.library.html) 'web_geo_html.dart'
    as web_geo;

class WallMapController extends ChangeNotifier {
  LatLng? _target;
  Wall? _selectedWall;
  FacilityPoi? _selectedFacility;

  LatLng? get target => _target;
  Wall? get selectedWall => _selectedWall;
  FacilityPoi? get selectedFacility => _selectedFacility;

  void focusOnWall(Wall wall) {
    _selectedWall = wall;
    _selectedFacility = null;
    _target = LatLng(wall.latitude, wall.longitude);
    notifyListeners();
  }

  void focusOnFacility(FacilityPoi facility) {
    _selectedFacility = facility;
    _selectedWall = null;
    _target = LatLng(facility.latitude, facility.longitude);
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
  List<Poi> _pois = [];
  static const double _defaultZoom = 11;
  static const double _poiLoadRadius = 30000;
  double _currentZoom = _defaultZoom;
  LatLng? _lastMapCenter;
  static const double _mapMoveThreshold = 2000;
  static const double _focusZoom = 16.0;
  bool _skipNextMoveFetch = false;

  void _handleControllerCommand() {
    final controller = widget.controller;
    final target = controller?.target;
    if (controller == null || target == null) return;

    _skipNextMoveFetch = true;
    _currentZoom = _focusZoom;
    _lastMapCenter = target;
    _mapController.move(target, _currentZoom);
    _fetchPoisForLocation(
      target.longitude,
      target.latitude,
      zoom: _currentZoom,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wall = controller.selectedWall;
      final facility = controller.selectedFacility;
      if (wall != null) {
        _showWallDetails(wall);
      } else if (facility != null) {
        _showPoiInfo(facility);
      }
    });
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

    if (_lastMapCenter == null || _shouldReload(currentCenter)) {
      _lastMapCenter = currentCenter;
      _fetchPoisForLocation(
        currentCenter.longitude,
        currentCenter.latitude,
        zoom: _currentZoom,
      );
    }
  }

  bool _shouldReload(LatLng newCenter) {
    if (_lastMapCenter == null) return true;
    final distance = const Distance().as(
      LengthUnit.Meter,
      _lastMapCenter!,
      newCenter,
    );
    return distance > _mapMoveThreshold;
  }

  double _radiusForZoom(double zoom) {
    return (_poiLoadRadius * (12 / zoom)).clamp(1500.0, 80000.0);
  }

  Future<void> _fetchPoisForLocation(
    double lng,
    double lat, {
    double? zoom,
  }) async {
    try {
      final effectiveZoom = zoom ?? _currentZoom;
      final radius = _radiusForZoom(effectiveZoom);
      final pois = await ApiService().getNearbyPois(lng, lat, radius: radius);
      if (mounted) {
        setState(() {
          _pois = pois;
        });
      }
    } catch (e) {
      print('Error fetching POIs for location: $e');
    }
  }

  Future<void> _fetchPois() async {
    if (_userLocation == null) {
      try {
        final pois = await ApiService().getAllPois();
        if (mounted) {
          setState(() {
            _pois = pois;
          });
        }
      } catch (e) {
        print('Error fetching all POIs: $e');
      }
    } else {
      _fetchPoisForLocation(
        _userLocation!.longitude,
        _userLocation!.latitude,
        zoom: _currentZoom,
      );
    }
  }

  Future<void> _initLocation() async {
    const maxRetries = 3;

    if (kIsWeb) {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          final latlng = await web_geo.webGetCurrentLatLng();
          if (latlng != null) {
            _userLocation = latlng;
            setState(() {
              _locating = false;
            });
            _fetchPoisForLocation(
              latlng.longitude,
              latlng.latitude,
              zoom: _currentZoom,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
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
            setState(() {
              _locating = false;
            });
            _fetchPois();
          } else {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        _userLocation = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _locating = false;
        });
        _fetchPoisForLocation(pos.longitude, pos.latitude, zoom: _currentZoom);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(_userLocation!, _defaultZoom);
          } catch (e) {
            print('Error moving map: $e');
          }
        });
        return;
      } catch (e) {
        print('Geolocation attempt $attempt/$maxRetries failed: $e');
        if (attempt == maxRetries) {
          setState(() {
            _locating = false;
          });
          _fetchPois();
        } else {
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

  List<Marker> _buildPoiMarkers() {
    return _pois.map((poi) {
      final point = LatLng(poi.latitude, poi.longitude);

      if (poi is FacilityPoi) {
        return Marker(
          width: 36,
          height: 36,
          point: point,
          child: GestureDetector(
            onTap: () => _showPoiInfo(poi),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueGrey,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.domain, color: Colors.white, size: 18),
            ),
          ),
        );
      }

      // OutdoorWallPoi
      final wall = poi as OutdoorWallPoi;
      final markerColor = _getDifficultyColor(wall.difficulty);
      return Marker(
        width: 32,
        height: 32,
        point: point,
        child: GestureDetector(
          onTap: () => _showPoiInfo(poi),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: markerColor,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.landscape, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();
  }

  void _showPoiInfo(Poi poi) {
    if (poi is FacilityPoi) {
      showModalBottomSheet(
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        context: context,
        builder: (context) =>
            FacilityDetailsDialog(facility: poi, onChanged: _fetchPois),
      );
    } else if (poi is OutdoorWallPoi) {
      _showWallDetails(
        Wall(
          id: poi.id,
          name: poi.name,
          latitude: poi.latitude,
          longitude: poi.longitude,
          description: poi.description,
          difficulty: poi.difficulty,
          wallType: 'OutdoorWall',
          ownerName: poi.ownerName,
          sessions: [],
          rating: poi.rating,
          issues: [],
        ),
      );
    }
  }

  // Used by WallMapController (search-driven selection) — always shows wall details directly.
  void _showWallDetails(Wall wall) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      context: context,
      builder: (context) =>
          WallDetailsDialog(wall: wall, onChanged: _fetchPois),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            initialCenter: center,
            initialZoom: _defaultZoom,
            onPositionChanged: (position, hasGesture) {
              _currentZoom = position.zoom;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const [],
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                if (_buildUserMarker() != null) _buildUserMarker()!,
                ..._buildPoiMarkers(),
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
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Locating...'),
                ],
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton.small(
            heroTag: 'recenter-map',
            tooltip: 'Center on my position / Retry location',
            onPressed: retryLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
