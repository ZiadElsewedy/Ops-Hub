import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_schedule_entity.dart';

part 'broadcast_schedule_state.freezed.dart';

@freezed
class BroadcastScheduleState with _$BroadcastScheduleState {
  const factory BroadcastScheduleState.initial() = _Initial;
  const factory BroadcastScheduleState.loading() = _Loading;
  const factory BroadcastScheduleState.loaded(
    List<BroadcastScheduleEntity> schedules, {
    @Default(false) bool busy,
  }) = _Loaded;
  const factory BroadcastScheduleState.error(String message) = _Error;
}
