import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/app_motion.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/task/domain/entities/activity_entry.dart';
import 'package:opshub/features/task/domain/entities/task_attachment.dart';
import 'package:opshub/features/task/domain/entities/task_entity.dart';
import 'package:opshub/features/task/domain/task_origin.dart';
import 'package:opshub/features/task/presentation/activity_format.dart';
import 'package:opshub/features/task/presentation/attachment_format.dart';
import 'package:opshub/features/task/presentation/cubit/task_cubit.dart';
import 'package:opshub/features/task/presentation/widgets/submission_details_sheet.dart';

/// The task's **flight recorder** — the activity timeline on Task Details.
///
/// Design (2026-07-06 rework): one prominent **current-status card** at the
/// head (the task's "you are here"), then the history as **compact ledger
/// rows** — no per-event card chrome, so eight events scan like a log, not a
/// wall of panels. A continuous spine runs through every node and each segment
/// blends this event's state colour into the next one's, so a rework loop
/// literally reads as colour flow (amber → red → purple …).
///
/// Motion stays within the app's living-border language: the head node
/// carries a slow breathing glow **only while the task is in flight**
/// (pending / started / completed / in review / rework) and sits still on
/// terminal states (approved, cancelled). One animation controller total.
///
/// Submission events stay tappable and open the [SubmissionDetailsSheet];
/// histories longer than [_collapseAfter] rows fold behind "Show earlier".
class ActivityTimeline extends StatefulWidget {
  const ActivityTimeline({
    super.key,
    required this.task,
    required this.directory,
    required this.cubit,
    required this.canReview,
  });

  final TaskEntity task;
  final Map<String, UserEntity> directory;
  final TaskCubit cubit;
  final bool canReview;

  @override
  State<ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<ActivityTimeline> {
  /// History rows (head excluded) shown before the timeline folds.
  static const _collapseAfter = 8;

  /// Rows kept visible when folded.
  static const _foldedCount = 6;

  bool _expanded = false;

  /// Submission-related events open the deep review surface on tap.
  static bool _isSubmission(String status) =>
      status == 'completed' || status == 'waitingReview';

  VoidCallback? _tapFor(BuildContext context, int index, ActivityEntry entry) {
    if (!_isSubmission(entry.status)) return null;
    return () => showSubmissionDetailsSheet(
      context: context,
      task: widget.task,
      submissionIndex: index,
      cubit: widget.cubit,
      canReview: widget.canReview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.task.activityLog;
    if (log.isEmpty) return const SizedBox.shrink();

    // Newest first — rendered purely from the event list (no hardcoded
    // sequence), so missing/optional steps and rework loops just work.
    final newest = log.length - 1;
    final head = log[newest];

    final historyCount = newest; // events below the head
    final folded = !_expanded && historyCount > _collapseAfter;
    final visible = folded ? _foldedCount : historyCount;
    final hiddenCount = historyCount - visible;

    final children = <Widget>[];
    var pos = 0; // render order (newest first) — drives the entrance stagger

    // ── Head: the current status, hero treatment ─────────────────────
    children.add(
      EntranceFade(
        delay: staggerDelay(pos++),
        offset: 10,
        child: _HeadRow(
          entry: head,
          actor: widget.directory[head.actorId],
          media: attachmentsForEvent(head, widget.task),
          // Spine continues down into the history (if any).
          nextColor: historyCount > 0
              ? activityColor(log[newest - 1].status)
              : null,
          onTap: _tapFor(context, newest, head),
        ),
      ),
    );

    // ── History: compact ledger rows ─────────────────────────────────
    for (var n = 0; n < visible; n++) {
      final i = newest - 1 - n; // chronological index of this row
      final entry = log[i];
      final isLastVisible = n == visible - 1;
      final nextColor = !isLastVisible
          ? activityColor(log[i - 1].status)
          : (hiddenCount > 0 ? AppColors.textTertiary : null);
      children.add(
        EntranceFade(
          delay: staggerDelay(pos++),
          offset: 10,
          child: _LedgerRow(
            entry: entry,
            actor: widget.directory[entry.actorId],
            media: attachmentsForEvent(entry, widget.task),
            nextColor: nextColor,
            onTap: _tapFor(context, i, entry),
          ),
        ),
      );
    }

    // ── Fold affordance for long histories ───────────────────────────
    if (hiddenCount > 0) {
      children.add(
        _ShowMoreRow(
          count: hiddenCount,
          onTap: () => setState(() => _expanded = true),
        ),
      );
    }

    return Column(children: children);
  }
}

// ─── Shared rail geometry ────────────────────────────────────────────

/// Fixed rail width so hero (34px) and ledger (24px) nodes share one axis.
const double _railWidth = 34;

/// The vertical connecting segment under a node — blends this event's colour
/// into the next (older) event's colour so the spine reads the state flow.
class _SpineSegment extends StatelessWidget {
  const _SpineSegment({
    required this.from,
    required this.to,
    this.emphasis = false,
  });

  final Color from;
  final Color to;

  /// Slightly stronger at the top under the head node.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [from.withAlpha(emphasis ? 150 : 110), to.withAlpha(110)],
        ),
      ),
    );
  }
}

