import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_picker.dart';

/// The reply composer pinned at the bottom of a case conversation. Text +
/// optional attachments. When the case is [closed] it becomes a read-only
/// banner (requirement: closed cases are read-only) with an optional Reopen
/// action for a recipient.
///
/// [onSend] returns whether the send **succeeded**: the composer only clears the
/// input on success, so a failed send never silently loses what the user typed.
class CaseComposer extends StatefulWidget {
  const CaseComposer({
    super.key,
    required this.onSend,
    required this.sending,
    required this.closed,
    this.canReopen = false,
    this.onReopen,
  });

  final Future<bool> Function(String text, List<PickedAttachment> attachments)
      onSend;
  final bool sending;
  final bool closed;
  final bool canReopen;
  final VoidCallback? onReopen;

  @override
  State<CaseComposer> createState() => _CaseComposerState();
}

class _CaseComposerState extends State<CaseComposer> {
  final _controller = TextEditingController();
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);
  List<PickedAttachment> _pending = const [];
  bool _showAttach = false;

  /// Desktop only: Enter sends, Shift+Enter inserts a newline (premium chat
  /// ergonomics). Recomputed each build from the layout width.
  bool _enterToSend = false;

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_enterToSend &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (widget.sending) return;
    if (text.isEmpty && _pending.isEmpty) return;
    // Keep the text + attachments until the send resolves — only clear on
    // success, so a network/permission failure lets the user retry, not retype.
    final ok = await widget.onSend(text, _pending);
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() {
      _pending = const [];
      _showAttach = false;
    });
    // Keep the keyboard/caret ready for the next reply.
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.closed) return _ClosedBar(canReopen: widget.canReopen, onReopen: widget.onReopen);

    _enterToSend = context.isDesktop;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.sm,
          AppSpacing.pagePadding, AppSpacing.sm + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showAttach || _pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AttachmentPickerField(
                attachments: _pending,
                onChanged: (v) => setState(() => _pending = v),
                title: 'Attachments',
                hint: 'Add photos or a short video',
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach',
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: _showAttach
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _showAttach = !_showAttach),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: AppRadius.xlAll,
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextField(
                    controller: _controller,
                    focusNode: _node,
                    minLines: 1,
                    maxLines: 5,
                    style: AppTypography.body,
                    keyboardType: TextInputType.multiline,
                    textInputAction: _enterToSend
                        ? TextInputAction.newline
                        : TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _enterToSend ? null : (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.sending ? null : _send,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: widget.sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.onPrimary))
                        : const Icon(Icons.arrow_upward_rounded,
                            color: AppColors.onPrimary, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.canReopen, this.onReopen});
  final bool canReopen;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.pagePadding, AppSpacing.md,
          AppSpacing.pagePadding, AppSpacing.md + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('This case is closed — the conversation is read-only.',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ),
          if (canReopen && onReopen != null)
            TextButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reopen'),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }
}
