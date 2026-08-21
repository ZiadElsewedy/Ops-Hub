import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/schedule/domain/shift_template.dart';

part 'shift_template_state.freezed.dart';

/// State for the shift-template manager (Schedule V2 · Pillar 5).
@freezed
class ShiftTemplateState with _$ShiftTemplateState {
  const factory ShiftTemplateState.initial() = _Initial;
  const factory ShiftTemplateState.loading() = _Loading;
  const factory ShiftTemplateState.loaded(
    ShiftTemplateSet set, {
    @Default(false) bool busy,
  }) = _Loaded;
  const factory ShiftTemplateState.error(String message) = _Error;
}
