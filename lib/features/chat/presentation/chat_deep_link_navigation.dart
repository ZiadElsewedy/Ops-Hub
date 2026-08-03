import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
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
  return chatThreadArgsFromSummary(summary, dir);
}

/// Opens a chat-notification destination with an intentional back stack:
/// thread ← inbox ← home. Unlike ordinary notification routes, a chat thread
/// depends on its inbox as its natural parent.
void openChatDeepLink(
  GoRouter router,
  String conversationId, {
  required UserRole role,
  ChatThreadArgs? args,
}) {
  final destination = RouteNames.chatConversation(conversationId);
  // Read the DELEGATE's location, not `routeInformationProvider.value`: an
  // imperative `push` is delegate-level and never writes back to the route
  // information provider, so that value still reports whatever the last `go`
  // set. Guarding on it would compare against a stale location and let a
  // re-tap stack a duplicate thread.
  if (router.state.uri.path == destination) return;
  // `go` intentionally establishes the authenticated root. The two pushes
  // then reproduce the normal route history: home ← inbox ← conversation.
  // This is called only after startup has restored the session, so the router
  // cannot redirect this role-aware home out from under the stack build.
  router.go(RouteNames.homeForRole(role));
  router.push(RouteNames.chat);
  router.push(destination, extra: args);
}
