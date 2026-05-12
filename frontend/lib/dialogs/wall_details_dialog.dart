import 'package:flutter/material.dart';
import '../models/wall.dart';

class WallDetailsDialog extends StatelessWidget {
  final Wall wall;

  const WallDetailsDialog({super.key, required this.wall});

  @override
  Widget build(BuildContext context) {
    // Determine the icon and color based on the wall type
    final bool isIndoor = wall.wallType == 'IndoorWall';
    final IconData typeIcon = isIndoor ? Icons.domain : Icons.landscape;
    final Color typeColor = isIndoor ? Colors.blueGrey : Colors.green;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(typeIcon, color: typeColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wall.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            _buildInfoRow(Icons.fitness_center, 'Difficulty', wall.difficulty),
            const SizedBox(height: 12),

            // Owner Info
            _buildInfoRow(
              isIndoor ? Icons.business : Icons.account_balance,
              'Managed By',
              wall.ownerName ?? 'Unknown',
            ),
            const SizedBox(height: 12),

            // Session Count Info
            _buildInfoRow(
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
            Text(wall.description, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Closes the dialog
          child: const Text('Close'),
        ),
      ],
    );
  }

  // A helper widget to keep the code clean for rows with icons and text
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
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
