import 'package:flutter/material.dart';
import 'package:drop/core/enums/notification_type.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/widgets/app_glass_card.dart';
import 'package:drop/core/widgets/status_badge.dart';
import 'package:drop/features/notifications/domain/entities/notification_entity.dart';
import 'package:drop/features/notifications/presentation/notification_format.dart';

/// A single notification in the inbox — icon (tinted by type), title, body,
/// time-ago, and an unread dot. Strictly monochrome; semantic colour only for
/// the rework / rejected / approved / emergency / overdue accents. Tapping marks
/// it read + deep-links. Deliberately display-only (2026-06-23 simplification):
/// no per-tile menu / pin — the inbox uses swipe-to-delete instead.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final accent = _accentFor(notification.type);
    final (catLabel, catColor) = _category(notification.type);
    // A critical notification (overdue · emergency) gets a stronger unread
    // indicator — the dot picks up its semantic accent and grows a touch. Subtle,
    // still monochrome elsewhere.
    final critical =
        notificationPriority(notification.type) == NotificationPriority.critical;
    final dotColor = critical ? accent : AppColors.primary;
    final dotSize = critical ? 10.0 : 8.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        elevated: unread,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble — tinted by the notification's semantic accent.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withAlpha(28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Icon(_iconFor(notification.type), size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTypography.label.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Unread dot — fades out when the notification is read
                      // (§5c motion); keeps its slot so the title never reflows.
                      Padding(
                        padding: const EdgeInsets.only(left: 6, top: 4),
                        child: AnimatedOpacity(
                          opacity: unread ? 1 : 0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Category badge + relative time.
                  Row(
                    children: [
                      StatusBadge(label: catLabel, color: catColor),
                      const SizedBox(width: AppSpacing.sm),
                      Text(AppDateFormatter.relative(notification.createdAt),
                          style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The notification's category badge — Task · Review · Reminder · Broadcast.
  /// Monochrome for the neutral kinds; a semantic tint only where it carries
  /// meaning (a review outcome, a reminder, an emergency).
  (String, Color) _category(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return ('Task', AppColors.textSecondary);
      // A cancellation is a business decision, not a failure — it stays neutral
      // so it never reads like the Missed beside it (Automated Tasks spec §8).
      case NotificationType.taskCancelled:
        return ('Task', AppColors.textSecondary);
      case NotificationType.taskMissed:
        return ('Task', AppColors.error);
      case NotificationType.taskReportedIncorrect:
        return ('Task', AppColors.warning);
      case NotificationType.taskSubmitted:
      case NotificationType.taskApproved:
      case NotificationType.taskRejected:
      case NotificationType.taskRework:
        return ('Review', _accentFor(type));
      case NotificationType.taskReminder:
      case NotificationType.taskOverdue:
      case NotificationType.broadcastReminder:
        return ('Reminder', AppColors.warning);
      case NotificationType.broadcastEmergency:
        return ('Broadcast', AppColors.error);
      case NotificationType.broadcastAnnouncement:
        return ('Broadcast', AppColors.textSecondary);
      case NotificationType.swapRequested:
      case NotificationType.swapAccepted:
      case NotificationType.swapApproved:
      case NotificationType.swapRejected:
        return ('Schedule', _accentFor(type));
      case NotificationType.caseClosed:
        return ('Case', AppColors.success);
      case NotificationType.caseOpened:
      case NotificationType.caseUpdated:
      case NotificationType.caseReplied:
        return ('Case', AppColors.textSecondary);
      case NotificationType.requestApproved:
      case NotificationType.requestCompleted:
        return ('Request', AppColors.success);
      case NotificationType.requestRejected:
      case NotificationType.requestCancelled:
        return ('Request', AppColors.error);
      case NotificationType.requestSubmitted:
      case NotificationType.requestCommented:
        return ('Request', AppColors.textSecondary);
      case NotificationType.attendanceCorrectionApproved:
        return ('Attendance', AppColors.success);
      case NotificationType.attendanceCorrectionRejected:
        return ('Attendance', AppColors.error);
      case NotificationType.attendanceAutoClosed:
        return ('Attendance', AppColors.warning);
      case NotificationType.attendanceCorrectionFiled:
        return ('Attendance', AppColors.textSecondary);
    }
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
      case NotificationType.broadcastEmergency:
      case NotificationType.swapRejected:
      case NotificationType.attendanceCorrectionRejected:
        return AppColors.error;
      case NotificationType.taskRework:
      case NotificationType.taskReminder:
      case NotificationType.swapAccepted:
      case NotificationType.attendanceAutoClosed:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

}