/// A status node on the rail. The head node is larger and — while the task is
/// in flight — carries a slow breathing glow (the timeline's only animation;
/// terminal states sit still, matching the living-border philosophy).
class _TimelineNode extends StatefulWidget {
  const _TimelineNode({
    required this.color,
    required this.icon,
    this.head = false,
    this.breathing = false,
  });

  final Color color;
  final IconData icon;
  final bool head;
  final bool breathing;

  @override
  State<_TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<_TimelineNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(_TimelineNode old) {
    super.didUpdateWidget(old);
    if (old.breathing != widget.breathing) _syncController();
  }

  void _syncController() {
    if (widget.breathing) {
      _c ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      _c!.repeat(reverse: true);
    } else {
      _c?.stop();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.head ? 34.0 : 24.0;
    final color = widget.color;

    Widget node(double t) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(widget.head ? 46 : 24),
        border: Border.all(
          color: color.withAlpha(widget.head ? 170 : 80),
          width: widget.head ? 1.6 : 1,
        ),
        boxShadow: widget.head
            ? [
                BoxShadow(
                  color: color.withAlpha((52 + 44 * t).round()),
                  blurRadius: 10 + 8 * t,
                ),
              ]
            : null,
      ),
      child: Icon(widget.icon, size: widget.head ? 17 : 13, color: color),
    );

    final c = _c;
    if (!widget.breathing || c == null) return node(widget.head ? 0.4 : 0);
    final eased = CurvedAnimation(parent: c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: eased,
      builder: (context, _) => node(eased.value),
    );
  }
}

// ─── Head: current status hero ───────────────────────────────────────

/// Actor line prefix for the hero ("Approved by", "Submitted by", …).
String _actorPrefix(String status) => switch (status) {
  'pending' => 'Created by',
  'assigned' => 'Assigned by',
  'started' => 'Started by',
  'completed' => 'Completed by',
  'waitingReview' => 'Submitted by',
  'approved' => 'Approved by',
  'rejected' => 'Requested by',
  'missed' => 'Marked missed by',
  'cancelled' => 'Cancelled by',
  'note' || 'noteWarning' || 'noteIssue' => 'Note by',
  _ => 'By',
};

/// States whose head node breathes — the task is still moving.
bool _isLiveStatus(String status) => switch (status) {
  'pending' ||
  'assigned' ||
  'started' ||
  'completed' ||
  'waitingReview' ||
  'rejected' => true,
  _ => false,
};

class _HeadRow extends StatelessWidget {
  const _HeadRow({
    required this.entry,
    required this.actor,
    required this.media,
    required this.nextColor,
    required this.onTap,
  });

  final ActivityEntry entry;
  final UserEntity? actor;
  final List<TaskAttachment> media;

