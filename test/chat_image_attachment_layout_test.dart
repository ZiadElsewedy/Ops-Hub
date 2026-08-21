import 'dart:async';

import 'package:opshub/core/enums/chat_attachment_kind.dart';
import 'package:opshub/core/enums/chat_message_type.dart';
import 'package:opshub/features/chat/domain/entities/chat_message.dart';
import 'package:opshub/features/chat/presentation/widgets/chat_message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('image bubble keeps its laid-out size after its URL resolves',
      (tester) async {
    final url = Completer<String?>();
    final message = ChatMessage(
      id: 'image-1',
      conversationId: 'conversation-1',
      senderId: 'them',
      type: ChatMessageType.image,
      attachment: const ChatMessageAttachment(
        id: 'attachment-1',
        kind: ChatAttachmentKind.image,
        format: 'JPG',
        mimeType: 'image/jpeg',
        originalFilename: 'portrait.jpg',
        byteSize: 2048,
      ),
      seq: BigInt.one,
      status: 'SENT',
      createdAt: DateTime.utc(2026, 8, 3),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageList(
          messages: [message],
          myUserId: 'me',
          imageUrlLoader: (_) => url.future,
        ),
      ),
    ));
    await tester.pump();

    final imageViewport = find.byType(ClipRRect);
    final before = tester.getSize(imageViewport);
    // The footprint a portrait photo already had before image bubbles were
    // pinned (width 240, maxHeight 280) — pinning bought scroll stability
    // without shrinking photos.
    expect(before, const Size(240, 280));

    url.complete('https://storage.example/portrait.jpg');
    await tester.pump();

    // THE INVARIANT THAT MATTERS: resolving the image must not change the row's
    // occupied size. A regression here is the scroll jump coming back — every
    // row below shifts the moment a photo decodes. The network image may still
    // be decoding (or fail under the test HTTP client), but all post-resolution
    // states share this exact viewport.
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(imageViewport), before);
  });
}
