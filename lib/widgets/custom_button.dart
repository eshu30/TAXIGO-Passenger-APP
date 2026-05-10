// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height ?? AppDimensions.largeButtonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primaryYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.circular),
          ),
          elevation: AppDimensions.cardElevation,
        ),
        child: isLoading
            ? CircularProgressIndicator(
                color: textColor ?? AppColors.textDark,
                strokeWidth: 2,
              )
            : Text(
                text,
                style: AppTextStyles.buttonText.copyWith(
                  color: textColor ?? AppColors.textDark,
                ),
              ),
      ),
    );
  }
}