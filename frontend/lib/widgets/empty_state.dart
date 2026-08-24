import 'package:flutter/material.dart';
import '../utils/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.secondaryText(context).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 15)),
        ],
      ),
    );
  }
}
