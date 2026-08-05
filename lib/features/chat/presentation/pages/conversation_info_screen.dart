import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_logger.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/chat/presentation/chat_format.dart';

/// Conversation Info — the WhatsApp/Telegram "contact" panel for a 1:1 thread:
/// avatar · name · role · branch, shared-media / shared-documents counts, and
/// the conversation actions (search, mute, clear, delete).
///
/// Presentation-only. Online / last-seen is deliberately **not** shown — the
/// backend exposes no presence, and DROP never fabricates it. Role/branch are
/// resolved best-effort from the Firebase directory + [BranchCubit]; anything
/// that can't be resolved is simply omitted.
class ConversationInfoScreen extends StatefulWidget {
  const ConversationInfoScreen({
    super.key,
    required this.name,
    required this.mediaCount,
    required this.documentCount,
    required this.muted,
    required this.onSearch,
    required this.onToggleMute,
    required this.onClear,
    required this.onDelete,
    this.photoUrl,
    this.counterpartExternalId,
  });

  final String name;
  final String? photoUrl;
  final String? counterpartExternalId;
  final int mediaCount;
  final int documentCount;
  final bool muted;
  final VoidCallback onSearch;
  final VoidCallback onToggleMute;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  static Future<void> push(
    BuildContext context, {
    required String name,
    required int mediaCount,
    required int documentCount,
    required bool muted,
    required VoidCallback onSearch,
    required VoidCallback onToggleMute,
    required VoidCallback onClear,
    required VoidCallback onDelete,
    String? photoUrl,
    String? counterpartExternalId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConversationInfoScreen(
          name: name,
          photoUrl: photoUrl,
          counterpartExternalId: counterpartExternalId,
          mediaCount: mediaCount,
          documentCount: documentCount,
          muted: muted,
          onSearch: onSearch,
          onToggleMute: onToggleMute,
          onClear: onClear,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  State<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends State<ConversationInfoScreen> {
  UserEntity? _counterpart;
  late bool _muted = widget.muted;

  @override
  void initState() {
    super.initState();
    _resolveCounterpart();
  }

  Future<void> _resolveCounterpart() async {
    final ext = widget.counterpartExternalId;
    if (ext == null) return;
    try {
      final dir = await AppDependencies.loadChatDirectory(context.currentUser);
      if (mounted && dir[ext] != null) setState(() => _counterpart = dir[ext]);
    } catch (e) {
      AppLog.warning('chat', 'conversation info directory skipped: $e');
    }
  }

  String? get _branchName {
    final id = _counterpart?.branchId;
    if (id == null) return null;
    try {
      return context.read<BranchCubit>().branchById(id)?.name;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _counterpart == null ? null : chatRoleLabel(_counterpart!.role);
    final position = _counterpart?.position;
    final branch = _branchName;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: Text('Conversation info', style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          // ── Identity header ──
          Column(
            children: [
              UserAvatar(imageUrl: widget.photoUrl, name: widget.name, size: 96),
              const SizedBox(height: AppSpacing.md),
              Text(widget.name,
                  style: AppTypography.h2, textAlign: TextAlign.center),
              if (role != null) ...[
                const SizedBox(height: 6),
                Text(
                  position == null || position.isEmpty
                      ? role
                      : '$position · $role',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Details ──
          if (role != null || branch != null)
            _InfoGroup(children: [
              if (role != null)
                _InfoTile(
                    icon: Icons.badge_outlined, label: 'Role', value: role),
              if (branch != null)
                _InfoTile(
                    icon: Icons.store_outlined,
                    label: 'Branch',
                    value: branch),
            ]),
          const SizedBox(height: AppSpacing.md),

          // ── Shared ──
          Row(
            children: [
              Expanded(
                child: _SharedTile(
                  icon: Icons.photo_library_outlined,
                  count: widget.mediaCount,
                  label: 'Media',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SharedTile(
                  icon: Icons.description_outlined,
                  count: widget.documentCount,
                  label: 'Documents',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Actions ──
          _InfoGroup(children: [
            _ActionTile(
              icon: Icons.search_rounded,
              label: 'Search in conversation',
              // Return to the thread, then the thread opens its search bar.
              onTap: () {
                Navigator.of(context).pop();
                widget.onSearch();
              },
            ),
            _ActionTile(
              icon: _muted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_none_rounded,
              label: _muted ? 'Unmute conversation' : 'Mute conversation',
              onTap: () {
                setState(() => _muted = !_muted);
                widget.onToggleMute();
              },
            ),
            _ActionTile(
              icon: Icons.cleaning_services_outlined,
              label: 'Clear chat history',
              onTap: () {
                Navigator.of(context).pop();
                widget.onClear();
              },
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete conversation',
              destructive: true,
              onTap: () {
                Navigator.of(context).pop();
                widget.onDelete();
              },
            ),
          ]),
        ],
      ),
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Text(label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTypography.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _SharedTile extends StatelessWidget {
  const _SharedTile(
      {required this.icon, required this.count, required this.label});
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text('$count',
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Text(label,
                style: AppTypography.body
                    .copyWith(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
