import 'package:flutter/material.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';

/// Presentation-only formatting for Operations Requests — icons, the single
/// status→colour source, and relative time. Kept out of the domain so the enums
/// stay Flutter-free (mirrors `activity_format.dart` for tasks).
class RequestFormat {
  const RequestFormat._();

  // ─── Type icon (the request category glyph) ────────────────────
  static IconData icon(RequestType type) => switch (type) {
        RequestType.employeeDiscount => Icons.sell_outlined,
        RequestType.leaveStore => Icons.directions_walk_rounded,
        RequestType.giftApproval => Icons.card_giftcard_rounded,
        RequestType.stockRequest => Icons.inventory_2_outlined,
        RequestType.maintenance => Icons.build_outlined,
        RequestType.customerIssue => Icons.report_gmailerrorred_outlined,
        RequestType.cashRequest => Icons.payments_outlined,
        RequestType.equipmentRequest => Icons.handyman_outlined,
        RequestType.branchSupport => Icons.hub_outlined,
        RequestType.other => Icons.more_horiz_rounded,
      };

  // ─── Status → colour (the ONE source, like taskStatusColor) ────
  static Color statusColor(RequestStatus status) => switch (status) {
        RequestStatus.pending => AppColors.warning, // awaiting a decision
        RequestStatus.approved => AppColors.success, // granted
        RequestStatus.rejected => AppColors.error,
      };

  static IconData statusIcon(RequestStatus status) => switch (status) {
        RequestStatus.pending => Icons.hourglass_top_rounded,
        RequestStatus.approved => Icons.check_circle_outline_rounded,
        RequestStatus.rejected => Icons.cancel_outlined,
      };

  // ─── Relative time ("2m", "3h", "Yesterday", "6 Jul") ──────────
  // (Its own wording — "now"/"Yesterday", no "ago" — differs from the shared
  // [AppDateFormatter.relative]; only the absolute-date fallback is shared.)
  static String relativeTime(DateTime? time, {DateTime? now}) {
    if (time == null) return '';
    final clock = now ?? DateTime.now();
    final diff = clock.difference(time);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return AppDateFormatter.dayMonth(time);
  }

  /// A longer age label for a pending request's "waiting" hint.
  static String waitingLabel(Duration d) {
    if (d.inMinutes < 60) return 'Waiting ${d.inMinutes}m';
    if (d.inHours < 24) return 'Waiting ${d.inHours}h';
    return 'Waiting ${d.inDays}d';
  }

  /// A precise "6 Jul · 4:30 PM" stamp for the detail header.
  static String fullStamp(DateTime? d) => d == null
      ? ''
      : '${AppDateFormatter.dayMonth(d)} · ${AppDateFormatter.time(d)}';
}
