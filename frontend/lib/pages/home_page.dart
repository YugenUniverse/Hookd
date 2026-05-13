import 'package:flutter/material.dart';
import 'dart:async';

import '../dialogs/profile_dialog.dart';
import '../pages/log_session_page.dart';
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
      ),
    );
  }

  Future<void> _openLogSessionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const LogSessionPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  tooltip: 'Log session',
                  icon: Icons.edit_calendar_outlined,
                  label: 'Log',
                  onTap: _openLogSessionSheet,
                ),
                _NavItem(
                  tooltip: 'Account',
                  icon: Icons.person_outline,
                  label: 'Me',
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => const ProfileDialog(),
                    );
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
  });

  final WallService wallService;
  final WallMapController mapController;

  @override
  State<_WallSearchSheet> createState() => _WallSearchSheetState();
}

class _WallSearchSheetState extends State<_WallSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Wall> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                        subtitle: Text('${wall.difficulty} • ${wall.type}'),
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
    this.selected = false,
    this.onTap,
    this.tooltip,
    this.onPressed,
  });

  final IconData? icon;
  final String? label;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
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
            ],
          ),
        ),
      ),
    );
  }
}
