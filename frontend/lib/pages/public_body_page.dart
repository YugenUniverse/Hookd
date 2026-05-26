import 'package:flutter/material.dart';

import '../models/poi.dart' show IndoorWallSummary;
import '../models/user.dart';
import '../pages/all_walls_page.dart';
import '../pages/edit_profile_page.dart';
import '../pages/wall_issues_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../dialogs/login_dialog.dart';
import '../utils/image_helpers.dart';

const _kMaxPreviewWalls = 5;

class PublicBodyPage extends StatefulWidget {
  const PublicBodyPage({super.key});

  @override
  State<PublicBodyPage> createState() => _PublicBodyPageState();
}

class _PublicBodyPageState extends State<PublicBodyPage> {
  late Future<User> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<User> _loadProfile() async {
    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(context);
      if (loggedIn != true || !AuthService().isAuthenticated) {
        throw StateError('Not authenticated');
      }
    }
    final user = await ApiService().fetchCurrentUserProfile(bearerToken: AuthService().jwt);
    AuthService().setCurrentUserProfile(
      avatar: user.profilePictureUrl ?? '',
      username: user.username,
    );
    return user;
  }

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
                    Builder(builder: (ctx) {
                      final screenWidth = MediaQuery.of(ctx).size.width;
                      final dialogMaxWidth = screenWidth < 600 ? screenWidth * 0.96 : 560.0;
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
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
                              publicBodyData: user.publicBodyData,
                              onEditProfile: () async {
                                final updated = await Navigator.of(context).push<User>(
                                  MaterialPageRoute(
                                    builder: (_) => EditProfilePage(user: user),
                                  ),
                                );
                                if (updated != null) _refresh();
                              },
                            ),
                            const SizedBox(height: 20),
                            _NavButton(
                              icon: Icons.report_problem_outlined,
                              label: 'Wall issues',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const WallIssuesPage(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _WallsSection(
                              walls: user.publicBodyData?.walls ?? [],
                              onRefresh: _refresh,
                            ),
                          ],
                        ),
                      ),
                    );
                    }),
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
    this.publicBodyData,
    this.onEditProfile,
  });

  final String username;
  final String initial;
  final String email;
  final bool isAdmin;
  final String memberSince;
  final String? profilePictureUrl;
  final PublicBodyData? publicBodyData;
  final VoidCallback? onEditProfile;

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
                backgroundColor: colorScheme.secondaryContainer,
                backgroundImage: avatarImageProvider(profilePictureUrl),
                child: avatarImageProvider(profilePictureUrl) == null
                    ? Text(
                        initial,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
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
                        _StatusChip(label: 'Public Body', icon: Icons.account_balance),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEditProfile,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (publicBodyData != null && publicBodyData!.name.isNotEmpty) ...[
            _InfoTile(
              icon: Icons.account_balance_outlined,
              title: 'Organisation',
              value: publicBodyData!.name,
            ),
            const SizedBox(height: 8),
          ],
          if (publicBodyData != null && publicBodyData!.description.isNotEmpty) ...[
            _InfoTile(
              icon: Icons.info_outline,
              title: 'About',
              value: publicBodyData!.description,
            ),
            const SizedBox(height: 8),
          ],
          if (publicBodyData?.address != null && publicBodyData!.address!.isNotEmpty) ...[
            _InfoTile(
              icon: Icons.location_on_outlined,
              title: 'Location',
              value: publicBodyData!.address!,
            ),
            const SizedBox(height: 8),
          ],
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

// ─── Walls section ────────────────────────────────────────────────────────────

class _WallsSection extends StatefulWidget {
  const _WallsSection({required this.walls, required this.onRefresh});

  final List<IndoorWallSummary> walls;
  final VoidCallback onRefresh;

  @override
  State<_WallsSection> createState() => _WallsSectionState();
}

class _WallsSectionState extends State<_WallsSection> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<IndoorWallSummary> get _filtered => _query.isEmpty
      ? widget.walls
      : widget.walls
          .where((w) => w.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  Future<void> _showCreateDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _CreateWallDialog(),
    );

    if (confirmed == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) widget.onRefresh();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wall created successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filtered;
    final isSearching = _query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Walls (${widget.walls.length})',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _showCreateDialog(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Add wall'),
                ],
              ),
            ),
          ],
        ),
        if (widget.walls.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (q) => setState(() => _query = q),
            decoration: InputDecoration(
              hintText: 'Search walls…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (widget.walls.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'No walls registered yet. Add your first outdoor wall.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (isSearching && filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'No walls match "$_query".',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else if (isSearching) ...[
          ...filtered.map(
            (wall) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WallTile(wall: wall, onRefresh: widget.onRefresh),
            ),
          ),
        ] else ...[
          ...widget.walls.take(_kMaxPreviewWalls).map(
                (wall) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WallTile(wall: wall, onRefresh: widget.onRefresh),
                ),
              ),
          if (widget.walls.length > _kMaxPreviewWalls)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllWallsPage(
                        title: 'All walls',
                        walls: widget.walls,
                        canDelete: true,
                      ),
                    ),
                  );
                  widget.onRefresh();
                },
                icon: const Icon(Icons.list, size: 18),
                label: Text('View all ${widget.walls.length} walls'),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── Wall tile ────────────────────────────────────────────────────────────────

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
        if (context.mounted) onRefresh();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wall updated successfully')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wall?'),
        content: Text('This will permanently delete "${wall.name}". This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ApiService().deleteWall(wall.id);
    if (!context.mounted) return;

    if (ok) {
      onRefresh();
      messenger.showSnackBar(const SnackBar(content: Text('Wall deleted')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Failed to delete wall')));
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
            child: const Icon(Icons.landscape, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wall.name,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
          if (wall.rating > 0) ...[
            Icon(Icons.star, size: 14, color: Colors.amber.shade700),
            const SizedBox(width: 2),
            Text(
              wall.rating.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Edit wall',
            onPressed: () => _showEditDialog(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete wall',
            onPressed: () => _confirmDelete(context),
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
          ),
        ],
      ),
    );
  }
}

// ─── Create wall dialog ───────────────────────────────────────────────────────

class _CreateWallDialog extends StatefulWidget {
  const _CreateWallDialog();

  @override
  State<_CreateWallDialog> createState() => _CreateWallDialogState();
}

class _CreateWallDialogState extends State<_CreateWallDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _latitudeController = TextEditingController();
  String _difficulty = 'UNKNOWN';
  bool _saving = false;

  static const _difficultyOptions = [
    'UNKNOWN',
    'BEGINNER',
    'INTERMEDIATE',
    'ADVANCED',
    'EXPERT',
  ];

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }
    if (lng == null || lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude and latitude are required')),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await ApiService().createWall(
      name: name,
      description: description,
      difficulty: _difficulty,
      longitude: lng,
      latitude: lat,
      address: address.isNotEmpty ? address : null,
    );
    if (!mounted) return;

    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Add outdoor wall'),
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
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _difficulty = v);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Coordinates are required to place the wall on the map.',
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
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ─── Edit wall dialog ─────────────────────────────────────────────────────────

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
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
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _difficulty = v);
                    },
            ),
            const SizedBox(height: 12),
            Text(
              'Changes apply everywhere this wall appears.',
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

// ─── Nav button ───────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

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
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
