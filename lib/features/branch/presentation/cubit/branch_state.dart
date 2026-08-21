import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';

part 'branch_state.freezed.dart';

@freezed
class BranchState with _$BranchState {
  const factory BranchState.initial() = _Initial;
  const factory BranchState.loading() = _Loading;
  const factory BranchState.loaded(
    List<BranchEntity> branches, {
    @Default(false) bool busy,
  }) = _Loaded;
  const factory BranchState.error(String message) = _Error;
}
