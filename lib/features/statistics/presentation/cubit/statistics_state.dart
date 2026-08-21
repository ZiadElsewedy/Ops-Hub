import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/statistics/domain/entities/statistics_entity.dart';

part 'statistics_state.freezed.dart';

@freezed
class StatisticsState with _$StatisticsState {
  const factory StatisticsState.initial() = _Initial;
  const factory StatisticsState.loading() = _Loading;
  const factory StatisticsState.loaded(StatisticsEntity stats) = _Loaded;
  const factory StatisticsState.error(String message) = _Error;
}
