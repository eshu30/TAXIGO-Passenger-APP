// lib/widgets/stat_card.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              fontSize: 20,
            ),
          ),
          Text(
            title,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}