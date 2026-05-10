// lib/widgets/custom_input_field.dart
import 'package:flutter/material.dart';
import '../constants.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? hintText;

  const CustomInputField({
    Key? key,
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.hintText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderGrey),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hintText ?? 'Enter $label',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
      ],
    );
  }
}