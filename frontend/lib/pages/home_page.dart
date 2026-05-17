import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../dialogs/login_dialog.dart';
import '../pages/log_session_page.dart';
import '../pages/global_leaderboard_page.dart';
import '../pages/user_page.dart';
import '../pages/facility_owner_page.dart';
import '../pages/public_body_page.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/poi.dart';
import '../models/wall.dart';
import '../widgets/poi_map.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final WallMapController _mapController = WallMapController();

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

  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    setState(() {});
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

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = AuthService().isAuthenticated;
    final userType = AuthService().userType;
    final isOwnerType = userType == 'FacilityOwner' || userType == 'PublicBody';

    if (_isDesktopLike) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(22),
                  color: Theme.of(context).colorScheme.surface,
                  child: NavigationRail(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedIndex: 0,
                    useIndicator: true,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 84,
                    minExtendedWidth: 84,
                    groupAlignment: -0.9,
                    leading: const SizedBox(height: 8),
                    trailing: const SizedBox(height: 8),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: Text('Map'),
                      ),
                      NavigationRailDestination(
                        icon: Tooltip(
                          message: 'Search walls',
                          child: const Icon(Icons.search),
                        ),
                        label: const Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Tooltip(
                          message: 'Global Rankings',
                          child: const Icon(Icons.leaderboard_outlined),
                        ),
                        label: const Text('Rank'),
                      ),
                      if (!isOwnerType)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: isAuthenticated
                                ? 'Log session'
                                : 'Log session (login required)',
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.edit_calendar_outlined),
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
                          ),
                          label: const Text('Log climb'),
                        ),
                      NavigationRailDestination(
                        icon: Tooltip(
                          message: isAuthenticated ? 'Account' : 'Login',
                          child: Icon(
                            isAuthenticated
                                ? Icons.person_outline
                                : Icons.login,
                          ),
                        ),
                        label: Text(isAuthenticated ? 'Me' : 'Login'),
                      ),
                    ],
                    onDestinationSelected: (index) {
                      switch (index) {
                        case 0:
                          break;
                        case 1:
                          _openWallSearch();
                          break;
                        case 2:
                          _openGlobalLeaderboard();
                          break;
                        case 3:
                          if (!isOwnerType) {
                            _openLogSessionSheet();
                          } else {
                            _openAccountPage();
                          }
                          break;
                        case 4:
                          _openAccountPage();
                          break;
                      }
                    },
                  ),
                ),
              ),
              Expanded(child: POIMap(controller: _mapController)),
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
  String? _error;
  Timer? _debounce;
  String _selectedPoiType = 'all';
  String _selectedDifficulty = 'all';

  static const List<String> _difficultyOptions = [
    'all',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT',
  ];

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

  void _clearFilters() {
    if (_selectedPoiType == 'all' && _selectedDifficulty == 'all') {
      return;
    }
    setState(() {
      _selectedPoiType = 'all';
      _selectedDifficulty = 'all';
    });
    _search();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _selectedPoiType == 'all',
                          onSelected: (_) => _setPoiType('all'),
                        ),
                        ChoiceChip(
                          label: const Text('Indoor'),
                          selected: _selectedPoiType == 'indoor',
                          onSelected: (_) => _setPoiType('indoor'),
                        ),
                        ChoiceChip(
                          label: const Text('Outdoor'),
                          selected: _selectedPoiType == 'outdoor',
                          onSelected: (_) => _setPoiType('outdoor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: _difficultyOptions
                          .map(
                            (difficulty) => DropdownMenuItem<String>(
                              value: difficulty,
                              child: Text(
                                difficulty == 'all'
                                    ? 'Any difficulty'
                                    : difficulty,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _setDifficulty(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Type a name to search for facilities and outdoor walls.',
                ),
              )
            else
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
                            : Text('${outdoorPoi!.difficulty} • Outdoor Wall'),
                        trailing: outdoorPoi != null
                            ? IconButton(
                                tooltip: isAuthenticated
                                    ? 'Log session'
                                    : 'Log session (login required)',
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.edit_calendar_outlined),
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
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    this.icon,
    this.label,
    this.hint,
    this.selected = false,
    this.onTap,
    this.tooltip,
    this.onPressed,
  });

  final IconData? icon;
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
                child: Icon(
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
