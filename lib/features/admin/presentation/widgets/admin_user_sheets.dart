import 'package:flutter/material.dart';
import 'package:opshub/core/theme/app_colors.dart';
import 'package:opshub/core/theme/app_spacing.dart';
import 'package:opshub/core/theme/app_typography.dart';
import 'package:opshub/core/utils/validators.dart';
import 'package:opshub/core/widgets/app_dialog.dart';
import 'package:opshub/core/widgets/user_avatar.dart';
import 'package:opshub/features/auth/domain/entities/user_entity.dart';
import 'package:opshub/features/auth/presentation/widgets/app_button.dart';
import 'package:opshub/features/auth/presentation/widgets/app_text_field.dart';
import 'package:opshub/features/branch/domain/entities/branch_entity.dart';
import 'package:opshub/features/admin/domain/entities/user_compensation.dart';
import 'package:opshub/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:opshub/features/admin/presentation/widgets/compensation_fields.dart';

Future<void> showResetAccountSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _ResetAccountSheet(cubit: cubit, user: user));

Future<void> showEmploymentStatusSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _EmploymentStatusSheet(cubit: cubit, user: user));

Future<void> showAssignBranchSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _AssignBranchSheet(cubit: cubit, user: user));

Future<void> showPromoteManagerSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
}) =>
    _sheet(context, _PromoteManagerSheet(cubit: cubit));

Future<void> showSetPositionSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) =>
    _sheet(context, _SetPositionSheet(cubit: cubit, user: user));

/// Confirms and permanently deletes an account. Shared by every admin surface
/// that offers Delete (employee list, manager list, desktop inspector) so the
/// warning copy and the destructive confirmation never drift. The refreshed list
/// (the person disappears) is the success signal; a failure surfaces through the
/// list's error snackbar. Irreversible — hence the destructive confirm. Returns
/// `true` only when the delete was confirmed and dispatched (so a caller like the
/// inspector can close itself only then, not on cancel).
Future<bool> confirmAndDeleteAccount({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) async {
  final name = (user.displayName != null && user.displayName!.isNotEmpty)
      ? user.displayName!
      : user.email;
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete account',
    message:
        'Permanently delete $name. This removes their sign-in and takes them '
        'off the schedule and any open task (a task left with no one assigned '
        'is cancelled), drops pending swaps, requests and sales closes, and '
        'clears their notifications. Finished history is kept. This cannot be '
        'undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) return false;
  await cubit.deleteAccount(user);
  return true;
}

Future<void> showEditDetailsSheet({
  required BuildContext context,
  required AdminUsersCubit cubit,
  required UserEntity user,
}) async {
  // Compensation is private data (C2) — loaded on demand from the
  // subdocument so the sheet can prefill it (it is not on the user entity).
  final compensation =
      await cubit.compensationFor(user.uid) ?? UserCompensation.empty;
  if (!context.mounted) return;
  return _sheet(
      context,
      _EditDetailsSheet(cubit: cubit, user: user, compensation: compensation));
}

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.pagePadding,
          right: AppSpacing.pagePadding,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: child,
      ),
    );

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Text(text, style: AppTypography.h3),
      );
}

/// Loads active branches and exposes a single-select list. [selected] is the
/// chosen branch id (null = none). Shows a leading "No branch" option.
class _BranchSelector extends StatefulWidget {
  const _BranchSelector({
    required this.cubit,
    required this.selected,
    required this.onChanged,
  });
  final AdminUsersCubit cubit;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  State<_BranchSelector> createState() => _BranchSelectorState();
}

class _BranchSelectorState extends State<_BranchSelector> {
  late final Future<List<BranchEntity>> _future = widget.cubit.branches();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchEntity>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final branches = snap.data ?? const [];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            children: [
              _tile(label: 'No branch', value: null),
              for (final b in branches)
                _tile(
                  label: b.location == null || b.location!.isEmpty
                      ? b.name
                      : '${b.name} · ${b.location}',
                  value: b.id,
                ),
              if (branches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No active branches yet — create one first.',
                      style: AppTypography.caption),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile({required String label, required String? value}) {
    final selected = widget.selected == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : AppColors.textTertiary,
        size: 20,
      ),
      title: Text(label, style: AppTypography.label),
      onTap: () => widget.onChanged(value),
    );
  }
}

