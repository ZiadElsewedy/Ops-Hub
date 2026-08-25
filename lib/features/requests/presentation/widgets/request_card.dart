import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/requests/domain/entities/request_entity.dart';
import 'package:opshub/features/requests/presentation/request_format.dart';

/// A single request row in the inbox — communicates, at a glance: type (icon +
/// name), status, requester, branch, time, and the one-line message. Premium
/// monochrome: a soft surface, hairline border, a status-tinted type tile and
/// pill, and the REQ reference as a quiet trailing meta. A **pending** row wears
/// a faint status-tinted border — the one thing in the list that needs action.
/// Deliberately restrained — no information overload.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.branchName,
    this.showRequester = true,
  });

  final RequestEntity request;
  final VoidCallback onTap;
  final String? branchName;

  /// Hidden on an employee's own list (they know it's theirs).
  final bool showRequester;

  @override
  Widget build(BuildContext context) {
    final statusColor = RequestFormat.statusColor(request.status);
    final pendingFor = request.pendingFor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            // Pending = the one row that needs action — it alone wears a faint
            // status tint; decided rows stay on the quiet hairline.
            border: Border.all(
              color: request.isPending
                  ? statusColor.withAlpha(48)
                  : AppColors.darkBorder,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeTile(request: request, tint: statusColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.type.label,
                            style: AppTypography.label.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusPill(request: request),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.summary,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary, height: 1.35),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MetaRow(
                      request: request,
                      branchName: branchName,
                      showRequester: showRequester,
                      pendingFor: pendingFor,
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
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.request, required this.tint});
  final RequestEntity request;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        // A soft vertical wash reads richer than a flat fill, still monochrome
        // discipline — the tint stays the status colour at whisper alpha.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withAlpha(34), tint.withAlpha(16)],
        ),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: tint.withAlpha(55)),
      ),
      child: Icon(RequestFormat.icon(request.type), size: 21, color: tint),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.request});
  final RequestEntity request;

  @override
  Widget build(BuildContext context) {
    final color = RequestFormat.statusColor(request.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(RequestFormat.statusIcon(request.status), size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            request.status.label,
            style: AppTypography.labelSmall
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.request,
    required this.branchName,
    required this.showRequester,
    required this.pendingFor,
  });

  final RequestEntity request;
  final String? branchName;
  final bool showRequester;
  final Duration? pendingFor;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];

    if (showRequester && (request.requesterName ?? '').trim().isNotEmpty) {
      parts.add(_MetaText(icon: Icons.person_outline_rounded, text: request.requesterName!.trim()));
    }
    final branch = branchName?.trim();
    if (branch != null && branch.isNotEmpty) {
      parts.add(_MetaText(icon: Icons.storefront_outlined, text: branch));
    }
    // For a pending request show how long it's been waiting; else its time.
    if (request.status.isPending && pendingFor != null) {
      parts.add(_MetaText(
        icon: Icons.schedule_rounded,
        text: RequestFormat.waitingLabel(pendingFor!),
        color: RequestFormat.statusColor(request.status),
      ));
    } else {
      parts.add(_MetaText(
        icon: Icons.schedule_rounded,
        text: RequestFormat.relativeTime(request.lastActivityAt),
      ));
    }
    // The quiet ops reference — always last, always whisper-level.
    parts.add(_MetaText(icon: Icons.tag_rounded, text: request.refLabel));

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        // Cap + ellipsize so a very long requester/branch name can't overflow
        // its line in the parent Wrap (min-size Row doesn't ellipsize on its own).
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(color: c)),
        ),
      ],
    );
  }
}

