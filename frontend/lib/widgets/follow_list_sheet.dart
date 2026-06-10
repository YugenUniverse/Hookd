import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../pages/climber_profile_page.dart';

enum FollowListType { followers, following }

Future<void> showFollowListSheet(
  BuildContext context, {
  required String userId,
  required FollowListType type,
  required int count,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FollowListSheet(userId: userId, type: type, count: count),
  );
}

class _FollowListSheet extends StatefulWidget {
  const _FollowListSheet({
    required this.userId,
    required this.type,
    required this.count,
  });

  final String userId;
  final FollowListType type;
  final int count;

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = widget.type == FollowListType.followers
        ? await ApiService().getFollowers(widget.userId)
        : await ApiService().getFollowingUsers(widget.userId);
    if (mounted) setState(() { _users = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.type == FollowListType.followers ? 'Followers' : 'Following';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '$label (${widget.count})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No $label yet.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _users.length,
                        itemBuilder: (ctx, i) {
                          final u = _users[i];
                          final uid =
                              (u['id'] ?? u['_id'] ?? '').toString();
                          final uname = u['username']?.toString() ?? '';
                          final initial = uname.isNotEmpty
                              ? uname[0].toUpperCase()
                              : '?';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                initial,
                                style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text('@$uname',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ClimberProfilePage(
                                  userId: uid,
                                  initialUsername: uname,
                                ),
                              ));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
