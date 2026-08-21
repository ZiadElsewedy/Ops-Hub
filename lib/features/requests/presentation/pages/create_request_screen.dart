import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opshub/core/enums/request_type.dart';
import 'package:opshub/core/responsive/breakpoints.dart';
import 'package:opshub/core/extensions/context_extensions.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_radius.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/widgets/adaptive_scaffold.dart';
import 'package:opshub/core/widgets/premium_button.dart';
import 'package:opshub/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:opshub/features/requests/presentation/request_format.dart';
import 'package:opshub/core/media/picked_attachment.dart';
import 'package:opshub/features/task/presentation/widgets/attachment_picker.dart';

/// The fast, premium request-filing flow — pick a type, write one short
/// message/reason, optionally attach a photo, submit. Deliberately just two
/// clean steps (it should feel like sending a message that needs approval, not
/// filling a form). Reachable from `/requests/create`.
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key, this.initialType});

  /// A pre-chosen type (from a quick action) skips the picker straight to the form.
  final RequestType? initialType;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  RequestType? _type;
  final TextEditingController _message = TextEditingController();
  List<PickedAttachment> _attachments = const [];
  bool _submitting = false;

  bool get _valid => _message.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _message.addListener(() => setState(() {}));
    // Ensure the app-wide cubit knows the user (idempotent) so submit works even
    // when the create screen is the first requests surface visited.
    final user = context.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<RequestsListCubit>().load(user),
      );
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final type = _type;
    if (type == null || !_valid || _submitting) return;
    setState(() => _submitting = true);
    final created = await context.read<RequestsListCubit>().submitRequest(
          type: type,
          details: {'message': _message.text.trim()},
          attachments: _attachments,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) {
      context.showSuccess('Request submitted');
      Navigator.of(context).pop();
    } else {
      context.showError('Could not submit your request. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    return AdaptiveScaffold(
      title: type == null ? 'New Request' : type.label,
      subtitle: type == null
          ? 'What do you need your manager to approve?'
          : 'Add a short reason',
      contentMaxWidth: 640,
      leading: type != null && widget.initialType == null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() {
                _type = null;
                _message.clear();
                _attachments = const [];
              }),
            )
          : null,
      body: type == null ? _TypePicker(onPick: _pick) : _form(type),
    );
  }

  void _pick(RequestType type) => setState(() {
        _type = type;
        _message.clear();
        _attachments = const [];
      });

  Widget _form(RequestType type) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        _TypeSummary(type: type),
        const SizedBox(height: AppSpacing.xl),
        Text('Message to your manager',
            style: AppTypography.label.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tell your manager what you need, and why. Keep it short.',
            hintStyle:
                AppTypography.body.copyWith(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.darkSurface,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.darkBorder),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.primary.withAlpha(120)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AttachmentPickerField(
          attachments: _attachments,
          onChanged: (a) => setState(() => _attachments = a),
          title: 'Attachments',
          hint: 'Add a photo or short video (optional)',
        ),
        const SizedBox(height: AppSpacing.xxl),
        PremiumButton(
          label: _submitting ? 'Submitting…' : 'Submit request',
          icon: Icons.send_rounded,
          style: PremiumButtonStyle.filled,
          onPressed: (_valid && !_submitting) ? _submit : null,
        ),
      ],
    );
  }
}

class _TypeSummary extends StatelessWidget {
  const _TypeSummary({required this.type});
  final RequestType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(RequestFormat.icon(type),
                color: AppColors.textPrimary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label,
                    style: AppTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(type.blurb,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.onPick});
  final ValueChanged<RequestType> onPick;

  @override
  Widget build(BuildContext context) {
    // Phone/tablet → full-width rows: big touch targets, the blurb reads in
    // full, and rows size to their content so nothing can overflow. Desktop →
    // a card grid with a FIXED tile height (never an aspect ratio, which is
    // what let tiles overflow on narrow layouts).
    if (!context.isDesktop) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          // The mobile app bar has no subtitle slot, so the guiding question
          // leads the list instead.
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'What do you need your manager to approve?',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          for (final type in RequestType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TypeRow(type: type, onTap: () => onPick(type)),
            ),
        ],
      );
    }
    return GridView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        for (final type in RequestType.values)
          _TypeTileCard(type: type, onTap: () => onPick(type)),
      ],
    );
  }
}

/// The phone-tier picker row — icon tile, title + full blurb, chevron.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.onTap});
  final RequestType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(RequestFormat.icon(type),
                    color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: AppTypography.label.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(type.blurb,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTileCard extends StatelessWidget {
  const _TypeTileCard({required this.type, required this.onTap});
  final RequestType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.darkBorder),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(RequestFormat.icon(type),
                    color: AppColors.textPrimary, size: 20),
              ),
              const Spacer(),
              Text(type.label,
                  style: AppTypography.label.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(type.blurb,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textTertiary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
