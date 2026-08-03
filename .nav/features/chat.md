<!-- AUTO-GENERATED mechanical inventory. Regenerate: python3 .nav/gen_atlas.py
     Hand-authored intelligence lives BELOW the marker. Do not delete that section. -->
# 📍 FEATURE CARD — `chat`

> `lib/features/chat/` · **58 files** · layer-complete clean-architecture slice

## Entry points (route → screen)
| Route const | Path | Guard/notes |
|---|---|---|
| `RouteNames.chat` | `/chat` |  |
| `RouteNames.chatConversationPattern` | `/chat/:conversationId` |  |
| `RouteNames.chatNew` | `/chat/new` |  |

## Owner files (by layer)
**presentation:page**
- `lib/features/chat/presentation/pages/chat_conversation_screen.dart`
- `lib/features/chat/presentation/pages/chat_screen.dart`
- `lib/features/chat/presentation/pages/conversation_info_screen.dart`
- `lib/features/chat/presentation/pages/image_viewer_screen.dart`
- `lib/features/chat/presentation/pages/message_info_screen.dart`
- `lib/features/chat/presentation/pages/new_chat_screen.dart`

**presentation:cubit**
- `lib/features/chat/presentation/cubit/chat_conversation_cubit.dart`
- `lib/features/chat/presentation/cubit/chat_conversation_state.dart`
- `lib/features/chat/presentation/cubit/chat_conversation_state.freezed.dart`
- `lib/features/chat/presentation/cubit/chat_list_cubit.dart`
- `lib/features/chat/presentation/cubit/chat_list_state.dart`
- `lib/features/chat/presentation/cubit/chat_list_state.freezed.dart`
- `lib/features/chat/presentation/cubit/new_chat_cubit.dart`
- `lib/features/chat/presentation/cubit/new_chat_state.dart`

**presentation:widget**
- `lib/features/chat/presentation/widgets/chat_attachment_sheet.dart`
- `lib/features/chat/presentation/widgets/chat_composer.dart`
- `lib/features/chat/presentation/widgets/chat_conversation_tile.dart`
- `lib/features/chat/presentation/widgets/chat_conversation_view.dart`
- `lib/features/chat/presentation/widgets/chat_message_actions.dart`
- `lib/features/chat/presentation/widgets/chat_message_list.dart`
- `lib/features/chat/presentation/widgets/chat_notification_listener.dart`
- `lib/features/chat/presentation/widgets/recent_messages_card.dart`

**presentation:other**
- `lib/features/chat/presentation/chat_attachment_picker.dart`
- `lib/features/chat/presentation/chat_conversation_presence.dart`
- `lib/features/chat/presentation/chat_deep_link_navigation.dart`
- `lib/features/chat/presentation/chat_document_service.dart`
- `lib/features/chat/presentation/chat_format.dart`
- `lib/features/chat/presentation/chat_message_preview.dart`
- `lib/features/chat/presentation/chat_thread_args.dart`
- `lib/features/chat/presentation/chat_thread_cache.dart`

**domain:entity**
- `lib/features/chat/domain/entities/chat_attachment_download.dart`
- `lib/features/chat/domain/entities/chat_conversation.dart`
- `lib/features/chat/domain/entities/chat_message.dart`
- `lib/features/chat/domain/entities/chat_outgoing_attachment.dart`
- `lib/features/chat/domain/entities/chat_read_receipt.dart`

**domain:usecase**
- `lib/features/chat/domain/usecases/delete_chat_message_for_everyone.dart`
- `lib/features/chat/domain/usecases/delete_chat_message_for_me.dart`
- `lib/features/chat/domain/usecases/get_cached_conversations.dart`
- `lib/features/chat/domain/usecases/get_chat_attachment_url.dart`
- `lib/features/chat/domain/usecases/get_chat_directory.dart`
- `lib/features/chat/domain/usecases/get_conversation.dart`
- `lib/features/chat/domain/usecases/get_conversations.dart`
- `lib/features/chat/domain/usecases/load_chat_history.dart`
- `lib/features/chat/domain/usecases/mark_chat_read.dart`
- `lib/features/chat/domain/usecases/send_chat_message.dart`
- `lib/features/chat/domain/usecases/start_conversation.dart`

