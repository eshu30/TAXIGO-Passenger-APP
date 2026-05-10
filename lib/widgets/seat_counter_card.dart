// lib/widgets/seat_counter_card.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class SeatCounterCard extends StatelessWidget {
  final int availableSeats;
  final ValueChanged<int> onSeatsChanged;

  const SeatCounterCard({
    Key? key,
    required this.availableSeats,
    required this.onSeatsChanged,
  }) : super(key: key);

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Seats',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Seats: $availableSeats',
                style: AppTextStyles.bodyMedium,
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: availableSeats > 1 ? () {
                      onSeatsChanged(availableSeats - 1);
                    } : null,
                    icon: Icon(Icons.remove_circle_outline),
                    color: AppColors.errorRed,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryYellow,
                      borderRadius: BorderRadius.circular(AppSpacing.lg),
                    ),
                    child: Text(
                      '$availableSeats',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: availableSeats < 6 ? () {
                      onSeatsChanged(availableSeats + 1);
                    } : null,
                    icon: Icon(Icons.add_circle_outline),
                    color: AppColors.successGreen,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}