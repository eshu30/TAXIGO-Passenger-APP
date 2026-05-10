// lib/widgets/status_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';

class StatusCard extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const StatusCard({
    Key? key,
    required this.isOnline,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(AppSpacing.lg),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: isOnline ? AppColors.successGreen : AppColors.borderGrey,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.successGreen : Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      isOnline ? 'You are Online' : 'You are Offline',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOnline ? AppColors.successGreen : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: EdgeInsets.only(left: AppSpacing.lg),
                  child: Text(
                    isOnline ? 'Ready to accept rides' : 'Go online to start earning',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: (value) {
              // Add haptic feedback
              HapticFeedback.lightImpact();
              onToggle(value);
            },
            activeColor: AppColors.successGreen,
            activeTrackColor: AppColors.successGreen.withOpacity(0.3),
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}