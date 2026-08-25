import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/notifications/domain/entities/notification_entity.dart';

part 'notification_state.freezed.dart';

@freezed
class NotificationState with _$NotificationState {
  const factory NotificationState.initial() = _Initial;
  const factory NotificationState.loading() = _Loading;

  /// The live notification feed, newest first.
  const factory NotificationState.loaded(
    List<NotificationEntity> notifications,
  ) = _Loaded;

  const factory NotificationState.error(String message) = _Error;
}
