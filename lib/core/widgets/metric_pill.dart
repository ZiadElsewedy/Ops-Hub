import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_typography.dart';

/// **MetricPill** — a compact, glanceable `[icon] value · label` chip for
/// surfacing a single number inline (e.g. "3 Reviews", "1 Overdue"). The small
/// sibling of `DashboardMetricCard`, for headers / summaries / card footers
/// where a full metric card is too heavy.
///
/// Monochrome by default; pass [tone] for a subtle semantic accent (e.g.
/// `AppColors.error` for overdue) — only the icon + value pick it up, the pill
/// surface stays greyscale, in keeping with the strictly-monochrome system.
class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.tone,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// Optional semantic accent for the icon + value (null = monochrome white).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: tone != null ? accent.withAlpha(60) : AppColors.darkBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: AppTypography.label.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
