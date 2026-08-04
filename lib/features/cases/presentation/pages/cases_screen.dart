import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/responsive/breakpoints.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/drop_empty_state.dart';
import 'package:drop/features/cases/domain/case_ordering.dart';
import 'package:drop/features/cases/domain/entities/case_entity.dart';
import 'package:drop/features/cases/presentation/cubit/case_conversation_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_state.dart';
import 'package:drop/features/cases/presentation/widgets/case_conversation_view.dart';
import 'package:drop/features/cases/presentation/widgets/case_list_tile.dart';
import 'package:drop/core/widgets/list_skeleton.dart';
import 'package:drop/core/widgets/app_error_state.dart';

/// Case Management entry point. **Desktop** → a split-pane workspace (case
/// inbox on the left, active conversation on the right). **Mobile / tablet** →
/// the inbox as a list that pushes a full-screen conversation. Role-scoped
/// (admin: all · manager: branch · employee: own).
class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  @override
  void initState() {
    super.initState();
    final user = context.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CaseListCubit>().load(user),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return context.isDesktop ? const _Workspace() : const _MobileInbox();
  }
}

// ─── Desktop: split-pane workspace ─────────────────────────────────────
class _Workspace extends StatelessWidget {
  const _Workspace();

  @override
  Widget build(BuildContext context) {
    final isGlobal = context.currentRole?.isAdmin ?? false;
    return ColoredBox(
      color: AppColors.darkBg,
      child: BlocBuilder<CaseListCubit, CaseListState>(
        builder: (context, state) {
          return state.maybeWhen(
            loaded: (cases, busy, directory, selectedId, unreadIds) {
              // Auto-select the first case so the pane opens into a conversation.
              if (selectedId == null && cases.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final cubit = context.read<CaseListCubit>();
                  if (cubit.selectedId == null && cubit.caseById(cases.first.id) != null) {
                    cubit.select(cases.first.id);
                  }
                });
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 360,
                    child: _ListPane(
                      cases: cases,
                      selectedId: selectedId,
                      unreadIds: unreadIds,
                      showBranch: isGlobal,
                      onOpen: (id) => context.read<CaseListCubit>().select(id),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.darkBorder),
                  Expanded(
                    child: _RightPane(selectedId: selectedId),
                  ),
                ],
              );
            },
            orElse: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          );
        },
      ),
    );
  }
}

class _ListPane extends StatelessWidget {
  const _ListPane({
    required this.cases,
    required this.selectedId,
    required this.unreadIds,
    required this.showBranch,
    required this.onOpen,
  });
  final List<CaseEntity> cases;
  final String? selectedId;
  final Set<String> unreadIds;
  final bool showBranch;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final canFile = !(context.currentRole?.isAdmin ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg,
              AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              const Text('Cases', style: AppTypography.h2),
              const Spacer(),
              if (canFile)
                IconButton(
                  tooltip: 'New Case',
                  onPressed: () => context.push(RouteNames.casesCreate),
                  icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
        Expanded(
          child: _Inbox(
            cases: cases,
            onOpen: onOpen,
            selectedId: selectedId,
            unreadIds: unreadIds,
            showBranch: showBranch,
            branchNames: context.read<CaseListCubit>().branchNames,
          ),
        ),
      ],
    );
  }
}

