import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/presentation/case_format.dart';
import 'package:opshub/features/task/presentation/activity_format.dart'
    show relativeTime;

/// A dense, scannable inbox row for one case — the conversation-inbox feel
/// (subject · last-message preview · time · status dot · urgent). [selected]
/// draws the desktop split-pane highlight.
class CaseListTile extends StatelessWidget {
  const CaseListTile({
    super.key,
    required this.caseItem,
    required this.onTap,
    this.selected = false,
    this.unread = false,
    this.branchName,
  });

  final CaseEntity caseItem;
  final VoidCallback onTap;
  final bool selected;

  /// New activity since the viewer last opened this case — drives the unread
  /// dot + emphasized subject/time (see `CaseSeenStore`).
  final bool unread;

  /// Shown for the admin/global list (which spans branches). Null → hidden.
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final time = caseItem.lastActivityAt == null
        ? ''
        : relativeTime(caseItem.lastActivityAt!);
    final preview = (caseItem.lastMessagePreview ?? '').trim();
    final statusColor = caseStatusColor(caseItem.status);

    return Material(
      color: selected ? AppColors.primarySurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
              bottom: const BorderSide(color: AppColors.darkBorder, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed unread gutter — a filled dot when unread, empty otherwise,
              // so read and unread rows stay aligned.
              SizedBox(
                width: 14,
                child: unread
                    ? const Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: _UnreadDot(),
                      )
                    : null,
              ),
              _CategoryAvatar(caseItem: caseItem),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            caseItem.subject,
                            style: AppTypography.body.copyWith(
                                fontWeight:
                                    unread ? FontWeight.w700 : FontWeight.w600,
                                height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(time,
                              style: AppTypography.caption.copyWith(
                                  color: unread
                                      ? AppColors.textPrimary
                                      : AppColors.textTertiary,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        style: AppTypography.bodySmall.copyWith(
                            color: unread
                                ? AppColors.textSecondary
                                : AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(caseItem.status.label,
                            style: AppTypography.caption
                                .copyWith(color: statusColor)),
                        if (branchName != null && branchName!.isNotEmpty) ...[
                          _dot(),
                          Flexible(
                            child: Text(branchName!,
                                style: AppTypography.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        if (caseItem.urgent) ...[
                          _dot(),
                          const Icon(Icons.priority_high_rounded,
                              size: 12, color: AppColors.error),
                          Text('Urgent',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.error)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      );
}

/// The unread indicator — a small filled monochrome dot (there is no chromatic
/// accent, so unread reads as the white [AppColors.primary] on the dark surface).
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      );
}

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.caseItem});
  final CaseEntity caseItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.mdAll,
      ),
      child: Icon(caseCategoryIcon(caseItem.category),
          size: 18, color: AppColors.textSecondary),
    );
  }
}
