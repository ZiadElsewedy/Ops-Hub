import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';

/// The set of people the caller may start a conversation with — the ONE source
/// of the chat directory, used by both the new-conversation picker and the
/// inbox's name/avatar resolution so the two can never disagree.
///
/// **Chat's access model is flat by design:** every authenticated user may
/// message every other active user. There is deliberately **no branch and no
/// role predicate** anywhere in this path — not in the query, not here, not in
/// the cubit, not in the UI. Chat is not org-scoped; a directory that mirrored
/// the branch hierarchy made admins (who are provisioned branchless, since the
/// role is global) unreachable in both directions.
///
/// The only filters are identity and account state:
/// - the caller is excluded (the server also rejects a self-conversation);
/// - deactivated accounts are hidden — `isActive` is the app-wide access gate,
///   and it is applied HERE rather than as a query predicate so that a legacy
///   document with no `isActive` field keeps [UserEntity]'s `true` default
///   instead of being silently dropped by an equality filter.
///
/// Sorted by display name so the picker order is stable.
class GetChatDirectory {
  final AuthRepository _repository;
  const GetChatDirectory(this._repository);

  Future<List<UserEntity>> call(UserEntity? me) async {
    if (me == null) return const [];

    final everyone = await _repository.getAllUsers();
    final directory = everyone
        .where((u) => u.uid != me.uid && u.isActive)
        .toList();

    directory.sort((a, b) => _label(a).toLowerCase().compareTo(
          _label(b).toLowerCase(),
        ));
    return List.unmodifiable(directory);
  }

  static String _label(UserEntity u) =>
      (u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email;
}
