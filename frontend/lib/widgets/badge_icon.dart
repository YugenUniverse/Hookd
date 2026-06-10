import 'package:flutter/material.dart';

class BadgeIcon extends StatelessWidget {
  final String name;
  final String? description;
  final int level;
  final String iconStr;

  const BadgeIcon({
    Key? key,
    required this.name,
    this.description,
    required this.level,
    required this.iconStr,
  }) : super(key: key);

  IconData _getIconData() {
    final str = iconStr.toLowerCase();
    
    // Custom Event Badges
    if (str == 'trophy') return Icons.emoji_events;
    if (str == 'medal') return Icons.workspace_premium;
    if (str == 'star') return Icons.star;
    if (str == 'flash') return Icons.flash_on;
    if (str == 'mountain') return Icons.terrain;

    // System Badges
    if (str.contains('first_ascent')) return Icons.star;
    if (str.contains('century_club')) return Icons.workspace_premium;
    if (str.contains('weekend_warrior')) return Icons.weekend;
    if (str.contains('super_climber')) return Icons.flash_on;
    if (str.contains('dedicated')) return Icons.link; // Closest default to carabiner
    if (str.contains('streak')) return Icons.local_fire_department;

    return Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color iconColor;
    Color shadowColor;
    Color borderColor;
    double blurRadius;
    double spreadRadius;

    switch (level) {
      case 1:
        bgColor = isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50;
        iconColor = Colors.amber.shade400;
        borderColor = Colors.amber.shade400;
        shadowColor = Colors.amber.withOpacity(0.4);
        blurRadius = 12;
        spreadRadius = 2;
        break;
      case 2:
        bgColor = isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blueGrey.shade50;
        iconColor = Colors.blueGrey.shade300;
        borderColor = Colors.blueGrey.shade300;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
        break;
      case 3:
        bgColor = isDark ? Colors.deepOrange.withOpacity(0.15) : Colors.orange.shade50;
        iconColor = Colors.deepOrange.shade300;
        borderColor = Colors.deepOrange.shade300;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
        break;
      default:
        // Use primary color theme for standard/system earned badges instead of grey
        bgColor = isDark ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.primary.withOpacity(0.1);
        iconColor = Theme.of(context).colorScheme.primary;
        borderColor = Colors.transparent;
        shadowColor = Colors.transparent;
        blurRadius = 0;
        spreadRadius = 0;
    }

    final message = description != null && description!.isNotEmpty 
      ? '$name\n${description!}'.trim()
      : name;

    return Tooltip(
      message: message,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: borderColor != Colors.transparent
              ? Border.all(color: borderColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: blurRadius,
              spreadRadius: spreadRadius,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(_getIconData(), size: 28, color: iconColor),
      ),
    );
  }
}
