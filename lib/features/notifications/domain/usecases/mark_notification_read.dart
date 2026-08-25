import 'package:opshub/features/notifications/domain/repositories/notification_repository.dart';

/// Marks a single notification read.
class MarkNotificationRead {
  final NotificationRepository _repository;
  const MarkNotificationRead(this._repository);

  Future<void> call(String id) => _repository.markRead(id);
}