**domain:repository-contract**
- `lib/features/chat/domain/repositories/chat_repository.dart`

**domain:other**
- `lib/features/chat/domain/chat_realtime.dart`

**data:repository-impl**
- `lib/features/chat/data/repositories/chat_repository_impl.dart`

**data:datasource**
- `lib/features/chat/data/datasources/chat_remote_datasource.dart`

**data:model**
- `lib/features/chat/data/models/chat_attachment_download_model.dart`
- `lib/features/chat/data/models/chat_conversation_model.dart`
- `lib/features/chat/data/models/chat_message_model.dart`

**data:other**
- `lib/features/chat/data/local/chat_database.dart`
- `lib/features/chat/data/local/chat_database.g.dart`
- `lib/features/chat/data/local/chat_local_datasource.dart`
- `lib/features/chat/data/realtime/chat_realtime_payloads.dart`
- `lib/features/chat/data/realtime/chat_socket_service.dart`

## Backend surface
- **Firestore collections:** —
- **Cloud Functions:** —
- **Security rules:** `firestore.rules` (search the collection names above) · `storage.rules` if it uploads media
- **Design spec(s):** —

## Tests
- `test/chat_conversation_actions_test.dart`
- `test/chat_conversation_presence_test.dart`
- `test/chat_conversation_tile_test.dart`
- `test/chat_conversation_view_test.dart`
- `test/chat_document_bubble_test.dart`
- `test/chat_image_attachment_layout_test.dart`
- `test/chat_list_realtime_test.dart`
- `test/chat_message_delete_test.dart`
- `test/chat_nav_promotion_test.dart`
- `test/chat_new_conversation_test.dart`
- `test/chat_offline_cache_test.dart`
- `test/chat_preview_cache_test.dart`
- `test/chat_realtime_sync_test.dart`
- `test/chat_screen_test.dart`
- `test/chat_served_preview_test.dart`

## Standard data flow (this feature follows the universal pattern)
```
UI (page/widget)
  → Cubit.method()            presentation/cubit/
    → UseCase.call()          domain/usecases/
      → Repository (contract) domain/repositories/
        → RepositoryImpl      data/repositories/
          → RemoteDatasource  data/datasources/   → Firestore/Functions/API
  ← Model.fromJson → Entity ← Stream/Future ← Cubit emits state → UI rebuilds
```

<!-- ═══════════════ HAND-AUTHORED INTELLIGENCE (edit freely) ═══════════════ -->

## Purpose
Direct 1:1 staff chat over the NestJS API. The inbox and thread are cache-first
for instant reads; REST is authoritative while Socket.IO delivers live updates.
Thread identity comes from route args first, then the inbox summary plus the
session directory — never from backend ids.

## ⚠️ Dangerous areas / invariants
- Chat is not Firebase: do not cache attachment/image bytes, fabricate presence,
  or make socket delivery authoritative.
- `ChatConversationCubit` ordering/dedup/optimistic slots and message-list keys
  are deliberate.
- A notification-opened chat must build `Home → Chat → Conversation` after the
  authenticated startup rendezvous; re-tapping the visible conversation is a no-op.

## 🧩 Extension points
- Use `ChatListCubit` for inbox state and `chatThreadArgsFromSummary` for one
  consistent, cache-backed participant identity.
- Route all chat notification opens through `openChatDeepLink`; keep
  `resolveNotificationRoute` pure.

## 🔗 Related
`core/routes/app_router.dart` owns routes and auth redirects; `main.dart` owns
FCM startup/tap sequencing; `notifications` owns pure deep-link resolution.
