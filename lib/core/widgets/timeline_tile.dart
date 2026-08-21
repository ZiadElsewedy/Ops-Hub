import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// A single row in a vertical timeline — a coloured dot connected by a spine to
/// the next row, with a title, a trailing timestamp, an optional subtitle
/// (actor) and an optional note. Rendered purely from data, so a caller can
/// build a timeline of any length / shape (missing steps, rework loops, …)
/// without hardcoding the sequence.
///
/// Shared by the task **activity timeline** (Task Details) and the admin
/// **recent activity feed** so both read from one component.
class TimelineTile extends StatelessWidget {
  const TimelineTile({
    super.key,
    required this.title,
    this.titleColor,
    this.time,
    this.subtitle,
    this.note,
    this.dotColor,
    this.isLast = false,
  });

  final String title;
  final Color? titleColor;

  /// Trailing relative/absolute timestamp (e.g. "5m ago", "19 Jun").
  final String? time;

  /// Secondary line under the title (typically the actor).
  final String? subtitle;

  /// Optional note (review reason, completion note, …).
  final String? note;
  final Color? dotColor;

  /// When true, the connecting spine below the dot is omitted.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dot = dotColor ?? AppColors.textTertiary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine: a haloed status dot + (unless last) the spine line.
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: dot.withAlpha(40)),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: dot),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.darkBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          // Content.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.label
                              .copyWith(color: titleColor ?? AppColors.textPrimary),
                        ),
                      ),
                      if (time != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(time!, style: AppTypography.caption),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppTypography.bodySmall),
                  ],
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Text(
                        note!,
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
