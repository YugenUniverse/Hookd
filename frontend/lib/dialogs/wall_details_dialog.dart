import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../dialogs/login_dialog.dart';
import '../models/review.dart';
import '../models/wall.dart';
import '../pages/log_session_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class WallDetailsDialog extends StatefulWidget {
  final Wall wall;

  const WallDetailsDialog({super.key, required this.wall});

  @override
  State<WallDetailsDialog> createState() => _WallDetailsDialogState();
}

class _WallDetailsDialogState extends State<WallDetailsDialog> {
  late final Future<List<Review>> _reviewsFuture;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double _initialChildSize = 0.58;
  bool _expandingToFullScreen = false;
  late Wall _wall;

  static const double _minChildSize = 0.38;
  static const double _maxChildSize = 0.96;

  @override
  void initState() {
    super.initState();
    _wall = widget.wall;
    _reviewsFuture = ApiService().getWallReviews(widget.wall.id);
    _reviewsFuture.then((reviews) {
      if (!mounted) return;
      setState(() {
        _initialChildSize = _estimateInitialChildSize(reviews);
      });
    });
    // Refresh wall details (rating, totalSessions) when opening dialog
    _fetchWallDetails();
  }

  Future<void> _fetchWallDetails() async {
    final fresh = await ApiService().getWallById(widget.wall.id);
    if (fresh == null) return;
    if (!mounted) return;
    setState(() {
      _wall = fresh;
    });
  }

  double _estimateInitialChildSize(List<Review> reviews) {
    const baseFraction = 0.42;
    const reviewFraction = 0.12;
    final estimated = baseFraction + (reviews.length * reviewFraction);
    return estimated.clamp(_minChildSize, _maxChildSize).toDouble();
  }

  Future<void> _handleLogSession(BuildContext context) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    if (!AuthService().isAuthenticated) {
      final loggedIn = await showLoginDialog(rootContext);
      if (loggedIn != true || !AuthService().isAuthenticated) {
        return;
      }
    }

    if (!context.mounted || !rootContext.mounted) {
      return;
    }

    Navigator.of(context).pop();
    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LogSessionPage(initialWall: _wall),
    );
  }

  void _expandSheetToFullScreen() {
    if (_expandingToFullScreen || !_sheetController.isAttached) {
      return;
    }

    if (_sheetController.size >= _maxChildSize) {
      return;
    }

    _expandingToFullScreen = true;
    _sheetController
        .animateTo(
          _maxChildSize,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
          if (mounted) {
            setState(() {
              _expandingToFullScreen = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final bool isIndoor = _wall.wallType == 'IndoorWall';
    final IconData typeIcon = isIndoor ? Icons.domain : Icons.landscape;
    final Color typeColor = isIndoor ? Colors.blueGrey : Colors.green;
    final bool isAuthenticated = AuthService().isAuthenticated;

    return SafeArea(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        initialChildSize: _initialChildSize,
        minChildSize: _minChildSize,
        maxChildSize: _maxChildSize,
        builder: (context, scrollController) {
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(typeIcon, color: typeColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _wall.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: isAuthenticated
                            ? 'Log session'
                            : 'Log session (login required)',
                        onPressed: () => _handleLogSession(context),
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
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction != ScrollDirection.idle &&
                            _sheetController.size < _maxChildSize) {
                          _expandSheetToFullScreen();
                        }
                        return false;
                      },
                      child: ListView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          Chip(
                            label: Text(
                              isIndoor ? 'Indoor Facility' : 'Outdoor Crag',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: typeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            context,
                            Icons.fitness_center,
                            'Difficulty',
                            _wall.difficulty,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            isIndoor ? Icons.business : Icons.account_balance,
                            'Managed By',
                            _wall.ownerName ?? 'Unknown',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            Icons.history,
                            'Total Climbs',
                            '${_wall.totalSessions} sessions logged',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            Icons.star,
                            'Mean Rating',
                            _wall.rating > 0
                                ? _wall.rating.toStringAsFixed(1)
                                : 'No rating yet',
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _wall.description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<Review>>(
                            future: _reviewsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Text(
                                  'Unable to load reviews right now.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }

                              final reviews = snapshot.data ?? const <Review>[];
                              if (reviews.isEmpty) {
                                return const Text(
                                  'No reviews yet for this wall.',
                                );
                              }

                              final hasPrivateReviews = reviews.any(
                                (review) => review.sessionIsPrivate,
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasPrivateReviews)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.lock_outline,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Private sessions are only visible to you, but they still count in the wall totals.',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ...reviews.map(
                                    (review) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Card(
                                        elevation: 0,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    child: Text(
                                                      review
                                                              .reviewerName
                                                              .isNotEmpty
                                                          ? review
                                                                .reviewerName[0]
                                                                .toUpperCase()
                                                          : '?',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Wrap(
                                                      spacing: 8,
                                                      runSpacing: 2,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          review.reviewerName,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        if (_formatSessionStats(
                                                          review,
                                                        ).isNotEmpty)
                                                          Text(
                                                            _formatSessionStats(
                                                              review,
                                                            ),
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: List.generate(5, (
                                                      index,
                                                    ) {
                                                      final filled =
                                                          index < review.rating;
                                                      return Icon(
                                                        filled
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        size: 16,
                                                        color: Colors
                                                            .amber
                                                            .shade700,
                                                      );
                                                    }),
                                                  ),
                                                ],
                                              ),
                                              if (review.sessionIsPrivate) ...[
                                                const SizedBox(height: 8),
                                                Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Chip(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    avatar: Icon(
                                                      Icons.lock_outline,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                    label: const Text(
                                                      'Private',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (review.body.isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                Text(
                                                  review.body,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(height: 1.4),
                                                ),
                                              ],
                                              if (review.sessionIsPrivate) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Visible only to you.',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    final iconColor = Theme.of(context).iconTheme.color ?? Colors.grey;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: textColor, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatSessionStats(Review review) {
    final parts = <String>[];

    if (review.sessionTimeMinutes > 0) {
      parts.add(_formatDuration(review.sessionTimeMinutes));
    }

    final sessionDate = review.sessionDate;
    if (sessionDate != null) {
      parts.add(_formatDate(sessionDate));
    }

    return parts.join(' · ');
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }
}
