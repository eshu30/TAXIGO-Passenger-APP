// lib/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class CustomAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primaryYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.xl),
          bottomRight: Radius.circular(AppSpacing.xl),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            width: AppDimensions.logoWidth,
            height: AppDimensions.logoHeight,
            child: Image.asset(
              'assets/taxigo_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}