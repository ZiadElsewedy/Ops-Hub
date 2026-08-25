import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/widgets/skeleton.dart';

/// A shimmering placeholder list shown on first load of a card list (tasks,
/// admin users, branches) — mirrors the real card rhythm so the screen doesn't
/// jump when data arrives. Premium loading state (Phase 10), reusing [Skeleton].
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 5, this.cardHeight = 96});

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.lg,
          AppSpacing.pagePadding, AppSpacing.xxxl),
      itemCount: count,
      itemBuilder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Skeleton(
                      width: 40,
                      height: 40,
                      circle: true,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 140, height: 13),
                        SizedBox(height: 8),
                        Skeleton(width: 90, height: 11),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Skeleton(width: 180, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
