import 'package:flutter/material.dart';
import 'package:opshub/core/enums/broadcast_audience.dart';
import 'package:opshub/core/enums/broadcast_category.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';

/// Shared presentation formatting for the Communications Center — keeps the
/// label / icon / colour mapping (and the monochrome "colour only for status"
/// rule) in one place, out of the pure `core/enums` values.

/// Compact relative time ("just now", "5m", "3h", "2d") then an absolute date.
String broadcastTimeAgo(DateTime? dt) {
  if (dt == null) return 'just now';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return AppDateFormatter.dayMonthYear(dt);
}

/// Longer, human date for the detail screen ("21 Jun 2026 • 4:59 PM").
String broadcastFullDate(DateTime? dt) =>
    dt == null ? '—' : AppDateFormatter.dayMonthYearTime(dt);

/// The audience label for a feed/detail chip ("Everyone" / "Branch" / "Direct").
String audienceLabel(BroadcastEntity b) => switch (b.audience) {
      BroadcastAudience.allBranches => 'Everyone',
      BroadcastAudience.branch => 'Branch',
      BroadcastAudience.user => 'Direct',
      BroadcastAudience.custom => 'Selected',
    };

IconData audienceIcon(BroadcastAudience a) => switch (a) {
      BroadcastAudience.allBranches => Icons.public_rounded,
      BroadcastAudience.branch => Icons.store_mall_directory_outlined,
      BroadcastAudience.user => Icons.person_outline_rounded,
      BroadcastAudience.custom => Icons.groups_outlined,
    };

IconData categoryIcon(BroadcastCategory c) => switch (c) {
      BroadcastCategory.announcement => Icons.campaign_outlined,
      BroadcastCategory.reminder => Icons.alarm_rounded,
      BroadcastCategory.emergency => Icons.error_outline_rounded,
    };

/// Status colour for a category — monochrome by default; only the urgent
/// emergency category carries a semantic colour (→ error).
Color categoryColor(BroadcastCategory c) => switch (c) {
      BroadcastCategory.emergency => AppColors.error,
      _ => AppColors.textSecondary,
    };

/// Status label for a broadcast in the history feed.
String broadcastStatusLabel(BroadcastEntity b) {
  if (b.isArchived) return 'Archived';
  return 'Sent';
}
