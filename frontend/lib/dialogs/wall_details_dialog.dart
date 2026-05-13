import 'package:flutter/material.dart';
import '../models/wall.dart';
import '../pages/log_session_page.dart';

class WallDetailsDialog extends StatelessWidget {
  final Wall wall;

  const WallDetailsDialog({super.key, required this.wall});

  @override
  Widget build(BuildContext context) {
    // Determine the icon and color based on the wall type
    final bool isIndoor = wall.wallType == 'IndoorWall';
    final IconData typeIcon = isIndoor ? Icons.domain : Icons.landscape;
    final Color typeColor = isIndoor ? Colors.blueGrey : Colors.green;

    return SafeArea(
      child: SizedBox(
        height: 500,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, color: typeColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wall.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Log session',
                    onPressed: () {
                      final rootContext = Navigator.of(context, rootNavigator: true).context;
                      Navigator.of(context).pop();
                      showModalBottomSheet(
                        context: rootContext,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => LogSessionPage(initialWall: wall),
                      );
                    },
                    icon: const Icon(Icons.edit_calendar_outlined),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wall Type Chip
                      Chip(
                        label: Text(
                          isIndoor ? 'Indoor Facility' : 'Outdoor Crag',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        backgroundColor: typeColor,
                      ),
                      const SizedBox(height: 16),

                      // Difficulty Info
                      _buildInfoRow(context, Icons.fitness_center, 'Difficulty', wall.difficulty),
                      const SizedBox(height: 12),

                      // Owner Info
                      _buildInfoRow(
                        context,
                        isIndoor ? Icons.business : Icons.account_balance,
                        'Managed By',
                        wall.ownerName ?? 'Unknown',
                      ),
                      const SizedBox(height: 12),

                      // Session Count Info
                      _buildInfoRow(
                        context,
                        Icons.history,
                        'Total Climbs',
                        '${wall.sessions.length} sessions logged',
                      ),
                      const SizedBox(height: 16),

                      // Description section
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(wall.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A helper widget to keep the code clean for rows with icons and text
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
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
}
