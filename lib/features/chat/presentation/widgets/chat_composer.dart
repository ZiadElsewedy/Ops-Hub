import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/features/chat/domain/entities/chat_outgoing_attachment.dart';
import 'package:opshub/features/chat/presentation/chat_attachment_picker.dart';
import 'package:opshub/features/chat/presentation/chat_message_preview.dart';
import 'package:opshub/features/chat/presentation/widgets/chat_attachment_sheet.dart';

/// The message composer pinned at the bottom of a chat thread.
///
/// **Design: iMessage.** A single hairline-outlined capsule with a *transparent
/// interior* — the field is defined by its stroke, not by a filled slab. The
/// controls recede so the text column dominates: the attachment `+` is a bare
/// glyph (no disc, no background) on the leading edge, and the send control is
/// a small 30pt disc tucked 4pt inside the trailing edge. Nothing floats
/// outside the capsule; there is exactly one surface here.
///
/// Proportions are fixed and deliberate — the capsule is 38pt at rest with a
/// fully-round 19pt radius, so a 30pt send disc clears its stroke by 4pt on
/// every side. Focus brightens the stroke without thickening it (a width change
/// makes the whole bar jump, which reads as cheap).
///
/// [onSend] returns whether the send was accepted; the composer clears the
/// input and any staged attachment only then, so a rejected send never loses
/// what the user prepared. With optimistic sending this returns almost
/// immediately (the network resolves on the bubble), so the bar never blocks.
///
/// Desktop: the field autofocuses on mount and Enter sends (Shift+Enter →
/// newline). Mobile keeps the keyboard down until the user taps the field.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.sending,
    this.header,
    this.attachmentSource,
  });

  /// Sends the composed message. Returns whether it was accepted.
  final Future<bool> Function(String text, ChatOutgoingAttachment? attachment)
  onSend;

  final bool sending;

  /// Optional banner rendered above the input row, inside the composer surface
  /// (e.g. the "Replying to …" preview). Null → just the input row.
  final Widget? header;

  /// Source for the paperclip button. Null → attachments are unavailable and
  /// the `+` is hidden (e.g. in tests, or an unsupported platform).
  final ChatAttachmentSource? attachmentSource;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  /// The capsule's resting height. A 30pt send disc + 4pt inset top and bottom
  /// lands exactly here, so the disc is optically centred with no fudge factor.
  static const double _capsuleHeight = 38;

  /// Inset of the send disc from the capsule's stroke, on every side.
  static const double _sendInset = 4;
  static const double _sendDiameter = _capsuleHeight - (_sendInset * 2);

  final _controller = TextEditingController();
  late final FocusNode _node = FocusNode(onKeyEvent: _handleKey);

  bool _enterToSend = false;
  bool _autofocused = false;
  bool _picking = false;

  /// Whether the input holds focus — drives the stroke's brightening.
  bool _focused = false;

  /// The staged attachment awaiting send (preview shown above the input).
  ChatOutgoingAttachment? _pending;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _node.hasFocus != _focused) {
      setState(() => _focused = _node.hasFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
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

  bool get _canSend =>
      !widget.sending &&
      (_controller.text.trim().isNotEmpty || _pending != null);

  Future<void> _send() async {
    final text = _controller.text.trim();
    final attachment = _pending;
    if (widget.sending || (text.isEmpty && attachment == null)) return;
    final ok = await widget.onSend(text, attachment);
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() => _pending = null);
    _node.requestFocus();
  }

  Future<void> _pickAttachment() async {
    final source = widget.attachmentSource;
    if (source == null || _picking) return;
    final choice = await showChatAttachmentSheet(context);
    if (choice == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final picked = switch (choice) {
        ChatAttachmentChoice.camera => await source.pickCameraImage(),
        ChatAttachmentChoice.gallery => await source.pickGalleryImage(),
        ChatAttachmentChoice.document => await source.pickDocument(),
      };
      if (picked != null && mounted) setState(() => _pending = picked);
    } on UnsupportedAttachmentException catch (e) {
      if (mounted) context.showError(e.message);
    } catch (_) {
      if (mounted) context.showError('Could not attach that file.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _enterToSend = context.isDesktop;
    if (_enterToSend && !_autofocused) {
      _autofocused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _node.requestFocus();
      });
    }
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final showAttach = widget.attachmentSource != null;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + safeBottom),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        border: Border(
          top: BorderSide(
            color: AppColors.darkBorder.withValues(alpha: 0.7),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply banner + staged-attachment preview animate in above the
          // capsule.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.header ?? const SizedBox(width: double.infinity),
                if (_pending != null)
                  _PendingAttachmentPreview(
                    attachment: _pending!,
                    onRemove: () => setState(() => _pending = null),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: _capsuleHeight),
            decoration: BoxDecoration(
              // No fill. The stroke alone defines the field — this is the
              // single biggest difference from a filled-slab composer, and
              // what makes the bar read as light.
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_capsuleHeight / 2),
              // Brighten on focus, never thicken: a width change nudges every
              // child by half a pixel and the whole bar shivers.
              border: Border.all(
                color: _focused ? AppColors.textTertiary : AppColors.darkBorder,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The `+` lives INSIDE the stroke as a bare glyph. It is never
                // a detached satellite button — a loose +/field/send trio has
                // been rejected repeatedly; there is exactly one surface here.
                // Bottom-aligned so it tracks the last line as the field grows.
                if (showAttach)
                  _GlyphButton(
                    icon: Icons.add_rounded,
                    onTap: _picking ? null : _pickAttachment,
                  ),
                Expanded(
                  child: Padding(
                    // Generous lead-in when the glyph is absent; with the
                    // glyph present it already provides the lead-in.
                    padding: EdgeInsets.only(
                      left: showAttach ? 2 : 16,
                      right: 6,
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _node,
                      minLines: 1,
                      maxLines: 6,
                      style: AppTypography.body.copyWith(height: 1.3),
                      cursorColor: AppColors.primary,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: _enterToSend
                          ? TextInputAction.newline
                          : TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppTypography.body.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                        // The capsule IS the AnimatedContainer above; the
                        // field must draw no border of its own. Null out
                        // EVERY state explicitly — setting only `border`
                        // still lets the global inputDecorationTheme's
                        // focusedBorder leak through on focus, drawing a
                        // second bright outline around the text and
                        // breaking the single-capsule look.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: _enterToSend ? null : (_) => _send(),
                    ),
                  ),
                ),
                // Send animates in only with something to send, tucked
                // inside the stroke.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canSend = _canSend;
                    final show = canSend || widget.sending;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOut,
                      alignment: Alignment.centerRight,
                      child: show
                          ? Padding(
                              padding: const EdgeInsets.all(_sendInset),
                              child: _SendButton(
                                active: canSend,
                                sending: widget.sending,
                                diameter: _sendDiameter,
                                onTap: widget.sending ? null : _send,
                              ),
                            )
                          : const SizedBox(width: 10, height: _capsuleHeight),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A staged attachment shown above the input before sending — an image
/// thumbnail or a compact file row, with a remove affordance.
class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onRemove,
  });

  final ChatOutgoingAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.kind.isImage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  attachment.bytes,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalFilename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attachment.format.value} · '
                    '${chatHumanBytes(attachment.bytes.length)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textTertiary,
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove attachment',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a tappable control with a quick press-scale — the tactile "give" that
/// makes iMessage/Telegram controls feel physical. No-op when [onTap] is null.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.onTap, required this.child});
  final VoidCallback? onTap;
  final Widget child;
  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _down = false;
  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? 0.88 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A bare icon affordance — no disc, no background, no border. Sized to a
/// comfortable tap target while reading as a lone glyph, so it recedes beside
/// the capsule instead of competing with it.
class _GlyphButton extends StatelessWidget {
  const _GlyphButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: _ChatComposerState._capsuleHeight,
        child: Icon(icon, size: 26, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.active,
    required this.sending,
    required this.diameter,
    required this.onTap,
  });

  final bool active;
  final bool sending;
  final double diameter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.darkSurfaceElevated,
          shape: BoxShape.circle,
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 17,
                color: active ? AppColors.onPrimary : AppColors.textTertiary,
              ),
      ),
    );
  }
}
