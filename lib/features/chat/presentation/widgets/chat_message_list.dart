import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/app_date_formatter.dart';
import 'package:opshub/features/chat/domain/entities/chat_message.dart';
import 'package:opshub/features/chat/presentation/chat_message_preview.dart';
import 'package:opshub/features/task/presentation/activity_format.dart'
    show relativeTime;

/// The direct-chat thread — the [CaseMessageList] sibling. Messages arrive
/// ascending by `seq` (oldest first) and render bottom-anchored: left/right
/// bubbles (counterpart vs mine), day changes get a date separator, and the
/// list auto-follows the newest message unless the reader has scrolled up
/// (then a "New messages" pill appears instead — Cases convention).
///
/// Two chat-specific additions over Cases:
/// * **Scroll-back pagination** — nearing the top with older history available
///   fires [onLoadOlder]; a quiet spinner row shows while the page is in
///   flight, and the scroll position is preserved when it prepends.
/// * **Visible-read signal** — [onVisible] fires post-frame whenever messages
///   are actually on screen; the cubit's monotonic mark-read makes repeated
///   calls free.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.myUserId,
    this.hasMore = false,
    this.loadingOlder = false,
    this.onLoadOlder,
    this.onVisible,
    this.onMessageLongPress,
    this.onReply,
    this.onRetry,
    this.onImageTap,
    this.onDocumentTap,
    this.onDocumentDownload,
    this.onMessageSecondaryTap,
    this.imageUrlLoader,
    this.deletingMessageId,
    this.counterpartName,
    this.highlightQuery,
    this.activeMatchId,
  });

  /// Ascending by `seq` — oldest first.
  final List<ChatMessage> messages;

  /// The caller's backend-internal user id, when derivable. Null → own-message
  /// alignment isn't resolvable yet (deep link into a never-messaged thread);
  /// everything renders left-aligned until the first send resolves it.
  final String? myUserId;

  /// Whether older history exists beyond the loaded window.
  final bool hasMore;

  /// An older page is in flight (top spinner row).
  final bool loadingOlder;

  /// Fired when the reader nears the top and [hasMore] — load the next older
  /// page. The cubit no-ops re-entrant calls.
  final VoidCallback? onLoadOlder;

  /// Fired post-frame while messages are on screen — the mark-read signal.
  final VoidCallback? onVisible;

  /// Long-press on a bubble — opens the message context menu (the host owns
  /// the sheet + the action). Null → long-press does nothing.
  final void Function(ChatMessage message, bool mine)? onMessageLongPress;

  /// Swipe-right on a bubble — starts a reply to it (WhatsApp gesture).
  final void Function(ChatMessage message)? onReply;

  /// Tap on a failed optimistic bubble — re-sends it.
  final void Function(ChatMessage message)? onRetry;

  /// Tap on an image attachment — opens the full-screen viewer.
  final void Function(ChatMessage message)? onImageTap;

  /// Tap on a document attachment (or its hover "Open") — opens it.
  final void Function(ChatMessage message)? onDocumentTap;

  /// Hover "Download" on a document (desktop) — saves it to Downloads.
  final void Function(ChatMessage message)? onDocumentDownload;

  /// Resolves a received image's brokered URL for its inline thumbnail.
  final Future<String?> Function(ChatMessage message)? imageUrlLoader;

  /// Right-click (secondary tap) on a bubble — opens the desktop context menu
  /// at the given global position.
  final void Function(ChatMessage message, bool mine, Offset globalPosition)?
      onMessageSecondaryTap;

  /// The message with a delete in flight — its bubble dims until it resolves.
  final String? deletingMessageId;

  /// Counterpart's display name — personalizes the empty state.
  final String? counterpartName;

  /// Active in-conversation search needle — matches are highlighted in text.
  /// Null / empty → no highlighting.
  final String? highlightQuery;

  /// The id of the current search match to keep in view + emphasize.
  final String? activeMatchId;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final _controller = ScrollController();

  /// Within this distance of the end counts as "at the bottom" — new messages
  /// auto-scroll only when the reader is already here.
  static const _bottomThreshold = 240.0;

  /// Within this distance of the top triggers the older-page load.
  static const _topThreshold = 120.0;

  bool _atBottom = true;
  bool _showJump = false;

  /// True while the reader is actively dragging the list. The open-on-newest
  /// re-pin is suppressed during a drag so it never yanks a reader scrolling up
  /// before they cross the "at bottom" threshold.
  bool _userDragging = false;

  /// Attached to the active search-match bubble so it can be scrolled into view.
  final GlobalKey _activeMatchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _scrollToBottom(animated: false);
    _notifyVisible();
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.isEmpty) return;

    final grew = widget.messages.length > oldWidget.messages.length;
    final prepended =
        grew &&
        oldWidget.messages.isNotEmpty &&
        widget.messages.first.id != oldWidget.messages.first.id;
    final appended =
        grew &&
        (oldWidget.messages.isEmpty ||
            widget.messages.last.id != oldWidget.messages.last.id);

    if (prepended) {
      _preserveOffsetAfterPrepend();
    }
    if (appended) {
      // Don't yank a reader who has scrolled up to read history: follow the
      // newest message only when they're already at the bottom, or it's their
      // own send. Otherwise surface a "New messages" pill.
      final newestMine = _isMine(widget.messages.last);
      if (_atBottom || newestMine) {
        _scrollToBottom();
      } else if (!_showJump) {
        setState(() => _showJump = true);
      }
    }
    if (grew || oldWidget.messages.isEmpty) _notifyVisible();

    // Jump to the current search match when it changes.
    if (widget.activeMatchId != null &&
        widget.activeMatchId != oldWidget.activeMatchId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _activeMatchKey.currentContext;
        if (mounted && ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            alignment: 0.4,
          );
        }
      });
    }
  }

  /// An older page was prepended above the viewport — the list grew upward, so
  /// keep the message the reader was looking at exactly where it was by
  /// re-applying the pre-layout offset plus the extent the page added.
  void _preserveOffsetAfterPrepend() {
    if (!_controller.hasClients) return;
    final oldMax = _controller.position.maxScrollExtent;
    final oldOffset = _controller.offset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final delta = _controller.position.maxScrollExtent - oldMax;
      if (delta > 0) _controller.jumpTo(oldOffset + delta);
    });
  }

  void _notifyVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.messages.isNotEmpty) widget.onVisible?.call();
    });
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (widget.hasMore &&
        !widget.loadingOlder &&
        position.pixels <= _topThreshold) {
      widget.onLoadOlder?.call();
    }
    final atBottom =
        position.maxScrollExtent - position.pixels <= _bottomThreshold;
    if (atBottom != _atBottom) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _showJump = false;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final target = _controller.position.maxScrollExtent;
      if (animated) {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _controller.jumpTo(target);
      }
      if (_showJump && mounted) setState(() => _showJump = false);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  bool _isMine(ChatMessage m) =>
      // An optimistic local bubble is always the caller's own send, even before
      // `myUserId` has resolved from the first server round-trip.
      m.id.startsWith('local:') ||
      (widget.myUserId != null && m.senderId == widget.myUserId);

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return _EmptyThread(counterpartName: widget.counterpartName);
    }

    // Precompute lightweight row specs (no widgets, no image fetches) so the
    // grouping/date-separator/tail decisions — which need each row's neighbours
    // — stay correct, while the actual bubbles (and their lazy image broker
    // calls) are built on demand by ListView.builder for visible rows only.
    final rows = _buildRows(widget.messages);

    return Stack(
      children: [
        // Track user-initiated drags so the open-on-newest re-pin below never
        // fights a reader scrolling up.
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _userDragging = true;
            } else if (n is ScrollEndNotification) {
              _userDragging = false;
            }
            return false;
          },
          // Opening a thread must land on the NEWEST message. A single
          // jump-to-bottom on the first frame isn't always enough: viewport
          // metrics can still change afterwards (for example keyboard or
          // window resizing). Image thumbnails use a fixed footprint, so image
          // decoding is deliberately no longer one of those changes.
          // ScrollMetricsNotification fires when the extent changes without a
          // user scroll — re-pin to the new bottom, but ONLY while the reader is
          // already at the bottom AND is not actively dragging (otherwise the
          // re-pin yanks a reader who is scrolling up before they cross the
          // "at bottom" threshold).
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (_atBottom &&
                  !_userDragging &&
                  metrics.maxScrollExtent - metrics.pixels > 1) {
                _scrollToBottom(animated: false);
              }
              return false;
            },
            child: ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.lg,
                AppSpacing.pagePadding,
                AppSpacing.lg,
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) => _buildRow(rows[index]),
            ),
          ),
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

  /// Flattens the message list into ordered row specs: a leading older-page
  /// spinner when loading, date separators at day boundaries, and one spec per
  /// message carrying its precomputed side/tail/reply-author. Cheap — no widget
  /// construction here.
  List<_RowSpec> _buildRows(List<ChatMessage> msgs) {
    final rows = <_RowSpec>[
      if (widget.loadingOlder) const _SpinnerRow(),
    ];
    DateTime? lastDay;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        rows.add(_SeparatorRow(day));
        lastDay = day;
      }
      final mine = _isMine(m);
      final rp = m.replyTo;
      final replyAuthorLabel = rp == null
          ? null
          : (rp.senderId == widget.myUserId
              ? 'You'
              : (widget.counterpartName ?? 'Them'));
      // Group by SIDE (ownership), not raw senderId: a 1:1 thread has exactly
      // two participants, and grouping on `mine` also folds an optimistic
      // `local:` bubble — whose senderId may not have resolved yet — into my
      // own run. Only the last message of a consecutive same-side, same-day run
      // is a "tail": it carries the timestamp and the flattened corner and gets
      // the roomy between-groups gap; earlier bubbles in the run sit tight. A
      // side change therefore always forces a tail + gap, so two people's runs
      // can never visually merge.
      final next = i + 1 < msgs.length ? msgs[i + 1] : null;
      final nextSameDay = next != null &&
          next.createdAt.year == m.createdAt.year &&
          next.createdAt.month == m.createdAt.month &&
          next.createdAt.day == m.createdAt.day;
      final isTail = next == null || _isMine(next) != mine || !nextSameDay;
      rows.add(_MessageRow(
        message: m,
        mine: mine,
        isTail: isTail,
        replyAuthorLabel: replyAuthorLabel,
      ));
    }
    return rows;
  }

  /// Builds the widget for a single row spec. Called lazily by
  /// [ListView.builder], so a bubble's image broker call / download only fires
  /// when that row scrolls into view.
  Widget _buildRow(_RowSpec row) {
    switch (row) {
      case _SpinnerRow():
        return const _OlderPageSpinner();
      case _SeparatorRow(:final day):
        return _DateSeparator(day: day);
      case _MessageRow(
          :final message,
          :final mine,
          :final isTail,
          :final replyAuthorLabel,
        ):
        final m = message;
        final isActiveMatch =
            widget.activeMatchId != null && m.id == widget.activeMatchId;
        // RepaintBoundary isolates each bubble: a list-wide rebuild (a new
        // message, a read receipt, an upload-progress tick) or the swipe-to-reply
        // translate then can't force every other bubble to re-rasterize.
        final bubble = RepaintBoundary(
          child: _Bubble(
            message: m,
            mine: mine,
            isTail: isTail,
            replyAuthorLabel: replyAuthorLabel,
            deleting: m.id == widget.deletingMessageId,
            highlightQuery: widget.highlightQuery,
            isActiveMatch: isActiveMatch,
            onLongPress: widget.onMessageLongPress == null
                ? null
                : () => widget.onMessageLongPress!(m, mine),
            onRetry: widget.onRetry == null ? null : () => widget.onRetry!(m),
            onImageTap:
                widget.onImageTap == null ? null : () => widget.onImageTap!(m),
            onDocumentTap: widget.onDocumentTap == null
                ? null
                : () => widget.onDocumentTap!(m),
            onDocumentDownload: widget.onDocumentDownload == null
                ? null
                : () => widget.onDocumentDownload!(m),
            imageUrlLoader: widget.imageUrlLoader == null
                ? null
                : () => widget.imageUrlLoader!(m),
          ),
        );
        // Swipe-right to reply — never on a tombstone or an unsent local bubble.
        final canSwipeReply = widget.onReply != null &&
            !m.deletedForEveryone &&
            !m.id.startsWith('local:');
        // Keyed by message id so an element follows its message across
        // prepends/appends — the entrance animation then fires only for a
        // genuinely new bubble, never re-running on an existing one.
        //
        // Side alignment is enforced HERE by an Align, not by the bubble's
        // inner Column: the swipe-to-reply wrapper is a Stack that shrink-wraps
        // to the bubble, which collapses any `crossAxisAlignment` and was
        // pinning my own (swipe-enabled) messages to the left. Aligning the
        // whole item is robust across both the swipe and non-swipe paths.
        return KeyedSubtree(
          key: ValueKey(m.id),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: KeyedSubtree(
              key: isActiveMatch ? _activeMatchKey : null,
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onSecondaryTapDown: widget.onMessageSecondaryTap == null
                    ? null
                    : (d) => widget.onMessageSecondaryTap!(
                        m, mine, d.globalPosition),
                child: canSwipeReply
                    ? _SwipeToReply(
                        onReply: () => widget.onReply!(m), child: bubble)
                    : bubble,
              ),
            ),
          ),
        );
    }
  }
}

