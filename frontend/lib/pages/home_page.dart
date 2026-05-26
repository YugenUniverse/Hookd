import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dialogs/login_dialog.dart';
import '../models/poi.dart';
import '../models/wall.dart';
import '../pages/facility_owner_page.dart';
import '../pages/global_leaderboard_page.dart';
import '../pages/log_session_page.dart';
import '../pages/public_body_page.dart';
import '../pages/user_page.dart';
import '../services/api_service.dart';
import '../utils/image_helpers.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../widgets/poi_map.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  final WallMapController _mapController = WallMapController();
  late final AnimationController _navExpand;
  late final Animation<double> _navAnim;

  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
    if (AuthService().isAuthenticated) _prefetchAvatar();
    _navExpand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _navAnim = CurvedAnimation(parent: _navExpand, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    _navExpand.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService().isAuthenticated && AuthService().avatar == null) {
      _prefetchAvatar();
    }
    setState(() {});
  }

  Widget? _buildNavAvatar(bool isAuthenticated, String? avatar, double radius) {
    if (!isAuthenticated || avatar == null || avatar.isEmpty) return null;
    final provider = avatarImageProvider(avatar);
    if (provider == null) return null;
    return CircleAvatar(radius: radius, backgroundImage: provider);
  }

  void _prefetchAvatar() {
    ApiService().fetchCurrentUserProfile().then((user) {
      AuthService().setCurrentUserProfile(
        avatar: user.profilePictureUrl ?? '',
        username: user.username,
      );
    }).catchError((_) {});
  }

  Future<bool> _ensureAuthenticated() async {
    if (AuthService().isAuthenticated) {
      return true;
    }

    final loggedIn = await showLoginDialog(context);
    return loggedIn == true && AuthService().isAuthenticated;
  }

  Future<void> _runProtectedAction(Future<void> Function() action) async {
    if (!await _ensureAuthenticated()) {
      return;
    }
    await action();
  }

  Future<void> _openWallSearch() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _WallSearchSheet(
        mapController: _mapController,
        onLogWall: _openLogSessionSheetWithWall,
      ),
    );
  }

  Future<void> _openLogSessionSheet() async {
    await _runProtectedAction(
      () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const LogSessionPage(),
      ),
    );
  }

  Future<void> _openLogSessionSheetWithWall(Wall wall) async {
    await _runProtectedAction(
      () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => LogSessionPage(initialWall: wall),
      ),
    );
  }

  void _openGlobalLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GlobalLeaderboardPage()),
    );
  }

  void _openAccountPage() async {
    if (!AuthService().isAuthenticated) {
      await _ensureAuthenticated();
      return;
    }

    final userType = AuthService().userType;
    final Widget page = switch (userType) {
      'FacilityOwner' => const FacilityOwnerPage(),
      'PublicBody' => const PublicBodyPage(),
      _ => const UserPage(),
    };

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  bool get _isDesktopLike {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => false,
      TargetPlatform.fuchsia => false,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;
    final userType = AuthService().userType;
    final isOwnerType = userType == 'FacilityOwner' || userType == 'PublicBody';
    if (_isDesktopLike) {
      final cs = Theme.of(context).colorScheme;

      // Builds one nav button. Width math: 8px outer-h + 40px icon + 128*t label + 8px outer-h = 56+128*t total.
      Widget navBtn({
        required IconData icon,
        Widget? iconWidget,
        required String label,
        required VoidCallback onTap,
        bool selected = false,
        Widget? lockBadge,
        required double t,
      }) {
        final color = selected ? cs.primary : cs.onSurfaceVariant;
        final iconChild = iconWidget ?? Icon(icon, size: 24, color: color);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: lockBadge != null
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                iconChild,
                                lockBadge,
                              ],
                            )
                          : iconChild,
                    ),
                  ),
                  ClipRect(
                    child: SizedBox(
                      width: 128.0 * t,
                      child: Opacity(
                        opacity: t,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            label,
                            softWrap: false,
                            style: TextStyle(
                              color: color,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              POIMap(controller: _mapController),
              Positioned(
                left: 16,
                top: 16,
                child: MouseRegion(
                  onEnter: (_) => _navExpand.forward(),
                  onExit: (_) => _navExpand.reverse(),
                  child: AnimatedBuilder(
                    animation: _navAnim,
                    builder: (context, _) {
                      final t = _navAnim.value;
                      return Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(24),
                        color: cs.surface,
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: 56.0 + 128.0 * t,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              navBtn(
                                icon: Icons.map_outlined,
                                label: 'Map',
                                onTap: () {},
                                selected: true,
                                t: t,
                              ),
                              navBtn(
                                icon: Icons.search,
                                label: 'Search',
                                onTap: _openWallSearch,
                                t: t,
                              ),
                              navBtn(
                                icon: Icons.leaderboard_outlined,
                                label: 'Rank',
                                onTap: _openGlobalLeaderboard,
                                t: t,
                              ),
                              if (!isOwnerType)
                                navBtn(
                                  icon: Icons.edit_calendar_outlined,
                                  label: 'Log climb',
                                  onTap: _openLogSessionSheet,
                                  lockBadge: !isAuthenticated
                                      ? Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Icon(
                                            Icons.lock_outline,
                                            size: 11,
                                            color: cs.primary,
                                          ),
                                        )
                                      : null,
                                  t: t,
                                ),
                              navBtn(
                                icon: isAuthenticated
                                    ? Icons.person_outline
                                    : Icons.login,
                                iconWidget: _buildNavAvatar(isAuthenticated, AuthService().avatar, 12),
                                label: isAuthenticated ? 'Me' : 'Login',
                                onTap: _openAccountPage,
                                t: t,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      body: POIMap(controller: _mapController),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            height: 84,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.map_outlined,
                  label: 'Map',
                  selected: true,
                  onTap: () {},
                ),
                _NavItem(
                  tooltip: 'Search walls',
                  icon: Icons.search,
                  label: 'Search',
                  onTap: _openWallSearch,
                ),
                _NavItem(
                  tooltip: 'Global Rankings',
                  icon: Icons.leaderboard_outlined,
                  label: 'Rank',
                  onTap: _openGlobalLeaderboard,
                ),
                if (!isOwnerType)
                  _NavItem(
                    tooltip: 'Log session',
                    icon: Icons.edit_calendar_outlined,
                    label: 'Log',
                    hint: isAuthenticated ? null : 'Login',
                    onTap: _openLogSessionSheet,
                  ),
                _NavItem(
                  tooltip: isAuthenticated ? 'Account' : 'Login',
                  icon: isAuthenticated ? Icons.person_outline : Icons.login,
                  label: isAuthenticated ? 'Me' : 'Login',
                  onPressed: _openAccountPage,
                  avatarWidget: _buildNavAvatar(isAuthenticated, AuthService().avatar, 14),
                ),
              ],
            ),
          ),
        ),
      ),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const SizedBox.shrink(),
    );
  }
}

