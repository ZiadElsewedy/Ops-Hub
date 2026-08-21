import 'package:flutter/material.dart';
import 'package:opshub/core/enums/request_status.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/requests/domain/entities/request_event.dart';
import 'package:opshub/features/requests/presentation/request_format.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_gallery.dart';

/// The request activity timeline — a premium issue-tracker feed. Every event is
/// one row: the opening submission + comments render as side-aligned bubbles;
/// the decision (approved / rejected) renders as a centered system chip on a
/// connecting spine. [viewerId] aligns the viewer's own comments to the right.
class RequestTimeline extends StatelessWidget {
  const RequestTimeline({
    super.key,
    required this.events,
    required this.viewerId,
  });

  final List<RequestEvent> events;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++)
          _EventRow(
            event: events[i],
            viewerId: viewerId,
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.viewerId,
    required this.isFirst,
    required this.isLast,
  });

  final RequestEvent event;
  final String viewerId;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (event.isSystem) return _SystemMarker(event: event);

    final mine = event.authorId.isNotEmpty && event.authorId == viewerId;
    final isOpening = event.isSubmitted;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: _Bubble(event: event, mine: mine, opening: isOpening),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.event, required this.mine, required this.opening});
  final RequestEvent event;
  final bool mine;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final author = (event.authorName ?? '').trim();
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: mine
            ? AppColors.primary.withAlpha(20)
            : AppColors.darkSurface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(mine ? AppRadius.lg : AppSpacing.xs),
          bottomRight: Radius.circular(mine ? AppSpacing.xs : AppRadius.lg),
        ),
        border: Border.all(
          color: mine
              ? AppColors.primary.withAlpha(50)
              : AppColors.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (opening) ...[
                const Icon(Icons.description_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  opening
                      ? 'Original request${author.isNotEmpty ? ' · $author' : ''}'
                      : (author.isEmpty ? 'Comment' : author),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                RequestFormat.relativeTime(event.createdAt),
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          if (event.hasText) ...[
            const SizedBox(height: 6),
            Text(event.text!,
                style:
                    AppTypography.body.copyWith(color: AppColors.textPrimary)),
          ],
          if (event.hasAttachments) ...[
            const SizedBox(height: AppSpacing.sm),
            AttachmentGallery(attachments: event.attachments),
          ],
        ],
      ),
    );
  }
}

class _SystemMarker extends StatelessWidget {
  const _SystemMarker({required this.event});
  final RequestEvent event;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(event.kind);
    final color = status != null
        ? RequestFormat.statusColor(status)
        : AppColors.textTertiary;
    final label = _label(event);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: AppRadius.fullAll,
              border: Border.all(color: color.withAlpha(70)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(event.kind), size: 13, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTypography.labelSmall.copyWith(
                        color: color, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text(RequestFormat.relativeTime(event.createdAt),
                    style: AppTypography.labelSmall
                        .copyWith(color: color.withAlpha(160))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  RequestStatus? _statusFor(RequestEventKind kind) => switch (kind) {
        RequestEventKind.approved => RequestStatus.approved,
        RequestEventKind.rejected => RequestStatus.rejected,
        // Reopened = pending again, so it wears the pending tint.
        RequestEventKind.reopened => RequestStatus.pending,
        _ => null,
      };

  IconData _icon(RequestEventKind kind) => switch (kind) {
        RequestEventKind.approved => Icons.check_circle_outline_rounded,
        RequestEventKind.rejected => Icons.cancel_outlined,
        RequestEventKind.reopened => Icons.replay_rounded,
        _ => Icons.circle_outlined,
      };

  String _label(RequestEvent event) {
    final who = (event.authorName ?? '').trim();
    final base = switch (event.kind) {
      RequestEventKind.approved => 'Approved',
      RequestEventKind.rejected => 'Rejected',
      RequestEventKind.reopened => 'Reopened',
      _ => 'Updated',
    };
    return who.isEmpty ? base : '$base by $who';
  }
}
