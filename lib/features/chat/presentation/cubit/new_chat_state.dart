import 'package:drop/features/auth/domain/entities/user_entity.dart';

/// State for the new-conversation teammate picker. Plain sealed classes (no
/// codegen), consistent with the chat feature's value-object precedent —
/// equality is by instance, and each emit is a fresh instance so the
/// `BlocBuilder` always rebuilds.
sealed class NewChatState {
  const NewChatState();
}

/// Loading the teammate directory.
class NewChatLoading extends NewChatState {
  const NewChatLoading();
}

/// Directory loaded. [teammates] excludes the current user, ordered by the
/// repository (name). An **empty** list is the "no teammates" empty state.
class NewChatLoaded extends NewChatState {
  const NewChatLoaded(this.teammates);
  final List<UserEntity> teammates;
}

/// The directory failed to load (full-screen retry).
class NewChatError extends NewChatState {
  const NewChatError(this.message);
  final String message;
}
