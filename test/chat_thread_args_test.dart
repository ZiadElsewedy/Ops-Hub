import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';

void main() {
  const args = ChatThreadArgs(
    counterpartUserId: 'counterpart',
    counterpartExternalId: 'uid-counterpart',
    counterpartName: 'Maya Ali',
    counterpartPhotoUrl: 'https://example.test/maya.jpg',
    counterpartRoleLine: 'Floor Lead · Employee',
  );

  test('identical header resolutions are equal', () {
    const repeated = ChatThreadArgs(
      counterpartUserId: 'counterpart',
      counterpartExternalId: 'uid-counterpart',
      counterpartName: 'Maya Ali',
      counterpartPhotoUrl: 'https://example.test/maya.jpg',
      counterpartRoleLine: 'Floor Lead · Employee',
    );
    expect(args, equals(repeated));
    expect(args.hashCode, repeated.hashCode);
  });

  test('cached inbox and directory resolve a real header without network', () {
    const user = UserEntity(
      uid: 'uid-counterpart',
      email: 'maya@drop.test',
      displayName: 'Maya Ali',
      authProvider: 'password',
      branchId: 'branch-1',
      position: 'Floor Lead',
    );
    final summary = ChatConversationSummary(
      id: 'conversation-1',
      counterpartUserId: 'counterpart',
      counterpartExternalId: user.uid,
      participantIds: const ['me', 'counterpart'],
      createdAt: DateTime(2026, 8, 3),
    );

    final resolved = chatThreadArgsFromSummary(summary, {user.uid: user});

    expect(resolved.counterpartName, 'Maya Ali');
    expect(resolved.counterpartRoleLine, 'Floor Lead · Employee');
    expect(resolved.counterpartName, isNot('Conversation'));
  });
}
