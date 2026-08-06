import 'package:flutter/material.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/presentation/notification_format.dart';

/// A single notification in the inbox — a **subject-led two-line row**: a type
/// glyph, a small event kicker with the age in the right corner, and the
/// **subject** on the line beneath.
///
/// ## Why the subject leads (2026-08-01, second pass)
///
/// Every producer — `NotifyTaskEvent` and the `functions/index.js` mirrors
/// alike — writes the **event type** into `title` ("New Task Assigned") and the
/// **thing it is about** into `body` ("Fridge check • Due today 2:59 PM").
/// Rendering `title` as the headline therefore made the loudest line on the card
/// the one line *guaranteed to repeat*: three assigned tasks were three
/// identical bold headings, and the only text that told them apart sat in 12px
/// grey underneath. Owner, correctly: *"all the tasks look the same."*
///
/// So the row is inverted. `body` — the subject — is the headline, and `title`
/// becomes a small uppercase **kicker** above it. Nothing is discarded and no
/// stored data changes (`title` is a pure function of `type` in every producer,
/// so it was always a label, never content). The kicker also carries the
/// semantic accent, which is how the deleted category pill's *meaning* comes
/// back at a quarter of its visual weight.
///
/// **Read/unread is carried by brightness, not by a lone dot.** An unread
/// notification wears an accent-tinted glyph, a white subject and a live dot; a
/// read one goes quiet — a flat glyph, a grey subject, no dot. The eye ranks the
/// list before it reads a word. Strictly monochrome except the semantic accent
/// (rework · rejected · approved · emergency · overdue), and a **critical unread**
/// item additionally carries the card's soft semantic halo.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.navigable = true,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;

  /// Whether tapping this notification opens somewhere (resolved by the screen
  /// via `resolveNotificationRoute`). When it does **not** — an employee's
  /// broadcast, say — the inbox is the notification's only surface, so the body
  /// is shown in full instead of being clamped to two lines. Tapping still
  /// marks it read.
  final bool navigable;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentFor(notification.type);
    // A critical notification (overdue · emergency · a swap awaiting approval)
    // that has not been seen yet earns the card's soft semantic halo. Once read
    // the halo goes — emphasis marks the unseen, never the status forever.
    final critical =
        notificationPriority(notification.type) == NotificationPriority.critical;
    final parts = splitNotificationBody(notification.body);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
        elevated: unread,
        glow: critical && unread ? accent : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Glyph(
              icon: _iconFor(notification.type),
              accent: accent,
              lit: unread,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KickerRow(
                    label: notification.title,
                    createdAt: notification.createdAt,
                    unread: unread,
                    // The kicker is tinted only when the type carries a semantic
                    // accent (approved · rejected · overdue · rework …). A
                    // neutral type keeps the grey ramp, so colour still means
                    // something when it appears.
                    accent: accent == AppColors.primary ? null : accent,
                  ),
                  const SizedBox(height: 2),
                  // The subject holds ONE line and never wraps: a wrapped
                  // headline makes every card a different height and the column
                  // reads ragged. Its trailing context drops to the line below,
                  // where it can be smaller and quieter.
                  //
                  // A row with nowhere to go is the exception — it is not a
                  // pointer to the message, it IS the message — so it is set as
                  // reading text (lighter, looser, multi-line) rather than as a
                  // headline that happens to be three lines long.
                  Text(
                    parts.subject,
                    style: navigable
                        ? AppTypography.label.copyWith(
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w500,
                            color: unread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          )
                        : AppTypography.body.copyWith(
                            fontSize: 13.5,
                            height: 1.45,
                            color: unread
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                          ),
                    maxLines: navigable ? 1 : null,
                    overflow: navigable ? TextOverflow.ellipsis : null,
                  ),
                  if (parts.context != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      parts.context!,
                      style: AppTypography.bodySmall.copyWith(
                        height: 1.35,
                        color: unread
                            ? AppColors.textTertiary
                            : AppColors.textQuaternary,
                      ),
                      maxLines: navigable ? 2 : null,
                      overflow: navigable ? TextOverflow.ellipsis : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Icons.assignment_outlined;
      case NotificationType.taskRework:
        return Icons.replay_rounded;
      case NotificationType.taskSubmitted:
        return Icons.upload_file_outlined;
      case NotificationType.taskApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.taskRejected:
        return Icons.cancel_outlined;
      case NotificationType.taskCancelled:
        return Icons.block_rounded;
      case NotificationType.taskMissed:
        return Icons.event_busy_rounded;
      case NotificationType.taskReportedIncorrect:
        return Icons.flag_outlined;
      case NotificationType.taskReminder:
        return Icons.alarm_rounded;
      case NotificationType.taskOverdue:
        return Icons.running_with_errors_rounded;
      case NotificationType.broadcastEmergency:
        return Icons.warning_amber_rounded;
      case NotificationType.broadcastReminder:
        return Icons.alarm_outlined;
      case NotificationType.broadcastAnnouncement:
        return Icons.campaign_outlined;
      case NotificationType.swapRequested:
      case NotificationType.swapAccepted:
        return Icons.swap_horiz_rounded;
      case NotificationType.swapApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.swapRejected:
        return Icons.cancel_outlined;
      case NotificationType.caseOpened:
        return Icons.flag_outlined;
      case NotificationType.caseUpdated:
        return Icons.forum_outlined;
      case NotificationType.caseClosed:
        return Icons.check_circle_outline_rounded;
      case NotificationType.caseReplied:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.requestSubmitted:
        return Icons.approval_outlined;
      case NotificationType.requestApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.requestRejected:
        return Icons.cancel_outlined;
      case NotificationType.requestCompleted:
        return Icons.task_alt_rounded;
      case NotificationType.requestCancelled:
        return Icons.block_rounded;
      case NotificationType.requestCommented:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.attendanceCorrectionFiled:
        return Icons.more_time_rounded;
      case NotificationType.attendanceCorrectionApproved:
        return Icons.check_circle_outline_rounded;
      case NotificationType.attendanceCorrectionRejected:
        return Icons.cancel_outlined;
      case NotificationType.attendanceAutoClosed:
        return Icons.timer_off_outlined;
      case NotificationType.salesSubmission:
        return Icons.point_of_sale_outlined;
    }
  }

  Color _accentFor(NotificationType type) {
    switch (type) {
      case NotificationType.taskApproved:
      case NotificationType.swapApproved:
      case NotificationType.attendanceCorrectionApproved:
        return AppColors.success;
      case NotificationType.taskRejected:
      case NotificationType.taskOverdue:
      case NotificationType.taskMissed:
      case NotificationType.broadcastEmergency:
      case NotificationType.swapRejected:
      case NotificationType.attendanceCorrectionRejected:
        return AppColors.error;
      case NotificationType.taskRework:
      case NotificationType.taskReminder:
      case NotificationType.broadcastReminder:
      case NotificationType.swapAccepted:
      case NotificationType.attendanceAutoClosed:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

/// The type glyph. **Lit** (unread) it carries a tint of the semantic accent —
/// a wash, a hairline and a coloured icon. **Unlit** (read) it recedes to a
/// flat inset square with a grey icon, so a read row never competes with a
/// live one. `AppColors.primary` is white, so a neutral unread glyph reads as a
/// clean white-on-dark chip and the monochrome rule holds.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.icon, required this.accent, required this.lit});

  final IconData icon;
  final Color accent;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: lit ? accent.withAlpha(28) : AppColors.darkBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: lit ? accent.withAlpha(64) : AppColors.darkBorder,
        ),
      ),
      child: Icon(
        icon,
        size: 19,
        color: lit ? accent : AppColors.textTertiary,
      ),
    );
  }
}

