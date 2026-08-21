import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/schedule/domain/entities/shift_swap_entity.dart';

part 'shift_swap_state.freezed.dart';

@freezed
class ShiftSwapState with _$ShiftSwapState {
  const factory ShiftSwapState.initial() = _Initial;
  const factory ShiftSwapState.loading() = _Loading;

  /// Swap requests loaded (employee's own, or a branch's queue). [busy] marks an
  /// in-flight approve/reject/create while the list stays visible.
  const factory ShiftSwapState.loaded(
    List<ShiftSwapEntity> swaps, {
    @Default(false) bool busy,
  }) = _Loaded;

  /// Transient — surfaced as a snackbar; the cubit re-emits the last list.
  const factory ShiftSwapState.error(String message) = _Error;
}
