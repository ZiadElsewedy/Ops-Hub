import 'package:flutter_test/flutter_test.dart';
import 'package:drop/features/chat/data/models/chat_conversation_model.dart';
import 'package:drop/features/chat/domain/entities/chat_conversation.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';

/// **The served last-message preview (FR-021).**
///
/// The list endpoint used to return `lastMessageAt` without the message, which
/// forced the inbox into one extra request per visible row. The backend now
/// joins it in. The field is **additive**: a server that predates it simply
/// omits it, and the client must fall back rather than blank the row — these
/// tests pin both directions, because the deployed server is the old one until
/// the API is released.
void main() {
  Map<String, dynamic> row({Object? lastMessage = _absent}) => {
        'id': 'c1',
        'counterpartUserId': 'u2',
        'counterpartExternalId': 'fb-u2',
        'participantIds': ['u1', 'u2'],
        'createdAt': '2026-08-01T09:00:00.000Z',
        'lastMessageAt': '2026-08-03T09:00:00.000Z',
        'unreadCount': 2,
        if (!identical(lastMessage, _absent)) 'lastMessage': lastMessage,
      };

  group('parsing', () {
    test('a served preview is carried onto the summary', () {
      final summary = ChatConversationModel.summaryFromJson(row(lastMessage: {
        'id': 'm1',
        'senderId': 'u2',
        'type': 'TEXT',
        'body': 'On my way',
        'deletedForEveryoneAt': null,
        'createdAt': '2026-08-03T09:00:00.000Z',
      }));

      expect(summary.lastMessage!.body, 'On my way');
      expect(summary.lastMessage!.senderId, 'u2');
      expect(summary.lastMessage!.isDeletedForEveryone, isFalse);
    });

    test('an older server that omits the field parses to null, not a crash', () {
      final summary = ChatConversationModel.summaryFromJson(row());

      expect(summary.lastMessage, isNull);
      // Everything else must still be intact — this is the deployed shape today.
      expect(summary.unreadCount, 2);
      expect(summary.lastMessageAt, isNotNull);
    });

    test('an explicit null (nothing to preview) parses to null', () {
      expect(
        ChatConversationModel.summaryFromJson(row(lastMessage: null))
            .lastMessage,
        isNull,
      );
    });

    test('a malformed preview is ignored rather than thrown on', () {
      expect(
        ChatConversationModel.summaryFromJson(row(lastMessage: {'body': 'hi'}))
            .lastMessage,
        isNull,
      );
    });
  });

  group('preview text', () {
    test('uses the body when there is one', () {
      expect(
        chatLastMessagePreviewText(const ChatLastMessage(
          id: 'm1',
          senderId: 'u2',
          type: 'TEXT',
          body: '  On my way  ',
        )),
        'On my way',
      );
    });

    test('a deleted-for-everyone message shows the placeholder, not its body',
        () {
      expect(
        chatLastMessagePreviewText(ChatLastMessage(
          id: 'm1',
          senderId: 'u2',
          type: 'TEXT',
          body: 'the original text',
          deletedForEveryoneAt: DateTime(2026, 8, 3),
        )),
        chatDeletedForEveryonePlaceholder,
      );
    });

    test('a body-less attachment still gets a label', () {
      // The served payload carries no attachment metadata, so this cannot be a
      // filename — but an empty row would read as a bug to the user.
      expect(
        chatLastMessagePreviewText(const ChatLastMessage(
          id: 'm1',
          senderId: 'u2',
          type: 'IMAGE',
        )),
        'Attachment',
      );
    });

    test('an empty text message stays empty', () {
      expect(
        chatLastMessagePreviewText(const ChatLastMessage(
          id: 'm1',
          senderId: 'u2',
          type: 'TEXT',
          body: '   ',
        )),
        '',
      );
    });
  });
}

const _absent = Object();
