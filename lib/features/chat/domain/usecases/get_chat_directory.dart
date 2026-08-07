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

  /// The active teammates the caller may start a conversation with. Unchanged
  /// contract — the new-conversation picker and every existing caller see the
  /// same active-only, self-excluded, name-sorted list.
  Future<List<UserEntity>> call(UserEntity? me) async =>
      (await resolve(me)).active;

  /// One read → **both** the active picker set and the set of Firebase uids that
  /// are deactivated. The inbox/thread need the deactivated ids to hide a
  /// conversation with a teammate whose account was turned off; deriving them
  /// here means the whole chat directory still costs a **single** `getAllUsers`
  /// read (the alternative — a second query for inactive accounts — would double
  /// it). The set is a *positive* signal: a uid is in it only when a real
  /// document says `isActive == false`, so callers never confuse "deactivated"
  /// with "directory not loaded yet".
  Future<ChatDirectorySnapshot> resolve(UserEntity? me) async {
    if (me == null) return const ChatDirectorySnapshot(active: [], deactivatedUids: {});

    final everyone = await _repository.getAllUsers();
    final active = everyone
        .where((u) => u.uid != me.uid && u.isActive)
        .toList()
      ..sort((a, b) => _label(a).toLowerCase().compareTo(
            _label(b).toLowerCase(),
          ));
    final deactivated = <String>{
      for (final u in everyone)
        if (u.uid != me.uid && !u.isActive) u.uid,
    };
    return ChatDirectorySnapshot(
      active: List.unmodifiable(active),
      deactivatedUids: Set.unmodifiable(deactivated),
    );
  }

  static String _label(UserEntity u) =>
      (u.displayName?.isNotEmpty ?? false) ? u.displayName! : u.email;
}

/// The chat directory split by account state, from one read. [active] is the
/// picker/name-resolution set; [deactivatedUids] are the Firebase uids of
/// accounts turned off (`isActive == false`), so a conversation with one can be
/// hidden and its thread refused.
class ChatDirectorySnapshot {
  const ChatDirectorySnapshot({
    required this.active,
    required this.deactivatedUids,
  });

  final List<UserEntity> active;
  final Set<String> deactivatedUids;
}