/// The meta line above the subject: the **event kicker** on the left, the age in
/// the right corner, the unread dot last. Small uppercase with wide tracking —
/// it labels the row without competing with it, which is exactly what the old
/// coloured category pill failed to do. The dot and the time keep fixed slots so
/// a row never reflows when it is marked read.
class _KickerRow extends StatelessWidget {
  const _KickerRow({
    required this.label,
    required this.createdAt,
    required this.unread,
    required this.accent,
  });

  final String label;
  final DateTime createdAt;
  final bool unread;

  /// The type's semantic colour, or null for a neutral type (grey ramp).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    // A read row drops to the faintest step of the ramp — including a semantic
    // one, so yesterday's red does not shout as loudly as this morning's.
    final kickerColor = unread
        ? (accent ?? AppColors.textTertiary)
        : AppColors.textQuaternary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: kickerColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          AppDateFormatter.relativeShort(createdAt),
          style: AppTypography.caption.copyWith(
            fontSize: 10.5,
            color: unread ? AppColors.textTertiary : AppColors.textQuaternary,
          ),
        ),
        // Unread dot — fades out when the notification is read (§5c motion);
        // keeps its slot so the meta line never reflows.
        SizedBox(
          width: 14,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedOpacity(
              opacity: unread ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              // Always the plain accent-white: the dot means "unread" and
              // nothing else. The kicker already carries the semantic colour,
              // and double-encoding it here would make the unread signal
              // change meaning per type.
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
