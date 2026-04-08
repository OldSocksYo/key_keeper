import 'package:flutter/material.dart';
import 'package:key_keeper/common/constants.dart';

class AccountIcon extends StatelessWidget {
  const AccountIcon({super.key, required this.typeText, this.size = 20});

  final String typeText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = AppConstants.iconMap[typeText.trim().toLowerCase()] ?? Icons.account_circle;
    return Icon(icon, size: size);
  }
}