class _WallSearchSheet extends StatefulWidget {
  const _WallSearchSheet({
    required this.mapController,
    required this.onLogWall,
  });

  final WallMapController mapController;
  final Future<void> Function(Wall wall) onLogWall;

  @override
  State<_WallSearchSheet> createState() => _WallSearchSheetState();
}

class _WallSearchSheetState extends State<_WallSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Poi> _results = [];
  bool _loading = false;
  bool _showingNearby = false;
  String? _error;
  Timer? _debounce;
  String _selectedPoiType = 'all';
  String _selectedDifficulty = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.text.trim().isEmpty) {
        _fetchNearby();
      }
    });
  }

  Future<void> _fetchNearby() async {
    setState(() {
      _loading = true;
      _error = null;
      _showingNearby = false;
    });

    try {
      final double lng;
      final double lat;

      final target = widget.mapController.target;
      if (target != null) {
        lng = target.longitude;
        lat = target.latitude;
      } else {
        try {
          // Try last known position first (instant, no GPS wait).
          Position? pos = await Geolocator.getLastKnownPosition();
          pos ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 5));
          lat = pos.latitude;
          lng = pos.longitude;
        } catch (_) {
          final all = await ApiService().getAllPois();
          if (mounted) {
            setState(() {
              _results = all;
              _showingNearby = true;
            });
          }
          return;
        }
      }

      final pois = await ApiService().getNearbyPois(lng, lat);
      if (mounted) {
        setState(() {
          _results = pois;
          _showingNearby = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _results = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogOutdoorWall(OutdoorWallPoi poi) async {
    final wall = Wall(
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
    );

    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();

    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(rootContext);
      if (loggedIn != true || !AuthService().isAuthenticated) return;
    }

    if (!mounted || !rootContext.mounted) return;
    await widget.onLogWall(wall);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  void _setPoiType(String value) {
    if (_selectedPoiType == value) return;
    setState(() {
      _selectedPoiType = value;
    });
    _search();
  }

  void _setDifficulty(String value) {
    if (_selectedDifficulty == value) return;
    setState(() {
      _selectedDifficulty = value;
    });
    _search();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      await _fetchNearby();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showingNearby = false;
    });

    try {
      final results = await ApiService().searchPois(
        query,
        type: _selectedPoiType,
        difficulty: _selectedDifficulty == 'all' ? null : _selectedDifficulty,
      );
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _results = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectPoi(Poi poi) {
    Navigator.of(context).pop();
    if (poi is FacilityPoi) {
      widget.mapController.focusOnFacility(poi);
    } else if (poi is OutdoorWallPoi) {
      widget.mapController.focusOnWall(
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

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search climbing spots',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search facilities and outdoor walls',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedPoiType == 'all',
                    onSelected: (_) => _setPoiType('all'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Indoor'),
                    selected: _selectedPoiType == 'indoor',
                    onSelected: (_) => _setPoiType('indoor'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Outdoor'),
                    selected: _selectedPoiType == 'outdoor',
                    onSelected: (_) => _setPoiType('outdoor'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 1,
                      height: 22,
                      child: ColoredBox(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Any difficulty'),
                    selected: _selectedDifficulty == 'all',
                    onSelected: (_) => _setDifficulty('all'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Beginner'),
                    selected: _selectedDifficulty == 'BEGINNER',
                    onSelected: (_) => _setDifficulty('BEGINNER'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Intermediate'),
                    selected: _selectedDifficulty == 'INTERMEDIATE',
                    onSelected: (_) => _setDifficulty('INTERMEDIATE'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Advanced'),
                    selected: _selectedDifficulty == 'ADVANCED',
                    onSelected: (_) => _setDifficulty('ADVANCED'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Expert'),
                    selected: _selectedDifficulty == 'EXPERT',
                    onSelected: (_) => _setDifficulty('EXPERT'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No results found. Try a different search or filters.',
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showingNearby)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Nearby',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final poi = _results[index];
                          final facilityPoi = poi is FacilityPoi ? poi : null;
                          final outdoorPoi = poi is OutdoorWallPoi ? poi : null;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  facilityPoi != null
                                      ? Icons.domain
                                      : Icons.landscape,
                                ),
                              ),
                              title: Text(poi.name),
                              subtitle: facilityPoi != null
                                  ? Text(
                                      'Indoor Facility • ${facilityPoi.walls.length} wall${facilityPoi.walls.length == 1 ? '' : 's'}',
                                    )
                                  : Text(
                                      '${outdoorPoi!.difficulty} • Outdoor Wall',
                                    ),
                              trailing: outdoorPoi != null
                                  ? IconButton(
                                      tooltip: isAuthenticated
                                          ? 'Log session'
                                          : 'Log session (login required)',
                                      icon: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(
                                            Icons.edit_calendar_outlined,
                                          ),
                                          if (!isAuthenticated)
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: Icon(
                                                Icons.lock_outline,
                                                size: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      onPressed: () =>
                                          _handleLogOutdoorWall(outdoorPoi),
                                    )
                                  : null,
                              onTap: () => _selectPoi(poi),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.icon,
    this.avatarWidget,
    this.label,
    this.hint,
    this.selected = false,
    this.onTap,
    this.tooltip,
    this.onPressed,
  });

  final IconData? icon;
  final Widget? avatarWidget;
  final String? label;
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDesktopLike =
        kIsWeb ||
        switch (defaultTargetPlatform) {
          TargetPlatform.linux ||
          TargetPlatform.macOS ||
          TargetPlatform.windows => true,
          _ => false,
        };
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ?? onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktopLike ? 6.0 : 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: tooltip ?? '',
                child: avatarWidget ??
                    Icon(
                      icon,
                      color: color,
                      size: isDesktopLike ? 24.0 : 28.0,
                    ),
              ),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: isDesktopLike ? 11.0 : 12.0,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 11,
                      color: color.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      hint!,
                      style: TextStyle(
                        fontSize: 9,
                        color: color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
