import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';

/// The counterpart identity for [conversationId], resolved from the inbox
/// summary + the session directory — the two sources both notification tap
/// surfaces already have in hand.
///
/// These args are a **first-paint optimization only**: the thread screen
/// resolves the same identity itself, so a null here costs a moment of
/// placeholder, never a wrong header. Kept in one place so the FCM tap
/// (`main.dart`) and the in-app banner tap (`ChatNotificationListener`) cannot
/// drift into building the header two different ways.
ChatThreadArgs? chatThreadArgsFor(
  String conversationId, {
  Map<String, UserEntity>? directory,
}) {
  final summary = AppDependencies.chatListCubit.conversationById(
    conversationId,
  );
  if (summary == null) return null;
  final dir = directory ?? AppDependencies.chatDirectorySnapshot;
  final external = summary.counterpartExternalId;
  final user = external == null ? null : dir[external];
  final role = user == null ? null : chatRoleLabel(user.role);
  final position = user?.position?.trim();
  return ChatThreadArgs(
    counterpartUserId: summary.counterpartUserId,
    counterpartExternalId: summary.counterpartExternalId,
    counterpartName:
        chatDisplayName(user, fallbackId: summary.counterpartUserId),
    counterpartPhotoUrl: user?.photoUrl,
    counterpartRoleLine: role == null
        ? null
        : (position == null || position.isEmpty) ? role : '$position · $role',
  );
}

/// Opens a chat-notification destination with an intentional back stack:
/// thread ← inbox ← home. Unlike ordinary notification routes, a chat thread
/// depends on its inbox as its natural parent.
void openChatDeepLink(
  GoRouter router,
  String conversationId, {
  ChatThreadArgs? args,
}) {
  final destination = RouteNames.chatConversation(conversationId);
  if (router.routeInformationProvider.value.uri.path == destination) return;
  router.go(RouteNames.chat);
  router.push(destination, extra: args);
}
