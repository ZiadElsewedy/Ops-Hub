import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/chat/presentation/chat_thread_args.dart';
import 'package:drop/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/new_chat_cubit.dart';
import 'package:drop/features/chat/presentation/cubit/new_chat_state.dart';

/// The new-conversation teammate picker (`/chat/new`). Lists everyone the
/// caller may message — every active user except themselves, with no branch or
/// role scoping (see [GetChatDirectory]) — supports search, and shows each
/// teammate's avatar · name · role. Selecting one starts (get-or-creates)
/// the conversation through [ChatListCubit] and replaces this screen with the
/// thread — so Back returns to the inbox, not the picker. An already-existing
/// conversation opens instead of creating a duplicate (server-idempotent).
class NewChatScreen extends StatelessWidget {
  const NewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;
    return BlocProvider<NewChatCubit>(
      create: (_) => AppDependencies.createNewChatCubit(user),
      child: const NewChatView(),
    );
  }
}

/// The picker body — reads its [NewChatCubit] and the app-wide [ChatListCubit]
/// from context. Split out from [NewChatScreen] so it can be hosted directly
/// (e.g. in tests) with a provided cubit, bypassing DI.
class NewChatView extends StatefulWidget {
  const NewChatView({super.key});
  @override
  State<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends State<NewChatView> {
  String _query = '';

  /// The teammate whose conversation is being started (its row shows a
  /// spinner and taps are blocked). One at a time.
  String? _startingUid;

  List<UserEntity> _filter(List<UserEntity> teammates) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return teammates;
    return teammates.where((u) {
      final name = (u.displayName ?? '').toLowerCase();
      return name.contains(q) ||
          u.email.toLowerCase().contains(q) ||
          _roleLabel(u.role).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _start(BuildContext context, UserEntity teammate) async {
    if (_startingUid != null) return;
    setState(() => _startingUid = teammate.uid);
    final listCubit = context.read<ChatListCubit>();
    final conversation = await listCubit.startChatWith(teammate.uid);
    if (!context.mounted) return;
    if (conversation == null) {
      setState(() => _startingUid = null);
      context.showError('Could not start the conversation. Please try again.');
      return;
    }
    // Replace the picker with the thread so Back returns to the inbox. Carry
    // the teammate's real name/avatar (we already have it) + the server
    // counterpart id for own-message alignment.
    final counterpartId =
        listCubit.conversationById(conversation.id)?.counterpartUserId;
    context.pushReplacement(
      RouteNames.chatConversation(conversation.id),
      extra: ChatThreadArgs(
        counterpartUserId: counterpartId,
        counterpartName: (teammate.displayName?.isNotEmpty ?? false)
            ? teammate.displayName
            : teammate.email,
        counterpartPhotoUrl: teammate.photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'New Chat',
      body: BlocBuilder<NewChatCubit, NewChatState>(
        builder: (context, state) {
          return switch (state) {
            NewChatLoading() => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            NewChatError(:final message) => _ErrorView(
                message: message,
                onRetry: () => context.read<NewChatCubit>().load(),
              ),
            NewChatLoaded(:final teammates) => _List(
                teammates: _filter(teammates),
                total: teammates.length,
                query: _query,
                startingUid: _startingUid,
                onQuery: (v) => setState(() => _query = v),
                onSelect: (u) => _start(context, u),
              ),
          };
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.teammates,
    required this.total,
    required this.query,
    required this.startingUid,
    required this.onQuery,
    required this.onSelect,
  });

  final List<UserEntity> teammates;
  final int total;
  final String query;
  final String? startingUid;
  final ValueChanged<String> onQuery;
  final ValueChanged<UserEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: AppSearchField(hint: 'Search teammates', onChanged: onQuery),
        ),
        Expanded(
          child: teammates.isEmpty
              ? DropEmptyState(
                  title: total == 0 ? 'No teammates yet' : 'No matches',
                  message: total == 0
                      ? 'There is no one else to message yet.'
                      : 'No teammate matches "$query".',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                  itemCount: teammates.length,
                  itemBuilder: (context, i) {
                    final u = teammates[i];
                    return _TeammateRow(
                      teammate: u,
                      starting: u.uid == startingUid,
                      // Block every row while one start is in flight.
                      onTap: startingUid == null ? () => onSelect(u) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TeammateRow extends StatelessWidget {
  const _TeammateRow({
    required this.teammate,
    required this.starting,
    required this.onTap,
  });

  final UserEntity teammate;
  final bool starting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = (teammate.displayName?.isNotEmpty ?? false)
        ? teammate.displayName!
        : teammate.email;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.darkBorder, width: 0.5)),
        ),
        child: Row(
          children: [
            // Real avatar when a photo exists, otherwise the initial(s) of the
            // display name — never a generic grey glyph (UserAvatar's fallback).
            UserAvatar.fromUser(teammate, size: 44),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // Card content: display name + role only. The internal/Firebase
              // user id is NEVER shown — it's an implementation detail.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_roleLabel(teammate.role),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
            if (starting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Human-readable role label, local to chat so the feature stays self-contained.
String _roleLabel(UserRole role) => switch (role) {
      UserRole.admin => 'Admin',
      UserRole.manager => 'Store Manager',
      UserRole.employee => 'Employee',
    };
