import 'package:flutter/material.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/features/chat/domain/entities/chat_message.dart';
import 'package:drop/features/chat/presentation/chat_message_preview.dart';

/// A read-only "Message info" screen — the metadata the backend actually
/// provides for one message, nothing invented. Pushed as a plain page (the
/// message object is passed directly, so no route serialization is needed).
///
/// The backend exposes a single delivery [ChatMessage.status] string
/// (`SENT` → `DELIVERED` → `READ`) rather than per-state timestamps, so this
/// screen shows the current status, not fabricated "delivered at / read at"
/// times. IDs are shown verbatim and are tap-to-copy for support/debugging.
class MessageInfoScreen extends StatelessWidget {
  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.mine,
    required this.senderLabel,
    this.replyAuthorLabel,
  });

  final ChatMessage message;
  final bool mine;

  /// Display name of the sender ("You" for own messages).
  final String senderLabel;

  /// Display name of the quoted message's author, when this is a reply.
  final String? replyAuthorLabel;

  static Future<void> push(
    BuildContext context, {
    required ChatMessage message,
    required bool mine,
    required String senderLabel,
    String? replyAuthorLabel,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessageInfoScreen(
          message: message,
          mine: mine,
          senderLabel: senderLabel,
          replyAuthorLabel: replyAuthorLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    final reply = message.replyTo;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: Text('Message info', style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          _MessagePreviewCard(message: message, mine: mine),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Delivery',
            children: [
              _InfoRow(label: 'Sender', value: senderLabel),
              _InfoRow(
                label: 'Sent',
                value: AppDateFormatter.dayMonthYearTime(message.createdAt),
              ),
              _InfoRow(label: 'Status', value: _statusLabel(message.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            title: 'Message',
            children: [
              _InfoRow(label: 'Type', value: _typeLabel(message.type.name)),
            ],
          ),
          if (attachment != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Attachment',
              children: [
                _InfoRow(label: 'Name', value: attachment.originalFilename),
                _InfoRow(label: 'Format', value: attachment.format),
                _InfoRow(label: 'Type', value: attachment.mimeType),
                _InfoRow(
                    label: 'Size', value: chatHumanBytes(attachment.byteSize)),
              ],
            ),
          ],
          if (reply != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'Replying to',
              children: [
                _InfoRow(label: 'Author', value: replyAuthorLabel ?? '—'),
                _InfoRow(
                  label: 'Message',
                  value: chatReplySnippet(
                    body: reply.body,
                    attachment: reply.attachment,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status.toUpperCase()) {
        'READ' => 'Read',
        'DELIVERED' => 'Delivered',
        'SENT' => 'Sent',
        'SENDING' => 'Sending…',
        'FAILED' => 'Failed to send',
        _ => status,
      };

  static String _typeLabel(String type) => switch (type.toLowerCase()) {
        'image' => 'Image',
        'document' => 'Document',
        _ => 'Text',
      };
}

class _MessagePreviewCard extends StatelessWidget {
  const _MessagePreviewCard({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final body = (message.body ?? '').trim();
    final text = body.isNotEmpty
        ? body
        : chatReplySnippet(body: null, attachment: message.attachment);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine ? 'Your message' : 'Received message',
            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