  /// Colour of the next (older) event — null when the head is the only event.
  final Color? nextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = activityColor(entry.status);
    final note = entry.note ?? '';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(95), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(26),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow + timestamp.
          Row(
            children: [
              Text(
                'CURRENT STATUS',
                style: AppTypography.caption.copyWith(
                  color: color.withAlpha(215),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${relativeTime(entry.at)} · ${clockTime(entry.at)}',
                style: AppTypography.caption,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            activityTitle(entry.status),
            style: AppTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Actor.
          Text(
            _actorPrefix(entry.status),
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _ActorFace(entry: entry, actor: actor),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  _displayName(entry, actor),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_roleLabel(entry, actor) case final role?) ...[
                const SizedBox(width: AppSpacing.sm),
                _RoleChip(label: role),
              ],
            ],
          ),
          // Note — the current state's message deserves a real callout.
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkSurface.withAlpha(160),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(46)),
              ),
              child: Text(
                '“$note”',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (media.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _MicroThumbs(media: media, size: 26),
          ],
        ],
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                _TimelineNode(
                  color: color,
                  icon: activityIcon(entry.status),
                  head: true,
                  breathing: _isLiveStatus(entry.status),
                ),
                if (nextColor != null)
                  Expanded(
                    child: _SpineSegment(
                      from: color,
                      to: nextColor!,
                      emphasis: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: nextColor != null ? AppSpacing.lg : 0,
              ),
              child: onTap == null
                  ? card
                  : InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: card,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History: compact ledger rows ────────────────────────────────────

String _displayName(ActivityEntry entry, UserEntity? actor) =>
    activityActorName(entry.actorId, entry.actorName, actor);

String? _roleLabel(ActivityEntry entry, UserEntity? actor) =>
    activityActorRole(entry.actorId, actor);

/// The actor's face on a timeline row. A person gets their photo/initials; the
/// **system** gets a glyph instead — initials ("SY") would read as a colleague
/// nobody at the branch has ever met.
class _ActorFace extends StatelessWidget {
  const _ActorFace({required this.entry, required this.actor, this.size = 22});

  final ActivityEntry entry;
  final UserEntity? actor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isSystemActorId(entry.actorId)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurfaceElevated,
          border: Border.all(color: AppColors.darkBorder),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.bolt_rounded,
          size: size * 0.62,
          color: AppColors.textSecondary,
        ),
      );
    }
    return actor != null
        ? UserAvatar.fromUser(actor!, size: size)
        : UserAvatar(name: _displayName(entry, actor), size: size);
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.entry,
    required this.actor,
    required this.media,
    required this.nextColor,
    required this.onTap,
  });

  final ActivityEntry entry;
  final UserEntity? actor;
  final List<TaskAttachment> media;

  /// Colour of the next (older) rendered element; null on the last row.
  final Color? nextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = activityColor(entry.status);
    final note = entry.note ?? '';
    // Neutral events keep a readable white title; coloured states wear their hue.
    final neutral =
        color == AppColors.textTertiary || color == AppColors.textSecondary;
    final titleColor = neutral ? AppColors.textPrimary : color;

    final name = _displayName(entry, actor);
    final role = _roleLabel(entry, actor);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityTitle(entry.status),
                    style: AppTypography.label.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ActorFace(entry: entry, actor: actor, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          role != null ? '$name · $role' : name,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Relative + exact clock time, right-aligned.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime(entry.at), style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(
                  clockTime(entry.at),
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 2, top: 1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
        // Note — a quiet quote with a state-coloured accent edge.
        if (note.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 7),
            padding: const EdgeInsets.only(left: 10, top: 1, bottom: 1),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color.withAlpha(120), width: 2),
              ),
            ),
            child: Text(
              '“$note”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        if (media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: _MicroThumbs(media: media, size: 20),
          ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                _TimelineNode(color: color, icon: activityIcon(entry.status)),
                if (nextColor != null)
                  Expanded(
                    child: _SpineSegment(from: color, to: nextColor!),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: nextColor != null ? AppSpacing.lg : 0,
              ),
              child: onTap == null
                  ? content
                  : InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: content,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folded-history affordance — "Show N earlier events" on the rail.
class _ShowMoreRow extends StatelessWidget {
  const _ShowMoreRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _railWidth,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.darkBorder),
                color: AppColors.darkSurfaceElevated,
              ),
              child: const Icon(
                Icons.unfold_more_rounded,
                size: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Show $count earlier event${count == 1 ? '' : 's'}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Micro media previews ────────────────────────────────────────────

/// Tiny inline previews for an event's media — up to three thumbnails, a "+N"
/// pill, and the "3 photos · 1 video" summary. The real gallery lives in the
/// submission sheet; the timeline only hints.
class _MicroThumbs extends StatelessWidget {
  const _MicroThumbs({required this.media, required this.size});

  final List<TaskAttachment> media;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = media.take(3).toList();
    final extra = media.length - shown.length;
    return Row(
      children: [
        for (final a in shown)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: a.type.isImage
                  ? Image.network(
                      a.url,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      cacheWidth: 96,
                      errorBuilder: (_, _, _) => _fallback(),
                    )
                  : _fallback(video: true),
            ),
          ),
        if (extra > 0)
          Container(
            height: size,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              '+$extra',
              style: AppTypography.caption.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            attachmentSummary(media),
            style: AppTypography.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _fallback({bool video = false}) => Container(
    width: size,
    height: size,
    color: AppColors.darkSurfaceElevated,
    child: Icon(
      video ? Icons.play_arrow_rounded : Icons.image_outlined,
      size: size * 0.55,
      color: AppColors.textSecondary,
    ),
  );
}

// ─── Role chip ───────────────────────────────────────────────────────

/// Quiet hairline role pill ("ADMIN") — monochrome; the status colour already
/// carries the state, the chip only answers "who".
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.darkBorder),
        color: AppColors.darkSurface.withAlpha(120),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
