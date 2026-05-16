import 'package:flutter/material.dart';
import 'dart:async';

import '../dialogs/login_dialog.dart';
import '../pages/log_session_page.dart';
import '../pages/global_leaderboard_page.dart';
import '../pages/user_page.dart';
import '../pages/facility_owner_page.dart';
import '../pages/public_body_page.dart';
import '../services/auth_service.dart';
import '../services/wall_service.dart';
import '../models/wall.dart';
import '../widgets/poi_map.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final WallService _wallService = WallService();
  final WallMapController _mapController = WallMapController();

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
        wallService: _wallService,
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
    return Scaffold(
      body: POIMap(controller: _mapController),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            height: 70,
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
                  icon: Icons.leaderboard_outlined, // A sleek podium icon
                  label: 'Rank',
                  onTap: _openGlobalLeaderboard,
                ),
                _NavItem(
                  tooltip: 'Log session',
                  icon: Icons.edit_calendar_outlined,
                  label: 'Log',
                  hint: isAuthenticated ? null : 'Login',
                  onTap: _openLogSessionSheet,
                ),
                _NavItem(
                  tooltip: 'Account',
                  icon: Icons.person_outline,
                  label: 'Me',
                  hint: isAuthenticated ? null : 'Login',
                  onPressed: () {
                    _runProtectedAction(() async {
                      final userType = AuthService().userType;
                      final Widget page = switch (userType) {
                        'FacilityOwner' => const FacilityOwnerPage(),
                        'PublicBody' => const PublicBodyPage(),
                        _ => const UserPage(),
                      };
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => page),
                      );
                    });
                  },
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
    required this.wallService,
    required this.mapController,
    required this.onLogWall,
  });

  final WallService wallService;
  final WallMapController mapController;
  final Future<void> Function(Wall wall) onLogWall;

  @override
  State<_WallSearchSheet> createState() => _WallSearchSheetState();
}

class _WallSearchSheetState extends State<_WallSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Wall> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  Future<void> _handleLogWall(Wall wall) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    Navigator.of(context).pop();

    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(rootContext);
      if (loggedIn != true || !AuthService().isAuthenticated) {
        return;
      }
    }

    if (!mounted || !rootContext.mounted) {
      return;
    }

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
      final results = await widget.wallService.searchWalls(query);
      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _results = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
              'Search climbing walls',
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
                hintText: 'Search by name',
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
                child: Text('Type a name and search for walls.'),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final wall = _results[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            wall.wallType == 'IndoorWall'
                                ? Icons.domain
                                : Icons.landscape,
                          ),
                        ),
                        title: Text(wall.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${wall.difficulty} • ${wall.type}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.amber[600]),
                                const SizedBox(width: 6),
                                Text(
                                  wall.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${wall.totalSessions} sessions',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
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
                          onPressed: () => _handleLogWall(wall),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.mapController.focusOnWall(wall);
                        },
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
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap ?? onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: tooltip ?? '',
                child: Icon(icon, color: color, size: 24),
              ),
              if (label != null) ...[
                const SizedBox(height: 1),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 11,
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
