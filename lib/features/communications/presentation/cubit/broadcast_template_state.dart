import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/communications/domain/entities/broadcast_template_entity.dart';

part 'broadcast_template_state.freezed.dart';

@freezed
class BroadcastTemplateState with _$BroadcastTemplateState {
  const factory BroadcastTemplateState.initial() = _Initial;
  const factory BroadcastTemplateState.loading() = _Loading;
  const factory BroadcastTemplateState.loaded(
    List<BroadcastTemplateEntity> templates, {
    @Default(false) bool busy,
  }) = _Loaded;
  const factory BroadcastTemplateState.error(String message) = _Error;
}