/// Ordered row descriptors for the lazy message list — a leading older-page
/// spinner, day-boundary separators, and per-message rows with their
/// precomputed side/tail/reply-author (grouping decisions that need neighbours).
sealed class _RowSpec {
  const _RowSpec();
}

class _SpinnerRow extends _RowSpec {
  const _SpinnerRow();
}

class _SeparatorRow extends _RowSpec {
  const _SeparatorRow(this.day);
  final DateTime day;
}

class _MessageRow extends _RowSpec {
  const _MessageRow({
    required this.message,
    required this.mine,
    required this.isTail,
    required this.replyAuthorLabel,
  });
  final ChatMessage message;
  final bool mine;
  final bool isTail;
  final String? replyAuthorLabel;
}

class _OlderPageSpinner extends StatelessWidget {
  const _OlderPageSpinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.md),
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    this.isTail = true,
    this.replyAuthorLabel,
    this.deleting = false,
    this.highlightQuery,
    this.isActiveMatch = false,
    this.onLongPress,
    this.onRetry,
    this.onImageTap,
    this.onDocumentTap,
    this.onDocumentDownload,
    this.imageUrlLoader,
  });
  final ChatMessage message;
  final bool mine;

  /// In-conversation search needle to highlight in the body; null → none.
  final String? highlightQuery;

  /// This bubble is the current search match (emphasized outline).
  final bool isActiveMatch;

  /// Tap handler for a failed optimistic bubble (re-send) and for an image
  /// attachment (open full-screen). Null → the respective tap is inert.
  final VoidCallback? onRetry;
  final VoidCallback? onImageTap;

  /// Open / download handlers for a document attachment.
  final VoidCallback? onDocumentTap;
  final VoidCallback? onDocumentDownload;

  /// Resolves this message's received-image URL for the inline thumbnail.
  final Future<String?> Function()? imageUrlLoader;

  /// Display label for the author of the quoted (replied-to) message, when
  /// this message is a reply — "You" or the counterpart's name.
  final String? replyAuthorLabel;

  /// Last message of a consecutive same-sender run — shows the timestamp and
  /// the flattened "tail" corner; grouped (non-tail) bubbles are fully rounded
  /// and sit tight against the next.
  final bool isTail;

  /// A delete for this message is in flight — dimmed until it resolves.
  final bool deleting;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Soft, premium rounding with a single flattened "tail" corner on the last
    // bubble of a run, on the side nearest the sender (bottom-right for me,
    // bottom-left for the counterpart) — the iMessage/Telegram silhouette.
    const r = AppRadius.xl; // 20
    const tailR = 6.0;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(r),
      topRight: const Radius.circular(r),
      bottomLeft: Radius.circular(mine || !isTail ? r : tailR),
      bottomRight: Radius.circular(!mine || !isTail ? r : tailR),
    );
    final body = (message.body ?? '').trim();
    final tombstone = message.deletedForEveryone;
    final attachment = message.attachment;
    final sending = message.status == 'SENDING';
    final failed = message.status == 'FAILED';
    final isImage = attachment != null &&
        !tombstone &&
        (message.localBytes != null || attachment.kind.isImage);
    final isDoc = attachment != null && !tombstone && !isImage;
    // Cap bubble width so a short line doesn't stretch edge-to-edge on tablets
    // and large phones while still tracking the viewport on small ones.
    final maxBubbleWidth =
        math.min(MediaQuery.sizeOf(context).width * 0.76, 560.0);

    // A failed bubble re-sends on tap; an image opens the full-screen viewer;
    // a document opens with the platform default app.
    final VoidCallback? onTap = failed
        ? onRetry
        : (sending
            ? null
            : (isImage ? onImageTap : (isDoc ? onDocumentTap : null)));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Padding(
        // Tight gap within a group, roomier gap between senders/groups.
        padding: EdgeInsets.only(bottom: isTail ? AppSpacing.md : 3),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              // Dim while a delete resolves, and slightly while a send is in
              // flight, so "sending" reads as provisional.
              opacity: deleting ? 0.4 : (sending ? 0.7 : 1),
              duration: const Duration(milliseconds: 160),
              child: MouseRegion(
                // A pointer cursor on anything tappable (image, document, a
                // failed bubble) — the desktop affordance.
                cursor: onTap != null
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                child: GestureDetector(
                onLongPress: (deleting || sending) ? null : onLongPress,
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    // Docs sit directly on the bubble (no inner card), so the
                    // bubble itself is tighter — the compact Slack/WhatsApp-
                    // desktop row rather than a card-in-a-card.
                    padding: EdgeInsets.symmetric(
                      horizontal: isImage ? 4 : (isDoc ? 8 : 14),
                      vertical: isImage ? 4 : (isDoc ? 7 : 9),
                    ),
                    decoration: BoxDecoration(
                      color:
                          mine ? AppColors.primary : AppColors.darkSurfaceElevated,
                      borderRadius: radius,
                      border: isActiveMatch
                          ? Border.all(color: AppColors.primary, width: 2)
                          : (mine
                              ? null
                              : Border.all(color: AppColors.darkBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null && !tombstone) ...[
                          Padding(
                            padding: EdgeInsets.all(isImage ? 4 : 0),
                            child: _QuotedPreview(
                              mine: mine,
                              authorLabel: replyAuthorLabel ?? 'Them',
                              snippet: chatReplySnippet(
                                body: message.replyTo!.body,
                                attachment: message.replyTo!.attachment,
                              ),
                            ),
                          ),
                          if (body.isNotEmpty || attachment != null)
                            const SizedBox(height: 6),
                        ],
                        if (isImage || isDoc)
                          _SendableAttachment(
                            sending: sending,
                            progress: message.uploadProgress,
                            child: isImage
                                ? _ImageAttachment(
                                    bytes: message.localBytes,
                                    heroTag: 'chat-image-${message.id}',
                                    urlLoader: imageUrlLoader,
                                  )
                                : _FileCard(
                                    attachment: attachment,
                                    mine: mine,
                                    onOpen: sending ? null : onDocumentTap,
                                    onDownload:
                                        sending ? null : onDocumentDownload,
                                  ),
                          ),
                        if (body.isNotEmpty) ...[
                          if (attachment != null) const SizedBox(height: 6),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isImage ? 6 : 0,
                              vertical: isImage ? 2 : 0,
                            ),
                            child: _HighlightedText(
                              text: body,
                              query: tombstone ? null : highlightQuery,
                              baseStyle: AppTypography.body.copyWith(
                                color: tombstone
                                    ? (mine
                                        ? AppColors.onPrimary
                                            .withValues(alpha: 0.7)
                                        : AppColors.textTertiary)
                                    : (mine ? AppColors.onPrimary : null),
                                fontStyle:
                                    tombstone ? FontStyle.italic : null,
                              ),
                              mine: mine,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
            if (failed)
              _FailedFooter(onRetry: onRetry)
            else if (isTail)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relativeTime(message.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    // Delivery status on my own messages — monochrome ticks, or
                    // a clock while the optimistic send is still in flight.
                    if (mine && !tombstone) ...[
                      const SizedBox(width: 4),
                      _StatusTicks(status: message.status),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style swipe-to-reply: the bubble tracks a rightward drag, a reply
/// glyph fades/scales in behind its leading edge, a single haptic fires once
/// the trigger threshold is crossed, and the bubble springs back on release —
/// invoking [onReply] only if the threshold was reached.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});
  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 56;
  static const double _maxDrag = 80;

  // Created eagerly in initState (not lazily): a lazy `late final` would first
  // construct the controller inside dispose(), building a Ticker on an already-
  // deactivated element.
  late final AnimationController _springBack;
  double _dx = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _springBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    _springBack.stop();
    setState(() {
      _dx = (_dx + details.delta.dx).clamp(0.0, _maxDrag);
      if (!_armed && _dx >= _threshold) {
        _armed = true;
        HapticFeedback.mediumImpact();
      } else if (_armed && _dx < _threshold) {
        _armed = false;
      }
    });
  }

  void _onEnd(DragEndDetails details) {
    if (_armed) widget.onReply();
    _armed = false;
    final from = _dx;
    final anim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _springBack, curve: Curves.easeOutBack),
    );
    void tick() => setState(() => _dx = anim.value);
    anim.addListener(tick);
    _springBack.forward(from: 0).whenComplete(() {
      anim.removeListener(tick);
      _dx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          if (_dx > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * progress,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _armed
                              ? AppColors.primary
                              : AppColors.darkSurfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply_rounded,
                          size: 18,
                          color: _armed
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// An inline image attachment — a rounded thumbnail wrapped in a [Hero] so it
/// flies into the full-screen viewer on tap. Local bytes (an optimistic send)
/// render immediately; a received image lazily resolves its brokered URL via
/// [urlLoader] and shows it inline, falling back to a "Photo" placeholder while
/// loading or on failure.
class _ImageAttachment extends StatefulWidget {
  const _ImageAttachment({
    required this.bytes,
    required this.heroTag,
    this.urlLoader,
  });
  final Uint8List? bytes;
  final Object heroTag;
  final Future<String?> Function()? urlLoader;

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends State<_ImageAttachment> {
  /// Deliberately the footprint a portrait photo ALREADY occupied (the former
  /// `width: 240` + `maxHeight: 280`), so pinning the size buys scroll
  /// stability without shrinking anyone's photos. The stability comes from the
  /// box being fixed, not from it being small.
  static const _thumbnailSize = Size(240, 280);
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    if (widget.bytes == null) _url = widget.urlLoader?.call();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bytes;
    final Widget content;
    if (b != null) {
      content = Image.memory(b, fit: BoxFit.cover);
    } else if (_url != null) {
      content = FutureBuilder<String?>(
        future: _url,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _ImagePlaceholder(loading: true);
          }
          final url = snap.data;
          if (url == null || url.isEmpty) {
            return const _ImagePlaceholder(loading: false);
          }
          return Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const _ImagePlaceholder(loading: true),
            errorBuilder: (_, _, _) => const _ImagePlaceholder(loading: false),
          );
        },
      );
    } else {
      content = const _ImagePlaceholder(loading: false);
    }
    return Hero(
      tag: widget.heroTag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Attachment metadata deliberately has no image dimensions, so the
        // true aspect ratio cannot be known before the download. A fixed
        // thumbnail viewport is the only way to guarantee that decoding never
        // changes a message row's layout. The full-screen viewer remains the
        // uncropped route for the original photo.
        child: SizedBox.fromSize(
          size: _thumbnailSize,
          child: content,
        ),
      ),
    );
  }
}

/// The loading / unavailable state of an inline image (fixed footprint so the
/// bubble doesn't jump when the real image arrives).
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurface,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textTertiary),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_rounded,
                    size: 30, color: AppColors.textTertiary),
                const SizedBox(height: 6),
                Text(
                  'Photo',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Overlays an in-flight attachment with a progress ring while it uploads.
class _SendableAttachment extends StatelessWidget {
  const _SendableAttachment({
    required this.sending,
    required this.progress,
    required this.child,
  });

  final bool sending;
  final double? progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!sending) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              // Indeterminate until real progress arrives, then determinate.
              value: (progress == null || progress == 0) ? null : progress,
              strokeWidth: 2.5,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

/// The Material icon that best represents a document format.
IconData chatDocumentIcon(String format) {
  switch (format.toUpperCase()) {
    case 'PDF':
      return Icons.picture_as_pdf_rounded;
    case 'DOC':
    case 'DOCX':
    case 'TXT':
      return Icons.description_rounded;
    case 'XLS':
    case 'XLSX':
      return Icons.table_chart_rounded;
    case 'PPT':
    case 'PPTX':
      return Icons.slideshow_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

/// A compact document row — a format-icon tile, the filename, and a
/// `PDF • 577 KB` meta line — sitting **directly** on the bubble (no secondary
/// card surface), the Slack / WhatsApp-desktop silhouette. On a pointer device
/// (desktop), hovering reveals quiet **Open** / **Download** affordances; on
/// touch the whole bubble opens the file.
class _FileCard extends StatefulWidget {
  const _FileCard({
    required this.attachment,
    required this.mine,
    this.onOpen,
    this.onDownload,
  });
  final ChatMessageAttachment attachment;
  final bool mine;
  final VoidCallback? onOpen;
  final VoidCallback? onDownload;

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final onLight = widget.mine;
    final attachment = widget.attachment;
    final badge = attachment.format.toUpperCase();
    final fg = onLight ? AppColors.onPrimary : AppColors.textPrimary;
    final subFg = onLight
        ? AppColors.onPrimary.withValues(alpha: 0.6)
        : AppColors.textTertiary;
    final showActions = _hovered && widget.onOpen != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 250),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The one subtle surface: a small rounded glyph tile.
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: onLight
                    ? AppColors.onPrimary.withValues(alpha: 0.14)
                    : AppColors.darkSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(chatDocumentIcon(badge), size: 18, color: fg),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$badge • ${chatHumanBytes(attachment.byteSize)}',
                    style: AppTypography.caption
                        .copyWith(color: subFg, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Desktop hover actions — Open / Download. Never shown on touch
            // (MouseRegion only fires for a pointer device).
            AnimatedSize(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: showActions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 4),
                        _FileAction(
                          icon: Icons.open_in_new_rounded,
                          tooltip: 'Open',
                          color: fg,
                          onTap: widget.onOpen,
                        ),
                        if (widget.onDownload != null)
                          _FileAction(
                            icon: Icons.download_rounded,
                            tooltip: 'Download',
                            color: fg,
                            onTap: widget.onDownload,
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders message text with any in-conversation search matches highlighted.
/// Monochrome, tone-aware: a translucent dark wash on my white bubble, a
/// translucent light wash on the counterpart's dark bubble. Falls back to a
/// plain [Text] when there's no active query.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.baseStyle,
    required this.mine,
    this.query,
  });

  final String text;
  final TextStyle baseStyle;
  final bool mine;
  final String? query;

  @override
  Widget build(BuildContext context) {
    final q = (query ?? '').trim();
    if (q.isEmpty) return Text(text, style: baseStyle);

    final lowerText = text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    if (!lowerText.contains(lowerQuery)) return Text(text, style: baseStyle);

    final highlight = mine
        ? const Color(0x33000000) // dark wash on the white bubble
        : const Color(0x55FFFFFF); // light wash on the dark bubble
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = lowerText.indexOf(lowerQuery, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + q.length),
        style: TextStyle(
          backgroundColor: highlight,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = i + q.length;
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

/// A small icon affordance used in the document row's hover actions.
class _FileAction extends StatelessWidget {
  const _FileAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

/// The footer under a failed optimistic bubble — a quiet error line with a
/// retry affordance (the bubble itself is also tap-to-retry).
class _FailedFooter extends StatelessWidget {
  const _FailedFooter({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
      child: GestureDetector(
        onTap: onRetry,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 13, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Not delivered · Tap to retry',
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style delivery ticks for an own message: a clock while sending, a
/// double **grey** check once delivered, and a double **green** check once the
/// counterpart has read it.
///
/// Owner ruling 2026-07-24 explicitly overrides the earlier monochrome-ticks
/// decision: green is requested for the read state (the familiar messaging
/// pattern). The backend accepts a message as `SENT` and immediately delivers
/// it to the counterpart's socket, so `SENT`/`DELIVERED` both read as
/// "delivered"; `READ` arrives over the socket.
class _StatusTicks extends StatelessWidget {
  const _StatusTicks({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    // Optimistic in-flight send → a clock, not a check.
    if (s == 'SENDING') {
      return const Icon(
        Icons.access_time_rounded,
        size: 13,
        color: AppColors.textTertiary,
        semanticLabel: 'Sending',
      );
    }
    final read = s == 'READ';
    return Icon(
      Icons.done_all_rounded,
      size: 16,
      color: read ? AppColors.success : AppColors.textTertiary,
      semanticLabel: read ? 'Read' : 'Delivered',
    );
  }
}

/// The quoted-message block shown at the top of a reply bubble: an accent bar,
/// the quoted author, and a one-line snippet. Tinted to sit legibly on either
/// bubble surface — a dark tint on my white bubble, a light tint on the
/// counterpart's dark bubble.
class _QuotedPreview extends StatelessWidget {
  const _QuotedPreview({
    required this.mine,
    required this.authorLabel,
    required this.snippet,
  });

  final bool mine;
  final String authorLabel;
  final String snippet;

  @override
  Widget build(BuildContext context) {
    final bg = mine
        ? AppColors.onPrimary.withValues(alpha: 0.06)
        : const Color(0x14FFFFFF);
    final bar = mine
        ? AppColors.onPrimary.withValues(alpha: 0.45)
        : AppColors.textSecondary;
    final author = mine ? AppColors.onPrimary : AppColors.textSecondary;
    final snippetColor = mine
        ? AppColors.onPrimary.withValues(alpha: 0.65)
        : AppColors.textTertiary;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorLabel,
                    style: AppTypography.caption.copyWith(
                      color: author,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.caption.copyWith(color: snippetColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The empty-thread state — a quiet, premium invitation to start the chat,
/// personalized with the counterpart's name when known.
class _EmptyThread extends StatelessWidget {
  const _EmptyThread({this.counterpartName});
  final String? counterpartName;

  @override
  Widget build(BuildContext context) {
    final name = (counterpartName ?? '').trim();
    final title = name.isEmpty ? 'Say hello' : 'Say hello to ${name.split(' ').first}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.waving_hand_rounded,
                  size: 30, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'This is the beginning of your conversation.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A floating "New messages" pill shown when a message lands while the reader
/// is scrolled up in the history. Tapping it animates back to the newest.
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'New messages',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
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
        // A subtle centered pill (WhatsApp/Telegram rhythm) rather than bare
        // text — reads as a quiet divider between days.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            _label(),
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