// ─── Reset account (new temp password + re-force change) ─────────
class _ResetAccountSheet extends StatefulWidget {
  const _ResetAccountSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_ResetAccountSheet> createState() => _ResetAccountSheetState();
}

class _ResetAccountSheetState extends State<_ResetAccountSheet> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _save() {
    final value = _password.text.trim();
    if (value.length < 6) return;
    widget.cubit.resetAccount(widget.user, value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Reset account'),
          Text(
            'Set a new temporary password for ${widget.user.email}. They will be '
            'forced to change it on next sign-in.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _password,
            label: 'Temporary password',
            hint: 'At least 6 characters',
            prefixIcon: Icons.lock_reset_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Reset account', onPressed: _save),
        ],
      ),
    );
  }
}

// ─── Employment status (HR label) ────────────────────────────────
class _EmploymentStatusSheet extends StatelessWidget {
  const _EmploymentStatusSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;

  static const _options = ['active', 'suspended', 'terminated'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Employment status'),
        const Text(
          'An HR record label. It does not block access on its own — use '
          'Deactivate to revoke sign-in.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final s in _options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              user.employmentStatus == s
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: user.employmentStatus == s
                  ? AppColors.primary
                  : AppColors.textTertiary,
              size: 20,
            ),
            title: Text(
              '${s[0].toUpperCase()}${s.substring(1)}',
              style: AppTypography.label,
            ),
            onTap: () {
              cubit.changeEmploymentStatus(user, s);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

// ─── Assign / change branch ──────────────────────────────────────
class _AssignBranchSheet extends StatefulWidget {
  const _AssignBranchSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_AssignBranchSheet> createState() => _AssignBranchSheetState();
}

class _AssignBranchSheetState extends State<_AssignBranchSheet> {
  late String? _branchId = widget.user.branchId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Assign branch'),
        _BranchSelector(
          cubit: widget.cubit,
          selected: _branchId,
          onChanged: (v) => setState(() => _branchId = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          onPressed: () {
            widget.cubit.changeBranch(widget.user, _branchId);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ─── Set job position ────────────────────────────────────────────
class _SetPositionSheet extends StatefulWidget {
  const _SetPositionSheet({required this.cubit, required this.user});
  final AdminUsersCubit cubit;
  final UserEntity user;
  @override
  State<_SetPositionSheet> createState() => _SetPositionSheetState();
}

class _SetPositionSheetState extends State<_SetPositionSheet> {
  late final _position =
      TextEditingController(text: widget.user.position ?? '');

  // Common retail positions — quick-fill chips (free text still allowed).
  static const _suggestions = ['Cashier', 'Supervisor', 'Stockist', 'Greeter'];

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _save() {
    final value = _position.text.trim();
    widget.cubit.changePosition(widget.user, value.isEmpty ? null : value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Job position'),
          const Text(
              'Drives shift-swap role compatibility when a branch requires '
              'same-role swaps. Leave empty for none.',
              style: AppTypography.caption),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _position,
            label: 'Position',
            hint: 'e.g. Cashier',
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final s in _suggestions)
                GestureDetector(
                  onTap: () => setState(() {
                    _position.text = s;
                    _position.selection = TextSelection.collapsed(
                        offset: _position.text.length);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Text(s, style: AppTypography.caption),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Save', onPressed: _save),
        ],
      ),
    );
  }
}

// ─── Edit contact details (name / phone / address / emergency) ───
class _EditDetailsSheet extends StatefulWidget {
  const _EditDetailsSheet({
    required this.cubit,
    required this.user,
    required this.compensation,
  });
  final AdminUsersCubit cubit;
  final UserEntity user;

  /// The private compensation record, pre-fetched by [showEditDetailsSheet].
  final UserCompensation compensation;
  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.user.displayName ?? '');
  late final _phone =
      TextEditingController(text: widget.user.phoneNumber ?? '');
  late final _address = TextEditingController(text: widget.user.address ?? '');
  late final _emergency =
      TextEditingController(text: widget.user.emergencyContact ?? '');
  late final _salaryAmount = TextEditingController(
      text: widget.compensation.salaryAmount == null
          ? ''
          : (widget.compensation.salaryAmount ==
                  widget.compensation.salaryAmount!.roundToDouble()
              ? widget.compensation.salaryAmount!.toStringAsFixed(0)
              : widget.compensation.salaryAmount.toString()));
  late final _paymentNumber =
      TextEditingController(text: widget.compensation.paymentNumber ?? '');
  late String? _salaryType = widget.compensation.salaryType;
  late String? _paymentMethod = widget.compensation.paymentMethod;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _emergency.dispose();
    _salaryAmount.dispose();
    _paymentNumber.dispose();
    super.dispose();
  }

  void _save() {
    // Fields are optional here (empty intentionally clears), but a non-empty
    // value is format-checked — a phone stays a number, a name stays letters.
    if (!_formKey.currentState!.validate()) return;
    final paymentNumber = _paymentNumber.text.trim();
    widget.cubit.updateDetails(
      widget.user,
      displayName: _name.text.trim(),
      phoneNumber: _phone.text.trim(),
      address: _address.text.trim(),
      emergencyContact: _emergency.text.trim(),
      writeCompensation: true,
      salaryAmount: double.tryParse(_salaryAmount.text.trim()),
      salaryType: _salaryType,
      paymentMethod: _paymentMethod,
      paymentNumber: paymentNumber.isEmpty ? null : paymentNumber,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Title('Edit details'),
            Text(
              'Contact information for ${widget.user.email}. Editable anytime — '
              'leave a field empty to clear it.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _name,
              label: 'Full name',
              hint: 'e.g. Ahmed Hassan',
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => Validators.name(v, required: false),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phone,
              label: 'Phone number',
              hint: 'e.g. +20 100 000 0000',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              inputFormatters: [Validators.phoneInput],
              validator: (v) => Validators.phone(v, required: false),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _address,
              label: 'Address',
              hint: 'Street, city',
              prefixIcon: Icons.home_outlined,
              validator: (v) => Validators.address(v, required: false),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _emergency,
              label: 'Emergency contact',
              hint: 'Name · phone',
              prefixIcon: Icons.emergency_outlined,
              validator: (v) => Validators.emergencyContact(v, required: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('COMPENSATION',
                style: AppTypography.caption.copyWith(letterSpacing: 1)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Salary and where it is sent. Only the payment number is '
              'visible to the employee (they can update it themselves).',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            CompensationFields(
              amount: _salaryAmount,
              paymentNumber: _paymentNumber,
              salaryType: _salaryType,
              paymentMethod: _paymentMethod,
              onSalaryType: (v) => setState(() => _salaryType = v),
              onPaymentMethod: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Save details', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// ─── Promote employee → manager ──────────────────────────────────
class _PromoteManagerSheet extends StatefulWidget {
  const _PromoteManagerSheet({required this.cubit});
  final AdminUsersCubit cubit;
  @override
  State<_PromoteManagerSheet> createState() => _PromoteManagerSheetState();
}

class _PromoteManagerSheetState extends State<_PromoteManagerSheet> {
  late final Future<List<UserEntity>> _future =
      widget.cubit.promotableEmployees();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Promote to manager'),
        const Text('Promote an existing employee to manager. Their current branch is '
            'kept — reassign it from the manager list if needed.',
            style: AppTypography.caption),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<UserEntity>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final employees = snap.data ?? const [];
            if (employees.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('No employees to promote.',
                    style: AppTypography.bodySmall),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employees.length,
                itemBuilder: (context, i) {
                  final u = employees[i];
                  final name = (u.displayName != null &&
                          u.displayName!.isNotEmpty)
                      ? u.displayName!
                      : u.email;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar.fromUser(u, size: 40),
                    title: Text(name, style: AppTypography.label),
                    subtitle: Text(u.email, style: AppTypography.caption),
                    onTap: () {
                      widget.cubit.promoteToManager(u);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
