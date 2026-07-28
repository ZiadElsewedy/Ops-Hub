import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_date_formatter.dart';

/// Presentation helpers that map a task [ActivityEntry.status] string onto a
/// human label + dot colour, and format an event time. Shared by the Task
/// Details activity timeline and the admin recent-activity feed so the mapping
/// lives in exactly one place.

/// The soft per-state palette — muted, premium, no neon — shared by the
/// living-border orbit (task cards), the activity timeline and the activity
/// feed dots so a state always wears the same colour everywhere.
const Color kStatePending = Color(0xFF7DD3FC); // baby blue
const Color kStateInProgress = Color(0xFFA78BFA); // purple
const Color kStateInReview = Color(0xFFF59E0B); // amber
const Color kStateRejected = Color(0xFFF87171); // soft red
const Color kStateOverdue = Color(0xFFFB923C); // orange

/// Human-readable title for a task activity entry (its post-transition status).
String activityTitle(String status) => switch (status) {
  'pending' => 'Task created',
  'assigned' => 'Assigned to employee',
  'started' => 'Started',
  'completed' => 'Completed',
  'waitingReview' => 'Submitted for review',
  'approved' => 'Approved',
  'rejected' => 'Rework requested',
  'missed' => 'Missed deadline',
  'cancelled' => 'Cancelled',
  'reportedIncorrect' => 'Reported as incorrect',
  'reportDismissed' => 'Report dismissed',
  'terminalCorrected' => 'Reopened by admin',
  'note' => 'Note',
  'noteWarning' => 'Warning',
  'noteIssue' => 'Issue',
  _ => status,
};

/// Dot / accent colour for a task activity entry — the soft state palette, so
/// the timeline reads in the same hues as the cards' living borders.
Color activityColor(String status) => switch (status) {
  'approved' => AppColors.success,
  'rejected' || 'missed' || 'noteIssue' => kStateRejected,
  // A report is a raised hand, not a fault — amber like the other "someone
  // needs to look at this" events. A cancellation stays neutral grey (it is
  // neither success nor failure), which `_` already gives it.
  'reportedIncorrect' || 'waitingReview' || 'noteWarning' => kStateInReview,
  'started' => kStateInProgress,
  'pending' || 'assigned' => kStatePending,
  'completed' => AppColors.textSecondary,
  _ => AppColors.textTertiary,
};

/// Glyph for a task activity entry — used by the richer timeline event cards.
IconData activityIcon(String status) => switch (status) {
  'pending' => Icons.add_task_rounded,
  'assigned' => Icons.person_add_alt_1_rounded,
  'started' => Icons.play_arrow_rounded,
  'completed' => Icons.check_rounded,
  'waitingReview' => Icons.hourglass_top_rounded,
  'approved' => Icons.verified_rounded,
  'rejected' => Icons.replay_rounded,
  'missed' => Icons.event_busy_rounded,
  'cancelled' => Icons.block_rounded,
  'reportedIncorrect' => Icons.flag_outlined,
  'reportDismissed' => Icons.flag_rounded,
  'terminalCorrected' => Icons.lock_open_rounded,
  'note' => Icons.chat_bubble_outline_rounded,
  'noteWarning' => Icons.warning_amber_rounded,
  'noteIssue' => Icons.report_gmailerrorred_rounded,
  _ => Icons.circle_outlined,
};

/// Compact relative time ("Just now", "5m ago", "3h ago", "2d ago", "19 Jun").
/// Delegates to the single [AppDateFormatter]; kept as a task-timeline alias so
/// existing call sites (and the cases inbox that reuses it) stay unchanged.
String relativeTime(DateTime dt) => AppDateFormatter.relative(dt);

/// Wall-clock time ("1:43 AM") — pairs with [relativeTime] on timeline rows so
/// ops can see the exact moment, not just "2m ago".
String clockTime(DateTime dt) => AppDateFormatter.time(dt);
