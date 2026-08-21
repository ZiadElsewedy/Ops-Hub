import 'dart:developer' as developer;

import 'package:opshub/core/enums/notification_type.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';
import 'package:opshub/features/notifications/domain/notification_deep_link.dart';
import 'package:opshub/features/notifications/domain/repositories/notification_repository.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';

/// Builds + persists the in-app notification(s) for a **shift-swap** event,
/// reusing the existing notification pipeline (one `notifications/{id}` doc per
/// recipient; the deployed `onNotificationCreated` Cloud Function pushes FCM).
///
/// **Best-effort by design** — a notification failure must never affect the swap
/// write, so [call] never throws: errors are logged and swallowed. Mirrors
/// [NotifyTaskEvent].
class NotifySwapEvent {
  final NotificationRepository _repository;
  const NotifySwapEvent(this._repository);

  /// Emits [type] for [swap], triggered by [actorId] (the sender — excluded from
  /// [recipients] so an actor never notifies themselves).
  Future<void> call({
    required ShiftSwapEntity swap,
    required NotificationType type,
    required String actorId,
    required List<String> recipients,
  }) async {
    try {
      final cleaned = recipients
          .where((uid) => uid.isNotEmpty && uid != actorId)
          .toSet()
          .toList();
      if (cleaned.isEmpty) return;

      final title = _title(type);
      final body = _body(swap, type);
      final payload = {'swapId': swap.id, 'route': NotificationRoute.schedule};
      final now = DateTime.now();

      await _repository.createMany([
        for (final uid in cleaned)
          NotificationEntity(
            id: '',
            recipientUid: uid,
            senderUid: actorId,
            type: type,
            title: title,
            body: body,
            createdAt: now,
            payload: payload,
          ),
      ]);
    } catch (e, st) {
      developer.log('NotifySwapEvent failed for ${type.value}',
          name: 'notifications', error: e, stackTrace: st);
    }
  }

  String _title(NotificationType type) => switch (type) {
        NotificationType.swapRequested => 'Shift Swap Request',
        NotificationType.swapAccepted => 'Swap Needs Review',
        NotificationType.swapApproved => 'Swap Approved',
        NotificationType.swapRejected => 'Swap Declined',
        _ => 'Shift Swap',
      };

  String _body(ShiftSwapEntity swap, NotificationType type) {
    final day = swap.day.label;
    final shift = swap.shift.label;
    final requester = swap.requesterName ?? 'A coworker';
    final target = swap.targetName ?? 'a coworker';
    switch (type) {
      case NotificationType.swapRequested:
        return '$requester wants to swap their $day $shift shift with you.';
      case NotificationType.swapAccepted:
        return "$target accepted $requester's $day swap — it needs your review.";
      case NotificationType.swapApproved:
        return 'Your $day shift swap was approved — the schedule is updated.';
      case NotificationType.swapRejected:
        return 'Your $day shift swap was declined.';
      default:
        return '$day $shift swap';
    }
  }
}
