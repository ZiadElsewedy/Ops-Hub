import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_picker.dart';

/// The comment composer pinned at the bottom of a request detail. Text + optional
/// attachments. When the request is terminal ([locked]) it becomes a read-only
/// banner (a decided request is a record). Mirrors `CaseComposer`: [onSend]
/// returns whether the post succeeded, so the input only clears on success.
class RequestComposer extends StatefulWidget {
  const RequestComposer({
    super.key,
    required this.onSend,
    required this.sending,
    required this.locked,
    this.lockedLabel = 'This request is closed — comments are read-only.',
  });

  final Future<bool> Function(String text, List<PickedAttachment> attachments)
      onSend;
  final bool sending;
  final bool locked;
  final String lockedLabel;

  @override
  State<RequestComposer> createState() => _RequestComposerState();
}

class _RequestComposerState extends State<RequestComposer> {
  final _controller = TextEditingController();
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);
  List<PickedAttachment> _pending = const [];
  bool _showAttach = false;
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
    final ok = await widget.onSend(text, _pending);
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() {
      _pending = const [];
      _showAttach = false;
    });
    _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locked) return _LockedBar(label: widget.lockedLabel);

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
                      hintText: 'Add a comment…',
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

class _LockedBar extends StatelessWidget {
  const _LockedBar({required this.label});
  final String label;

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
            child: Text(label,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}
