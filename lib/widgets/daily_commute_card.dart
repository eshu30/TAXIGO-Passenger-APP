import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/daily_route.dart';

class DailyCommuteCard extends StatelessWidget {
  final DailyRoute dailyRoute;
  final VoidCallback onEdit;

  const DailyCommuteCard({
    Key? key,
    required this.dailyRoute,
    required this.onEdit,
  }) : super(key: key);

  String _formatDays(List<String> days) {
    if (days.isEmpty) return 'No days selected';
    if (days.length == 7) return 'Daily';
    if (days.length == 5 &&
        days.contains('Monday') &&
        days.contains('Tuesday') &&
        days.contains('Wednesday') &&
        days.contains('Thursday') &&
        days.contains('Friday')) {
      return 'Weekdays';
    }
    if (days.length == 2 &&
        days.contains('Saturday') &&
        days.contains('Sunday')) {
      return 'Weekends';
    }
    return days.map((day) => day.substring(0, 3)).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
        border: Border.all(
          color: AppColors.primaryYellow.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Icon(
                  Icons.commute,
                  color: AppColors.primaryYellow,
                  size: 20,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Commute',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dailyRoute.destinationName ?? 'No destination set',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit,
                  color: Colors.grey[600],
                  size: 20,
                ),
                tooltip: 'Edit commute details',
              ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          /// Pickup Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferred Pickup Points',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              // Fixed bullet points and null safety
              if (dailyRoute.preferredPickupNames.isNotEmpty)
                ...dailyRoute.preferredPickupNames.map((point) => Padding(
                      padding: EdgeInsets.only(left: AppSpacing.lg),
                      child: Text(
                        "• $point", // Fixed bullet character
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
              else
                Padding(
                  padding: EdgeInsets.only(left: AppSpacing.lg),
                  child: Text(
                    "• No pickup points set", // Fixed bullet character
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: AppSpacing.md),

          /// Commute Time & Days
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          dailyRoute.commuteTime.isNotEmpty 
                              ? dailyRoute.commuteTime 
                              : 'No time set',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[300],
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _formatDays(dailyRoute.operatingDays),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.md),

          /// Quick Action
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement find passengers logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Finding passengers...')),
                    );
                  },
                  icon: Icon(
                    Icons.people,
                    size: 16,
                    color: AppColors.primaryYellow,
                  ),
                  label: Text(
                    'Find Passengers',
                    style: TextStyle(
                      color: AppColors.primaryYellow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryYellow),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}