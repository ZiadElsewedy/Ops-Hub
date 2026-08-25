import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';

/// The grab handle at the top of a modal bottom sheet — centralised so every
/// schedule sheet (shift details, picker, swap queue, resolve) looks identical.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: const BoxDecoration(
          color: AppColors.darkBorder,
          borderRadius: AppRadius.fullAll,
        ),
      ),
    );
  }
}
