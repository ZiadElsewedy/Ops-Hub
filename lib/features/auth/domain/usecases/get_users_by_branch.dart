import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/domain/repositories/auth_repository.dart';

/// Lists the users belonging to a branch — used by managers/admins to pick a
/// task assignee. Security rules limit a manager to their own branch.
class GetUsersByBranch {
  final AuthRepository _repository;
  const GetUsersByBranch(this._repository);

  Future<List<UserEntity>> call(String branchId) =>
      _repository.getUsersByBranch(branchId);
}
