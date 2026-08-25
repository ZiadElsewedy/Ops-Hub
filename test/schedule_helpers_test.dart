import 'package:flutter_test/flutter_test.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/schedule/presentation/widgets/schedule_helpers.dart';

/// Verifies the schedule name-resolution + **orphan detection** logic — the root
/// of the Branch Schedule "Unknown" issue. An assigned uid that isn't a current
/// branch member is a broken reference that must be flagged, not masked.
void main() {
  const alice = UserEntity(
      uid: 'u_alice',
      email: 'alice@x.com',
      authProvider: 'password',
      displayName: 'Alice');
  const bob = UserEntity(
      uid: 'u_bob',
      email: 'bob@x.com',
      authProvider: 'password',
      displayName: 'Bob');
  final members = [alice, bob];

  group('userForUid / nameForUid', () {
    test('resolves a current member to their display name', () {
      expect(userForUid('u_alice', members), alice);
      expect(nameForUid('u_alice', members), 'Alice');
    });

    test('falls back to email when no display name', () {
      const noName =
          UserEntity(uid: 'u_c', email: 'c@x.com', authProvider: 'password');
      expect(nameForUid('u_c', [noName]), 'c@x.com');
    });
  });

  group('isOrphanAssignment', () {
    test('a current member is not an orphan', () {
      expect(isOrphanAssignment('u_alice', members), isFalse);
    });

    test('a uid not in the branch (moved/removed) is an orphan', () {
      expect(isOrphanAssignment('u_ghost', members), isTrue);
    });

    test('empty member list → every assignment is an orphan', () {
      expect(isOrphanAssignment('u_alice', const []), isTrue);
    });
  });

  group('shortUid', () {
    test('truncates a long uid with an ellipsis', () {
      expect(shortUid('a1b2c3d4e5'), 'a1b2c3…');
    });

    test('leaves a short uid untouched', () {
      expect(shortUid('abc'), 'abc');
    });
  });
}
