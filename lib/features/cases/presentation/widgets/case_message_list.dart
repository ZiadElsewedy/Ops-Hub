import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/cases/domain/case_thread.dart';
import 'package:opshub/features/cases/domain/entities/case_entity.dart';
import 'package:opshub/features/cases/domain/entities/case_message.dart';
import 'package:opshub/features/cases/presentation/case_format.dart';
import 'package:opshub/features/task/presentation/activity_format.dart'
    show relativeTime;
import 'package:opshub/features/task/presentation/widgets/attachment_gallery.dart';

/// The case **conversation** — a premium chat/support thread. Real messages
/// render as left/right bubbles (mine vs the other party); status changes render
/// as quiet centered system chips; day changes get a date separator. Auto-scrolls
/// to the newest message as replies stream in.
class CaseMessageList extends StatefulWidget {
  const CaseMessageList({
    super.key,
    required this.caseItem,
    required this.messages,
    required this.currentUid,
    required this.iAmReporter,
  });

  /// The case being viewed — used to synthesize the opening message when the
  /// server-written one isn't present yet (see [caseThread]).
  final CaseEntity caseItem;

  final List<CaseMessage> messages;

  /// The signed-in user's uid — a message they authored aligns right.
  final String currentUid;

  /// True when the viewer is the case's reporter — so their de-identified
  /// confidential replies (empty authorId) still align to the right.
  final bool iAmReporter;

  @override
  State<CaseMessageList> createState() => _CaseMessageListState();
}

class _CaseMessageListState extends State<CaseMessageList> {
  final _controller = ScrollController();

  /// Within this distance of the end counts as "at the bottom" — new replies
  /// auto-scroll only when the reader is already here.
  static const _bottomThreshold = 240.0;

  bool _atBottom = true;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant CaseMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      // Don't yank a reader who has scrolled up to read history: only follow the
      // newest message when they're already at the bottom, or it's their own
      // reply. Otherwise surface a "New messages" pill they can tap.
      final newestMine =
          widget.messages.isNotEmpty && _isMine(widget.messages.last);
      if (_atBottom || newestMine) {
        _scrollToBottom();
      } else if (!_showJump) {
        setState(() => _showJump = true);
      }
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final atBottom =
        _controller.position.maxScrollExtent - _controller.offset <=
            _bottomThreshold;
    if (atBottom != _atBottom) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _showJump = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      if (_showJump && mounted) setState(() => _showJump = false);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  bool _isMine(CaseMessage m) =>
      m.authorId == widget.currentUid ||
      (widget.iAmReporter && m.authorRole == CaseAuthorRole.reporter);

  @override
  Widget build(BuildContext context) {
    final messages = caseThread(widget.messages, widget.caseItem);
    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet.', style: AppTypography.bodySmall),
      );
    }
    DateTime? lastDay;
    final children = <Widget>[];
    for (final m in messages) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        children.add(_DateSeparator(day: day));
        lastDay = day;
      }
      if (m.isSystem) {
        children.add(_SystemChip(message: m));
      } else {
        children.add(_Bubble(message: m, mine: _isMine(m)));
      }
    }
    return Stack(
      children: [
        ListView(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
              AppSpacing.lg, AppSpacing.pagePadding, AppSpacing.lg),
          children: children,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.md,
          child: _JumpToLatest(visible: _showJump, onTap: _scrollToBottom),
        ),
      ],
    );
  }
}

/// A floating "New messages" pill shown when a reply arrives while the reader is
/// scrolled up in the history. Tapping it animates back to the newest message.
class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Center(
            child: Material(
              color: AppColors.darkSurfaceElevated,
              elevation: 3,
              shadowColor: Colors.black54,
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.darkBorder),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('New messages',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final CaseMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final who = (message.authorName ?? '').trim();
    const tail = 4.0; // the flattened "tail" corner nearest the sender
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(mine ? AppRadius.lg : tail),
      bottomRight: Radius.circular(mine ? tail : AppRadius.lg),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine && who.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(who,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : AppColors.darkSurfaceElevated,
                borderRadius: radius,
                border: mine ? null : Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.hasText)
                    Text(
                      message.text!.trim(),
                      style: AppTypography.body
                          .copyWith(color: mine ? AppColors.onPrimary : null),
                    ),
                  if (message.hasAttachments) ...[
                    if (message.hasText) const SizedBox(height: AppSpacing.sm),
                    AttachmentGallery(attachments: message.attachments),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(relativeTime(message.createdAt),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({required this.message});
  final CaseMessage message;

  @override
  Widget build(BuildContext context) {
    final event = message.systemEvent ?? '';
    final color = caseSystemColor(event);
    final label = message.hasText ? message.text!.trim() : caseSystemLabel(event);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.fullAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(caseSystemIcon(event), size: 13, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppTypography.caption.copyWith(color: color)),
              Text('  ·  ${relativeTime(message.createdAt)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.day});
  final DateTime day;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return AppDateFormatter.monthDayYear(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(_label(),
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
      ),
    );
  }
}
