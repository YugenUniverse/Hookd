import 'dart:async';

import 'package:flutter/material.dart';

import '../models/poi.dart' show IndoorWallSummary;
import '../models/user.dart';
import '../pages/all_walls_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

const _kMaxPreviewWalls = 5;

class FacilityOwnerPage extends StatefulWidget {
  const FacilityOwnerPage({super.key});

  @override
  State<FacilityOwnerPage> createState() => _FacilityOwnerPageState();
}

class _FacilityOwnerPageState extends State<FacilityOwnerPage> {
  late Future<User> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<User> _loadProfile() =>
      ApiService().fetchCurrentUserProfile(bearerToken: AuthService().jwt);

  void _refresh() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Do you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Logged out')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<User>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 44, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Unable to load profile', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final user = snapshot.data;
              if (user == null) {
                return const Center(child: Text('No profile data available.'));
              }

              final username = user.username.isNotEmpty ? user.username : 'User';
              final initial = username[0].toUpperCase();
              final memberSince = user.createdAt != null
                  ? MaterialLocalizations.of(context).formatShortDate(user.createdAt!)
                  : 'Unknown';

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AccountCard(
                              username: username,
                              initial: initial,
                              email: user.email,
                              isAdmin: user.isAdmin,
                              profilePictureUrl: user.profilePictureUrl,
                              memberSince: memberSince,
                            ),
                            const SizedBox(height: 20),
                            if (user.facilityData != null)
                              _FacilityCard(
                                facility: user.facilityData!,
                                onRefresh: _refresh,
                              )
                            else
                              _ClaimFacilityCard(onClaimed: _refresh),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Account header card ──────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.username,
    required this.initial,
    required this.email,
    required this.isAdmin,
    required this.memberSince,
    this.profilePictureUrl,
  });

  final String username;
  final String initial;
  final String email;
  final bool isAdmin;
  final String memberSince;
  final String? profilePictureUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                    ? NetworkImage(profilePictureUrl!)
                    : null,
                child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                    ? Text(
                        initial,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email.isNotEmpty ? email : 'No email on file',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isAdmin)
                          _StatusChip(label: 'Admin', icon: Icons.shield),
                        _StatusChip(label: 'Facility Owner', icon: Icons.domain),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InfoTile(
            icon: Icons.calendar_month_outlined,
            title: 'Member since',
            value: memberSince,
          ),
        ],
      ),
    );
  }
}

// ─── Linked facility card ─────────────────────────────────────────────────────

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.facility, required this.onRefresh});

  final FacilityProfile facility;
  final VoidCallback onRefresh;

  Future<void> _showEditDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditFacilityDialog(facility: facility),
    );

    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onRefresh();
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility updated successfully')),
        );
      }
    }
  }

  Future<void> _unpairFacility(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unpair facility?'),
        content: const Text('This will unlink your account from the facility. The facility will remain in the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ApiService().unpairFacility(facility.id);
    if (!context.mounted) return;

    if (ok) {
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facility unpaired successfully')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unpair facility')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your facility',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.domain, size: 28, color: Colors.blueGrey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      facility.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (facility.address != null && facility.address!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16,
                        color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facility.address!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (facility.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(facility.description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditDialog(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit facility'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _unpairFacility(context),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Unpair'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Walls (${facility.walls.length})',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (facility.walls.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'No walls registered yet. Add walls from the map.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          ...facility.walls.take(_kMaxPreviewWalls).map((wall) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WallTile(wall: wall, onRefresh: onRefresh),
              )),
          if (facility.walls.length > _kMaxPreviewWalls)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllWallsPage(
                        title: 'All walls — ${facility.name}',
                        walls: facility.walls,
                        canDelete: false,
                      ),
                    ),
                  );
                  onRefresh();
                },
                icon: const Icon(Icons.list, size: 18),
                label: Text(
                  'View all ${facility.walls.length} walls',
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EditFacilityDialog extends StatefulWidget {
  const _EditFacilityDialog({required this.facility});

  final FacilityProfile facility;

  @override
  State<_EditFacilityDialog> createState() => _EditFacilityDialogState();
}

class _EditFacilityDialogState extends State<_EditFacilityDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _latitudeController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.facility.name);
    _descriptionController = TextEditingController(text: widget.facility.description);
    _addressController = TextEditingController(text: widget.facility.address ?? '');
    _longitudeController = TextEditingController(
      text: widget.facility.coordinates != null ? widget.facility.coordinates![0].toString() : '',
    );
    _latitudeController = TextEditingController(
      text: widget.facility.coordinates != null ? widget.facility.coordinates![1].toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final lng = double.tryParse(_longitudeController.text.trim());
    final lat = double.tryParse(_latitudeController.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    if (lng == null || lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Longitude and latitude are required to save the facility location'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await ApiService().updateFacility(
      widget.facility.id,
      name: name,
      description: description,
      location: {
        'type': 'Point',
        'coordinates': [lng, lat],
        if (address.isNotEmpty) 'address': address,
      },
    );
    if (!mounted) return;

    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Edit facility'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Update the marker location by providing both coordinates.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }
}

class _WallTile extends StatelessWidget {
  const _WallTile({required this.wall, required this.onRefresh});

  final IndoorWallSummary wall;
  final VoidCallback onRefresh;

  Color _difficultyColor(String d) => switch (d.toUpperCase()) {
        'BEGINNER' => Colors.green,
        'INTERMEDIATE' => Colors.amber.shade700,
        'ADVANCED' => Colors.orange,
        'EXPERT' => Colors.red.shade700,
        _ => Colors.grey,
      };

  Future<void> _showEditDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditWallDialog(wall: wall),
    );

    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onRefresh();
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wall updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOpen = wall.status.toUpperCase() == 'OPEN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _difficultyColor(wall.difficulty),
            child: const Icon(Icons.route, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wall.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      wall.difficulty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isOpen) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          wall.status.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit wall',
            onPressed: () => _showEditDialog(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (wall.rating > 0) ...[
            Icon(Icons.star, size: 14, color: Colors.amber.shade700),
            const SizedBox(width: 2),
            Text(
              wall.rating.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditWallDialog extends StatefulWidget {
  const _EditWallDialog({required this.wall});

  final IndoorWallSummary wall;

  @override
  State<_EditWallDialog> createState() => _EditWallDialogState();
}

class _EditWallDialogState extends State<_EditWallDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _difficulty;
  bool _saving = false;

  static const _difficultyOptions = [
    'UNKNOWN',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wall.name);
    _descriptionController = TextEditingController(text: widget.wall.description);
    _difficulty = _difficultyOptions.contains(widget.wall.difficulty.toUpperCase())
        ? widget.wall.difficulty.toUpperCase()
        : 'UNKNOWN';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await ApiService().updateWall(
      widget.wall.id,
      name: name,
      description: description,
      difficulty: _difficulty,
    );
    if (!mounted) return;

    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Edit wall'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: const InputDecoration(labelText: 'Difficulty'),
              items: _difficultyOptions
                  .map(
                    (difficulty) => DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _difficulty = value);
                    },
            ),
            const SizedBox(height: 12),
            Text(
              'Changes are saved on the wall itself and will show up everywhere it is used.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Apply'),
        ),
      ],
    );
  }
}

