import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_entity.dart';

part 'broadcast_state.freezed.dart';

@freezed
class BroadcastState with _$BroadcastState {
  const factory BroadcastState.initial() = _Initial;
  const factory BroadcastState.loading() = _Loading;

  /// The live broadcast feed. [sending] is true while a new broadcast is being
  /// persisted (the existing list stays visible).
  const factory BroadcastState.loaded(
    List<BroadcastEntity> broadcasts, {
    @Default(false) bool sending,
  }) = _Loaded;

  const factory BroadcastState.error(String message) = _Error;
}
