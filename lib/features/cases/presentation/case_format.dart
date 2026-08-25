import 'package:flutter/material.dart';
import 'package:opshub/core/enums/case_category.dart';
import 'package:opshub/core/enums/case_status.dart';
import 'package:opshub/core/theme/app_colors.dart';

/// Shared, **pure** presentation helpers for Case Management — the single source
/// for a category glyph, a status colour, and the system-message markers.
/// Strictly monochrome: colour appears only for an urgent case, the In
/// Discussion / Waiting states, and a closed case.

// ─── Category ───────────────────────────────────────────────────────
IconData caseCategoryIcon(CaseCategory c) => switch (c) {
      CaseCategory.sales => Icons.point_of_sale_outlined,
      CaseCategory.inventory => Icons.inventory_2_outlined,
      CaseCategory.staff => Icons.groups_2_outlined,
      CaseCategory.security => Icons.shield_outlined,
      CaseCategory.operations => Icons.storefront_outlined,
      CaseCategory.personal => Icons.person_outline_rounded,
    };

// ─── Status ─────────────────────────────────────────────────────────
Color caseStatusColor(CaseStatus s) => switch (s) {
      CaseStatus.open => AppColors.primary,
      CaseStatus.inDiscussion => AppColors.warning,
      CaseStatus.waitingResponse => AppColors.textSecondary,
      CaseStatus.closed => AppColors.success,
    };

IconData caseStatusIcon(CaseStatus s) => switch (s) {
      CaseStatus.open => Icons.flag_outlined,
      CaseStatus.inDiscussion => Icons.forum_outlined,
      CaseStatus.waitingResponse => Icons.hourglass_bottom_rounded,
      CaseStatus.closed => Icons.check_circle_outline_rounded,
    };

// ─── System messages (status changes shown inline in the conversation) ─
// [status] is the raw `systemEvent` value (a [CaseStatus.value]).
String caseSystemLabel(String status) => switch (status) {
      'open' => 'Case reopened',
      'inDiscussion' => 'Marked In Discussion',
      'waitingResponse' => 'Waiting for a response',
      'closed' => 'Case closed',
      _ => 'Status updated',
    };

Color caseSystemColor(String status) => switch (status) {
      'closed' => AppColors.success,
      'inDiscussion' => AppColors.warning,
      _ => AppColors.textTertiary,
    };

IconData caseSystemIcon(String status) => switch (status) {
      'open' => Icons.refresh_rounded,
      'inDiscussion' => Icons.forum_outlined,
      'waitingResponse' => Icons.hourglass_bottom_rounded,
      'closed' => Icons.check_circle_outline_rounded,
      _ => Icons.circle_outlined,
    };
