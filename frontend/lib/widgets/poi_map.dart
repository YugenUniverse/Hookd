import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

import '../models/poi.dart';
import '../models/wall.dart';
import '../services/api_service.dart';
import '../dialogs/wall_details_dialog.dart';
import '../dialogs/facility_details_dialog.dart';
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
  bool _isCompactScreen = false;

  // Initialized once per app session. Static so every rebuild reuses the same
  // resolved future — no tile-provider swaps mid-render.
  static final Future<CacheStore> _cacheStoreFuture = _initCacheStore();

  static Future<CacheStore> _initCacheStore() async {
    if (kIsWeb) return MemCacheStore();
    // Application support dir persists across sessions; temp dir may be cleared by the OS.
    final dir = await getApplicationSupportDirectory();
    return FileCacheStore('${dir.path}/map_tiles');
  }

  static const double _defaultZoom = 11;
  static const double _focusZoom = 16.0;
    static const double _compactDefaultZoom = 12.5;
    static const double _compactFocusZoom = 17.0;
  double _currentZoom = _defaultZoom;
  LatLng? _lastMapCenter;
  static const double _mapMoveThreshold = 2000;
  bool _skipNextMoveFetch = false;

    double get _effectiveDefaultZoom =>
      _isCompactScreen ? _compactDefaultZoom : _defaultZoom;

    double get _effectiveFocusZoom =>
      _isCompactScreen ? _compactFocusZoom : _focusZoom;

  void _handleControllerCommand() {
    final controller = widget.controller;
    final target = controller?.target;
    if (controller == null || target == null) return;

    _skipNextMoveFetch = true;
    _currentZoom = _effectiveFocusZoom;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isCompactScreen = MediaQuery.sizeOf(context).shortestSide < 600;
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

  // Only fires when the user stops moving the map (pan end / fling end).
  void _setupMapListener() {
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd) {
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

  // Exponential radius: zoom 16 → ~1km, zoom 12 → ~16km, zoom 11 → ~23km.
  double _radiusForZoom(double zoom) {
    return (1000.0 * pow(2.0, 16.0 - zoom.clamp(8.0, 16.0)))
        .clamp(1000.0, 50000.0);
  }

  // Merges incoming POIs into existing set (newer data wins on ID collision).
  // Caps total at 500 to bound memory usage.
  static List<Poi> _mergePois(List<Poi> existing, List<Poi> incoming) {
    final merged = <String, Poi>{for (final p in existing) p.id: p};
    for (final p in incoming) {
      merged[p.id] = p;
    }
    const maxPois = 500;
    if (merged.length > maxPois) {
      return merged.values.skip(merged.length - maxPois).toList();
    }
    return merged.values.toList();
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
          _pois = _mergePois(_pois, pois);
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
            _pois = _mergePois(_pois, pois);
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
                _mapController.move(_userLocation!, _effectiveDefaultZoom);
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

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      setState(() {
        _locating = false;
      });
      _fetchPois();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permission denied: $permission');
      setState(() {
        _locating = false;
      });
      _fetchPois();
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
            _mapController.move(_userLocation!, _effectiveDefaultZoom);
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
          width: 48,
          height: 48,
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
              child: const Icon(Icons.domain, color: Colors.white, size: 24),
            ),
          ),
        );
      }

      final wall = poi as OutdoorWallPoi;
      final markerColor = _getDifficultyColor(wall.difficulty);
      return Marker(
        width: 44,
        height: 44,
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
            child: const Icon(Icons.landscape, color: Colors.white, size: 22),
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
    final maptilerKey = dotenv.env['MAPTILER_KEY'];
    final maptilerStyle = (dotenv.env['MAPTILER_STYLE'] ?? 'basic-v2').trim();
    final useMapTiler = maptilerKey != null && maptilerKey.isNotEmpty;
    final tileUrl = useMapTiler
        ? 'https://api.maptiler.com/maps/$maptilerStyle/{z}/{x}/{y}.png?key=$maptilerKey'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    final userMarker = _buildUserMarker();

    // _cacheStoreFuture is static: after the first resolution it returns
    // immediately on every rebuild, so FutureBuilder never falls through to the
    // no-TileLayer branch after the very first frame.
    return FutureBuilder<CacheStore>(
      future: _cacheStoreFuture,
      builder: (context, snapshot) {
        final cacheStore = snapshot.data;
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(46.067, 11.117),
                initialZoom: _effectiveDefaultZoom,
                // Prevents zooming out past the Trentino Alto Adige scale (~220km visible).
                minZoom: 8,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                // TileLayer is withheld until the cache store is ready so that
                // no tile is ever fetched outside the cached provider.
                if (cacheStore != null)
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const [],
                    tileProvider: CachedTileProvider(
                      store: cacheStore,
                      maxStale: const Duration(days: 30),
                    ),
                  ),
                MarkerLayer(
                  markers: [
                    ?userMarker,
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
          bottom: 16,
          child: SafeArea(
            minimum: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              heroTag: 'recenter-map',
              tooltip: 'Center on my position / Retry location',
              onPressed: retryLocation,
              child: const Icon(Icons.my_location, size: 28),
            ),
          ),
        ),
      ],
    );
  },
  );
  }
}
