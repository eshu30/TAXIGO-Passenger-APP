// lib/constants.dart
import 'package:flutter/material.dart';

int finalFare = 0;

// Colors
class AppColors {
  static const Color primaryYellow = Color(0xFFF4D03F);
  static const Color textDark = Colors.black87;
  static const Color textLight = Colors.grey;
  static const Color white = Colors.white;
  static const Color cardShadow = Color(0x1A000000);
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color successGreen = Colors.green;
  static const Color errorRed = Colors.red;
  static const Color warningOrange = Colors.orange;
  static const Color infoBlue = Colors.blue;
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    color: AppColors.textDark,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    color: AppColors.textDark,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    color: AppColors.textLight,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );
}

// Spacing
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
}

// Border Radius
class AppBorderRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double circular = 25.0;
}

// App Dimensions
class AppDimensions {
  static const double buttonHeight = 50.0;
  static const double largeButtonHeight = 55.0;
  static const double inputHeight = 55.0;
  static const double logoWidth = 150.0;
  static const double logoHeight = 60.0;
  static const double profileImageRadius = 60.0;
  static const double cardElevation = 2.0;
}

// Animation Durations
class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splash = Duration(seconds: 2);
  static const Duration timeout = Duration(seconds: 3);
}
