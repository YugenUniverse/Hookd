import 'package:flutter/material.dart';

import '../models/poi.dart';
import '../models/wall.dart';
import '../services/api_service.dart';
import '../dialogs/wall_details_dialog.dart';

class FacilityDetailsDialog extends StatelessWidget {
  final FacilityPoi facility;

  const FacilityDetailsDialog({super.key, required this.facility});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        width: double.infinity,
        child: Material(
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
                    const Icon(Icons.domain, color: Colors.blueGrey, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        facility.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Chip(
                  label: Text(
                    'Indoor Facility',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.blueGrey,
                ),
                if (facility.address != null &&
                    facility.address!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(facility.address!)),
                    ],
                  ),
                ],
                if (facility.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    facility.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Climbing Walls (${facility.walls.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: facility.walls.isEmpty
                      ? const Center(
                          child: Text(
                            'No walls registered for this facility yet.',
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: facility.walls.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final wall = facility.walls[i];
                            return _WallTile(wall: wall);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WallTile extends StatelessWidget {
  final IndoorWallSummary wall;

  const _WallTile({required this.wall});

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'BEGINNER':
        return Colors.green;
      case 'INTERMEDIATE':
        return Colors.amber;
      case 'ADVANCED':
        return Colors.orange;
      case 'EXPERT':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openWallDetails(BuildContext context) async {
    final Wall? full = await ApiService().getWallById(wall.id);
    if (full == null || !context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => WallDetailsDialog(wall: full),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = wall.status == 'OPEN';

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _difficultyColor(wall.difficulty),
          child: const Icon(Icons.route, color: Colors.white, size: 18),
        ),
        title: Text(wall.name),
        subtitle: Row(
          children: [
            Text(wall.difficulty),
            const SizedBox(width: 8),
            if (!isOpen)
              Chip(
                label: Text(
                  wall.status.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.orange.shade100,
              ),
          ],
        ),
        trailing: wall.rating > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 2),
                  Text(
                    wall.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              )
            : null,
        onTap: () => _openWallDetails(context),
      ),
    );
  }
}
