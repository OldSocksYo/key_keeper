import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';

class AccountIcon extends StatelessWidget {
  const AccountIcon({super.key, required this.typeText, this.size = 20});

  final String typeText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = typeText.trim();
    final icon = AppConstants.iconMap[normalized.toLowerCase()];
    if (icon != null) {
      return Icon(icon, size: size);
    }
    if (normalized.isEmpty || normalized.toLowerCase() == 'default') {
      return Icon(Icons.account_circle, size: size);
    }

    final label = _buildShortLabel(normalized);
    final textTheme = Theme.of(context).textTheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontSize: size * 0.38,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _buildShortLabel(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return '?';
    final points = compact.runes.take(2).toList();
    return String.fromCharCodes(points).toUpperCase();
  }
}