// ─── Claim facility card ──────────────────────────────────────────────────────

class _ClaimFacilityCard extends StatefulWidget {
  const _ClaimFacilityCard({required this.onClaimed});

  final VoidCallback onClaimed;

  @override
  State<_ClaimFacilityCard> createState() => _ClaimFacilityCardState();
}

class _ClaimFacilityCardState extends State<_ClaimFacilityCard> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  Timer? _debounce;
  bool _searching = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onChanged);
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    final q = _searchCtrl.text.trim();
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _selected = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final res = await ApiService().searchFacilities(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searching = false;
        if (_selected != null && !res.any((r) => r['_id'] == _selected!['_id'])) {
          _selected = null;
        }
      });
    });
  }

  Future<void> _claim() async {
    if (_selected == null) return;
    final id = (_selected!['_id'] ?? _selected!['id'])?.toString();
    if (id == null) return;

    setState(() => _claiming = true);
    final ok = await ApiService().claimFacility(id);
    if (!mounted) return;
    setState(() => _claiming = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facility claimed! Refreshing…')),
      );
      widget.onClaimed();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to claim facility. It may already have an owner.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Facility',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.link_off, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    'No facility linked',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Search for your gym by name and claim it to manage its walls.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                enabled: !_claiming,
                decoration: InputDecoration(
                  labelText: 'Search facility by name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _results = [];
                                  _selected = null;
                                });
                              },
                            )
                          : null,
                ),
              ),

              // Selected facility chip
              if (_selected != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selected!['name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _claiming
                            ? null
                            : () => setState(() => _selected = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _claiming ? null : _claim,
                  icon: _claiming
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Claim this facility'),
                ),
              ],

              // Search results
              if (_results.isNotEmpty && _selected == null) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _results.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: colorScheme.outlineVariant),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.domain),
                          title: Text(_results[i]['name']?.toString() ?? ''),
                          subtitle: _results[i]['location']?['address'] != null
                              ? Text(_results[i]['location']['address'].toString())
                              : null,
                          onTap: () => setState(() {
                            _selected = _results[i];
                            _results = [];
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (_results.isEmpty &&
                  _searchCtrl.text.trim().length >= 2 &&
                  !_searching &&
                  _selected == null) ...[
                const SizedBox(height: 12),
                Text(
                  'No unclaimed facilities found. Contact us to add yours.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared sub-widgets (mirrors user_page.dart) ──────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