class _RightPane extends StatelessWidget {
  const _RightPane({required this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final id = selectedId;
    if (id == null) {
      return const _EmptyPane();
    }
    final user = context.currentUser;
    return BlocProvider<CaseConversationCubit>(
      key: ValueKey(id),
      create: (_) => AppDependencies.createCaseConversationCubit(id, user),
      child: CaseConversationView(
        onClosedOrDeleted: () => context.read<CaseListCubit>().select(null),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 44, color: AppColors.textTertiary),
          SizedBox(height: AppSpacing.md),
          Text('Select a case', style: AppTypography.h3),
          SizedBox(height: 4),
          Text('Pick a conversation from the list.',
              style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}

// ─── Mobile: inbox list → pushes the conversation ──────────────────────
class _MobileInbox extends StatelessWidget {
  const _MobileInbox();

  @override
  Widget build(BuildContext context) {
    final isGlobal = context.currentRole?.isAdmin ?? false;
    final canFile = !isGlobal;
    return AdaptiveScaffold(
      title: 'Cases',
      subtitle: isGlobal
          ? 'Incoming cases & escalations'
          : 'Your private conversations',
      floatingActionButton: canFile
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RouteNames.casesCreate),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Case'),
            )
          : null,
      body: BlocBuilder<CaseListCubit, CaseListState>(
        builder: (context, state) {
          return state.when(
            initial: () => const _Loading(),
            loading: () => const _Loading(),
            error: (message) => _ErrorView(
              message: message,
              onRetry: () {
                final u = context.currentUser;
                if (u != null) {
                  context.read<CaseListCubit>().load(u, forceRefresh: true);
                }
              },
            ),
            loaded: (cases, busy, directory, selectedId, unreadIds) =>
                RefreshIndicator(
              onRefresh: () => context.read<CaseListCubit>().refresh(),
              color: AppColors.primary,
              child: _Inbox(
                cases: cases,
                onOpen: (id) {
                  // Opening the conversation clears its unread flag.
                  context.read<CaseListCubit>().markSeen(id);
                  context.push(RouteNames.caseDetail(id));
                },
                unreadIds: unreadIds,
                showBranch: isGlobal,
                branchNames: context.read<CaseListCubit>().branchNames,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Shared inbox (search · active section · collapsible archive) ──────
class _Inbox extends StatefulWidget {
  const _Inbox({
    required this.cases,
    required this.onOpen,
    required this.showBranch,
    required this.branchNames,
    required this.unreadIds,
    this.selectedId,
  });

  final List<CaseEntity> cases;
  final ValueChanged<String> onOpen;
  final bool showBranch;
  final Map<String, String> branchNames;
  final Set<String> unreadIds;
  final String? selectedId;

  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  String _query = '';
  bool _archiveOpen = false;

  List<CaseEntity> _filter(List<CaseEntity> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      return c.subject.toLowerCase().contains(q) ||
          (c.description ?? '').toLowerCase().contains(q) ||
          (c.lastMessagePreview ?? '').toLowerCase().contains(q) ||
          c.category.label.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final parts = partitionCases(_filter(widget.cases));
    final active = parts.active;
    final archived = parts.archived;
    final nothing = active.isEmpty && archived.isEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          child: AppSearchField(
            hint: 'Search cases',
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: nothing
              ? DropEmptyState(
                  title: widget.cases.isEmpty ? 'No cases yet' : 'Nothing here',
                  message: widget.cases.isEmpty
                      ? 'Open a case to start a private conversation about an issue.'
                      : 'No cases match your search.',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                  children: [
                    for (final c in active) _tile(c),
                    if (archived.isNotEmpty)
                      _ArchiveHeader(
                        count: archived.length,
                        open: _archiveOpen,
                        onTap: () =>
                            setState(() => _archiveOpen = !_archiveOpen),
                      ),
                    if (_archiveOpen)
                      for (final c in archived) _tile(c),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tile(CaseEntity c) => CaseListTile(
        caseItem: c,
        selected: c.id == widget.selectedId,
        unread: widget.unreadIds.contains(c.id),
        branchName: widget.showBranch ? widget.branchNames[c.branchId] : null,
        onTap: () => widget.onOpen(c.id),
      );
}

class _ArchiveHeader extends StatelessWidget {
  const _ArchiveHeader({
    required this.count,
    required this.open,
    required this.onTap,
  });
  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(open ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text('Archived · $count',
                style: AppTypography.label
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  // The card rhythm the real list will land in, rather than a spinner in the
  // middle of nowhere — the screen no longer jumps when data arrives.
  Widget build(BuildContext context) => const ListSkeleton();
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppErrorState(
        title: 'Could not load cases',
        message: message,
        retryLabel: 'Retry',
        onRetry: onRetry,
      );
}
