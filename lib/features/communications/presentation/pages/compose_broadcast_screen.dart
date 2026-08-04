import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/enums/broadcast_audience.dart';
import 'package:drop/core/enums/broadcast_category.dart';
import 'package:drop/core/enums/broadcast_recurrence.dart';
import 'package:drop/core/extensions/context_extensions.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/utils/app_date_formatter.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/app_search_field.dart';
import 'package:drop/core/widgets/app_snackbar.dart';
import 'package:drop/core/widgets/user_avatar.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/auth/presentation/widgets/app_button.dart';
import 'package:drop/features/auth/presentation/widgets/app_dropdown_field.dart';
import 'package:drop/features/auth/presentation/widgets/app_text_field.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/communications/domain/entities/broadcast_entity.dart';
import 'package:drop/features/communications/domain/entities/broadcast_schedule_entity.dart';
import 'package:drop/features/communications/domain/entities/broadcast_template_entity.dart';
import 'package:drop/features/communications/domain/broadcast_permissions.dart';
import 'package:drop/features/communications/domain/template_renderer.dart';
import 'package:drop/features/communications/presentation/communications_format.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_schedule_cubit.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_state.dart';
import 'package:drop/features/communications/presentation/pages/broadcast_templates_screen.dart';

/// Compose Broadcast (Phase 3). Role-gated form: audience (admin: everyone /
/// branch / individual · manager: own branch / individual-in-branch), an
/// optional branch + recipient picker, category, title, body, and a sticky
/// "Send Broadcast" CTA. Sending routes through `BroadcastCubit.send` (→ the
/// callable Cloud Function); the success snackbar reports the recipient count.
class ComposeBroadcastScreen extends StatefulWidget {
  const ComposeBroadcastScreen({super.key, this.prefill});

  /// When set (e.g. "Duplicate as editable draft"), seeds the form's text,
  /// category, audience, priority and channel from an existing broadcast.
  final BroadcastEntity? prefill;

  @override
  State<ComposeBroadcastScreen> createState() => _ComposeBroadcastScreenState();
}

class _ComposeBroadcastScreenState extends State<ComposeBroadcastScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  late final UserEntity _sender;
  late final List<BroadcastAudience> _allowed;
  late BroadcastAudience _audience;
  BroadcastCategory _category = BroadcastCategory.announcement;
  bool _sendsPush = true;

  List<BranchEntity> _branches = const [];
  BranchEntity? _selectedBranch; // admin's chosen branch (branch / individual)
  List<UserEntity> _users = const [];
  final Set<String> _selectedUsers = {}; // multi-select recipient uids
  bool _loadingUsers = false;
  String _userQuery = '';
  bool _submitting = false;

  /// Role filter for a branch / all-branches send ('all' = everyone).
  String _roleFilter = 'all';

  bool get _isAdmin => _sender.role.isAdmin;

  @override
  void initState() {
    super.initState();
    // The route guard guarantees an admin/manager reaches this screen.
    _sender = context.currentUser!;
    _allowed = BroadcastPermissions.allowedAudiences(_sender.role);
    _audience = _allowed.first;
    // Seed from a duplicated broadcast when provided.
    final p = widget.prefill;
    if (p != null) {
      _titleCtrl.text = p.title;
      _bodyCtrl.text = p.message;
      _category = BroadcastCategory.fromString(p.category);
      _sendsPush = p.sendsPush;
      if (_allowed.contains(p.audience)) _audience = p.audience;
    }
    _titleCtrl.addListener(_onFormChanged);
    _bodyCtrl.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final branches = await context.read<BroadcastCubit>().branches();
    if (!mounted) return;
    setState(() => _branches = branches);
    // A manager's individual recipients come from their own branch.
    if (!_isAdmin && _audience == BroadcastAudience.user) {
      _loadUsers(_sender.branchId ?? '');
    }
  }

  void _onFormChanged() => setState(() {});

  Future<void> _loadUsers(String branchId) async {
    setState(() {
      _loadingUsers = true;
      _users = const [];
      _selectedUsers.clear();
    });
    final users = await context.read<BroadcastCubit>().branchUsers(branchId);
    if (!mounted) return;
    setState(() {
      // Don't offer the sender as a recipient of their own message.
      _users = users.where((u) => u.uid != _sender.uid).toList();
      _loadingUsers = false;
    });
  }

  void _selectAudience(BroadcastAudience a) {
    setState(() {
      _audience = a;
      _selectedUsers.clear();
      _userQuery = '';
    });
    if (a == BroadcastAudience.user && !_isAdmin) {
      _loadUsers(_sender.branchId ?? '');
    }
  }

  /// The branch id a recipient list / branch send targets.
  String get _targetBranchId =>
      _isAdmin ? (_selectedBranch?.id ?? '') : (_sender.branchId ?? '');

  String? get _ownBranchName {
    for (final b in _branches) {
      if (b.id == _sender.branchId) return b.name;
    }
    return null;
  }

  /// The single selected recipient (when exactly one is picked), else null.
  UserEntity? get _singleSelectedUser {
    if (_selectedUsers.length != 1) return null;
    for (final u in _users) {
      if (u.uid == _selectedUsers.first) return u;
    }
    return null;
  }

  String? _userBranch(String? uid) {
    if (uid == null) return null;
    for (final u in _users) {
      if (u.uid == uid) return u.branchId;
    }
    return null;
  }

  bool get _canSend {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      return false;
    }
    switch (_audience) {
      case BroadcastAudience.allBranches:
        return true;
      case BroadcastAudience.branch:
        return _isAdmin ? _selectedBranch != null : true;
      case BroadcastAudience.user:
      case BroadcastAudience.custom:
        return _selectedUsers.isNotEmpty;
    }
  }

  List<UserEntity> get _filteredUsers {
    if (_userQuery.isEmpty) return _users;
    final q = _userQuery.toLowerCase();
    return _users
        .where(
          (u) =>
              (u.displayName ?? '').toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _send() async {
    setState(() => _submitting = true);
    // A people-pick of one sends as a direct message (user); two or more as a
    // multi-recipient custom broadcast.
    final people = _selectedUsers.toList();
    final isPeople = _audience == BroadcastAudience.user;
    final sendAudience = isPeople && people.length > 1
        ? BroadcastAudience.custom
        : _audience;
    final singleUid = isPeople && people.length == 1 ? people.first : null;
    final isBranchOrAll =
        _audience == BroadcastAudience.branch ||
        _audience == BroadcastAudience.allBranches;

    final count = await context.read<BroadcastCubit>().send(
      sender: _sender,
      title: _titleCtrl.text,
      message: _bodyCtrl.text,
      audience: sendAudience,
      branchId: _audience == BroadcastAudience.branch ? _targetBranchId : null,
      targetUserId: singleUid,
      targetUserBranchId: _userBranch(singleUid),
      targetUserIds: sendAudience == BroadcastAudience.custom
          ? people
          : const [],
      roleFilter: isBranchOrAll ? _roleFilter : '',
      category: _category.value,
      sendsPush: _sendsPush,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (count != null) {
      AppSnackbar.success(
        context,
        'Broadcast sent to $count ${count == 1 ? 'recipient' : 'recipients'}',
      );
      context.pop();
    }
    // On failure the cubit emits an error → surfaced by the BlocListener below.
  }

  /// Opens the scheduling sheet and creates a `broadcastSchedules` entry (the
  /// Cloud Function fires it). Reuses the same audience derivation as [_send].
  Future<void> _scheduleSend() async {
    final cfg = await showModalBottomSheet<_ScheduleConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ScheduleSheet(),
    );
    if (cfg == null || !mounted) return;

    final people = _selectedUsers.toList();
    final isPeople = _audience == BroadcastAudience.user;
    final sendAudience = isPeople && people.length > 1
        ? BroadcastAudience.custom
        : _audience;
    final isBranchOrAll =
        _audience == BroadcastAudience.branch ||
        _audience == BroadcastAudience.allBranches;

    final entity = BroadcastScheduleEntity(
      id: '',
      title: _titleCtrl.text.trim(),
      message: _bodyCtrl.text.trim(),
      category: _category,
      sendsPush: _sendsPush,
      audience: sendAudience,
      branchId: _audience == BroadcastAudience.branch ? _targetBranchId : null,
      roleFilter: isBranchOrAll ? _roleFilter : 'all',
      senderId: _sender.uid,
      senderName: _sender.displayName ?? _sender.email,
      senderRole: _sender.role,
      recurrenceType: cfg.recurrence,
      interval: cfg.interval,
      startDate: cfg.startAt,
      endDate: cfg.endDate,
      nextRunAt: cfg.startAt,
    );

    await context.read<BroadcastScheduleCubit>().create(
      entity,
      targetUserIds: sendAudience == BroadcastAudience.custom
          ? people
          : const [],
    );
    if (!mounted) return;
    AppSnackbar.success(context, 'Broadcast scheduled');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'New Broadcast',
      subtitle: 'Send a message to your team',
      actions: [
        IconButton(
          tooltip: 'Schedule for later',
          onPressed: _canSend ? _scheduleSend : null,
          icon: Icon(
            Icons.schedule_rounded,
            color: _canSend ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
        TextButton.icon(
          onPressed: _useTemplate,
          icon: const Icon(
            Icons.dashboard_customize_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          label: Text(
            'Templates',
            style: AppTypography.label.copyWith(color: AppColors.primary),
          ),
        ),
      ],
      bottomBar: _SendBar(
        enabled: _canSend && !_submitting,
        loading: _submitting,
        onSend: _send,
      ),
      body: BlocListener<BroadcastCubit, BroadcastState>(
        listener: (context, state) =>
            state.whenOrNull(error: (m) => AppSnackbar.error(context, m)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.lg,
            AppSpacing.pagePadding,
            AppSpacing.xl,
          ),
          children: [
            const _Label('Title'),
            AppTextField(
              controller: _titleCtrl,
              label: 'Broadcast title',
              hint: 'e.g. Stock count tonight',
              textInputAction: TextInputAction.next,
            ),
            _Counter(length: _titleCtrl.text.length, max: 80),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Message'),
            AppTextField(
              controller: _bodyCtrl,
              label: 'Write your message',
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
            _Counter(length: _bodyCtrl.text.length, max: 500),
            const SizedBox(height: AppSpacing.xl),
            const _Label('Delivery'),
            _deliverySelector(),
            const SizedBox(height: AppSpacing.lg),
            const _Label('Audience'),
            _audienceSelector(),
            ..._audienceTarget(),
            const SizedBox(height: AppSpacing.xl),
            const _Label('Category'),
            _categorySelector(),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const _Label('Preview'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _canSend ? _saveAsTemplate : null,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save as template'),
                ),
              ],
            ),
            _PreviewCard(
              title: _titleCtrl.text,
              message: _bodyCtrl.text,
              category: _category,
              sendsPush: _sendsPush,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Template integration ──────────────────────────────────────
  /// Opens the template library as a picker; applies the chosen template
  /// (rendering `{{placeholders}}` with the current context).
  Future<void> _useTemplate() async {
    final picked = await context.push<BroadcastTemplateEntity?>(
      RouteNames.communicationsTemplates,
      extra: 'pick',
    );
    if (picked == null || !mounted) return;
    final ctx = _placeholderContext();
    setState(() {
      _titleCtrl.text = TemplateRenderer.render(picked.title, ctx);
      _bodyCtrl.text = TemplateRenderer.render(picked.message, ctx);
      _category = picked.category;
    });
  }

  /// Opens the template editor seeded from the current draft.
  void _saveAsTemplate() {
    showTemplateEditor(
      context,
      prefill: BroadcastTemplateEntity(
        id: '',
        title: _titleCtrl.text.trim(),
        message: _bodyCtrl.text.trim(),
        category: _category,
      ),
    );
  }

  /// The placeholder values available in the composer (recipient/branch/date).
  Map<String, String> _placeholderContext() {
    final now = DateTime.now();
    final date = AppDateFormatter.numeric(now);
    final branchName = _selectedBranch?.name ?? _ownBranchName ?? '';
    final employeeName = _singleSelectedUser?.displayName ?? '';
    return {
      'sender_name': _sender.displayName ?? _sender.email,
      'date': date,
      if (branchName.isNotEmpty) 'branch_name': branchName,
      if (employeeName.isNotEmpty) 'employee_name': employeeName,
    };
  }

  Widget _audienceSelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in _allowed)
          _Choice(
            icon: audienceIcon(a),
            label: _audienceChoiceLabel(a),
            selected: _audience == a,
            onTap: () => _selectAudience(a),
          ),
      ],
    );
  }

  String _audienceChoiceLabel(BroadcastAudience a) => switch (a) {
    BroadcastAudience.allBranches => 'Everyone',
    BroadcastAudience.branch => 'Branch',
    BroadcastAudience.user => 'People',
    BroadcastAudience.custom => 'People',
  };

  /// The audience-specific picker (branch selector / role filter / people picker).
  List<Widget> _audienceTarget() {
    switch (_audience) {
      case BroadcastAudience.allBranches:
        return [
          const SizedBox(height: AppSpacing.md),
          const _Hint(
            'Every active user across all branches will be notified.',
          ),
          const SizedBox(height: AppSpacing.md),
          _roleSelector(),
        ];
      case BroadcastAudience.branch:
        return [
          const SizedBox(height: AppSpacing.md),
          if (_isAdmin)
            AppDropdownField<BranchEntity>(
              value: _selectedBranch,
              hint: 'Select a branch',
              prefixIcon: Icons.store_mall_directory_outlined,
              items: [
                for (final b in _branches)
                  DropdownMenuItem(value: b, child: Text(b.name)),
              ],
              onChanged: (b) => setState(() => _selectedBranch = b),
            )
          else
            _FixedTarget(
              icon: Icons.store_mall_directory_outlined,
              label: _ownBranchName ?? 'Your branch',
              caption: 'Everyone in your branch will be notified.',
            ),
          const SizedBox(height: AppSpacing.md),
          _roleSelector(),
        ];
      case BroadcastAudience.user:
      case BroadcastAudience.custom:
        return [
          const SizedBox(height: AppSpacing.md),
          if (_isAdmin) ...[
            AppDropdownField<BranchEntity>(
              value: _selectedBranch,
              hint: 'Select a branch',
              prefixIcon: Icons.store_mall_directory_outlined,
              items: [
                for (final b in _branches)
                  DropdownMenuItem(value: b, child: Text(b.name)),
              ],
              onChanged: (b) {
                setState(() => _selectedBranch = b);
                if (b != null) _loadUsers(b.id);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _userPicker(),
        ];
    }
  }

  /// A role filter for a branch / all-branches send (Everyone / Managers /
  /// Employees), applied server-side.
  Widget _roleSelector() {
    const options = [
      ('all', 'Everyone'),
      ('manager', 'Managers'),
      ('employee', 'Employees'),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (value, label) in options)
          _Choice(
            icon: switch (value) {
              'manager' => Icons.shield_outlined,
              'employee' => Icons.badge_outlined,
              _ => Icons.groups_outlined,
            },
            label: label,
            selected: _roleFilter == value,
            onTap: () => setState(() => _roleFilter = value),
          ),
      ],
    );
  }

  Widget _userPicker() {
    if (_isAdmin && _selectedBranch == null) {
      return const _Hint('Pick a branch to choose a recipient.');
    }
    if (_loadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return const _Hint('No active users to message in this branch.');
    }
    final filtered = _filteredUsers;
    final allSelected =
        filtered.isNotEmpty &&
        filtered.every((u) => _selectedUsers.contains(u.uid));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          hint: 'Search people',
          onChanged: (v) => setState(() => _userQuery = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              _selectedUsers.isEmpty
                  ? 'Select one or more'
                  : '${_selectedUsers.length} selected',
              style: AppTypography.caption,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  for (final u in filtered) {
                    _selectedUsers.remove(u.uid);
                  }
                } else {
                  for (final u in filtered) {
                    _selectedUsers.add(u.uid);
                  }
                }
              }),
              child: Text(
                allSelected ? 'Clear all' : 'Select all',
                style: AppTypography.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        if (filtered.isEmpty)
          const _Hint('No people match your search.')
        else
          for (final u in filtered)
            _UserTile(
              user: u,
              selected: _selectedUsers.contains(u.uid),
              onTap: () => setState(() {
                if (!_selectedUsers.add(u.uid)) _selectedUsers.remove(u.uid);
              }),
            ),
      ],
    );
  }

  Widget _categorySelector() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final c in BroadcastCategory.values)
          _Choice(
            icon: categoryIcon(c),
            label: c.label,
            selected: _category == c,
            accent: c.isUrgent ? categoryColor(c) : null,
            onTap: () => setState(() => _category = c),
          ),
      ],
    );
  }

  Widget _deliverySelector() => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: [
      _Choice(
        icon: Icons.inbox_outlined,
        label: 'Inbox only',
        selected: !_sendsPush,
        onTap: () => setState(() => _sendsPush = false),
      ),
      _Choice(
        icon: Icons.notifications_active_outlined,
        label: 'Push + Inbox',
        selected: _sendsPush,
        onTap: () => setState(() => _sendsPush = true),
      ),
    ],
  );
}

/// A live character counter shown under a field.
class _Counter extends StatelessWidget {
  const _Counter({required this.length, required this.max});
  final int length;
  final int max;
  @override
  Widget build(BuildContext context) {
    final over = length > max;
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$length/$max',
          style: AppTypography.caption.copyWith(
            color: over ? AppColors.error : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// A live preview of how the broadcast will read.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.message,
    required this.category,
    required this.sendsPush,
  });

  final String title;
  final String message;
  final BroadcastCategory category;
  final bool sendsPush;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(category);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: catColor.withAlpha(category.isUrgent ? 30 : 20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: catColor.withAlpha(60)),
                ),
                child: Icon(categoryIcon(category), size: 18, color: catColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title.trim().isEmpty ? 'Broadcast title' : title,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: title.trim().isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message.trim().isEmpty ? 'Your message preview…' : message,
            style: AppTypography.bodySmall.copyWith(
              color: message.trim().isEmpty
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                category.label,
                style: AppTypography.caption.copyWith(color: catColor),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${sendsPush ? 'Push + Inbox' : 'Inbox only'}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The result of the scheduling sheet.
class _ScheduleConfig {
  const _ScheduleConfig({
    required this.startAt,
    required this.recurrence,
    required this.interval,
    this.endDate,
  });
  final DateTime startAt;
  final BroadcastRecurrence recurrence;
  final int interval;
  final DateTime? endDate;
}

/// Picks the first run time + recurrence (Phase 2 Commit 4).
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late DateTime _startAt;
  BroadcastRecurrence _rec = BroadcastRecurrence.oneTime;
  int _interval = 2;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9);
    _startAt = tomorrow;
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (!mounted) return;
    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startAt.add(const Duration(days: 30)),
      firstDate: _startAt,
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (!mounted) return;
    if (date != null) {
      setState(
        () => _endDate = DateTime(date.year, date.month, date.day, 23, 59),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.md,
          AppSpacing.pagePadding,
          AppSpacing.xl,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Schedule broadcast', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.lg),
          _label('First send'),
          _Tappable(
            icon: Icons.event_rounded,
            label: broadcastFullDate(_startAt),
            onTap: _pickStart,
          ),
          const SizedBox(height: AppSpacing.lg),
          _label('Repeat'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in BroadcastRecurrence.values)
                _Choice(
                  icon: r.isRecurring
                      ? Icons.repeat_rounded
                      : Icons.event_available_rounded,
                  label: r.label,
                  selected: _rec == r,
                  onTap: () => setState(() => _rec = r),
                ),
            ],
          ),
          if (_rec == BroadcastRecurrence.custom) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Text('Every', style: AppTypography.body),
                const SizedBox(width: AppSpacing.md),
                _StepBtn(
                  icon: Icons.remove_rounded,
                  onTap: () =>
                      setState(() => _interval = (_interval - 1).clamp(1, 365)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text('$_interval', style: AppTypography.h3),
                ),
                _StepBtn(
                  icon: Icons.add_rounded,
                  onTap: () =>
                      setState(() => _interval = (_interval + 1).clamp(1, 365)),
                ),
                const SizedBox(width: AppSpacing.md),
                const Text('days', style: AppTypography.body),
              ],
            ),
          ],
          if (_rec.isRecurring) ...[
            const SizedBox(height: AppSpacing.lg),
            _label('Ends (optional)'),
            _Tappable(
              icon: Icons.event_busy_rounded,
              label: _endDate == null
                  ? 'No end date'
                  : broadcastFullDate(_endDate),
              onTap: _pickEnd,
              trailing: _endDate == null
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      onPressed: () => setState(() => _endDate = null),
                    ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Schedule',
            onPressed: () => Navigator.pop(
              context,
              _ScheduleConfig(
                startAt: _startAt,
                recurrence: _rec,
                interval: _interval,
                endDate: _rec.isRecurring ? _endDate : null,
              ),
            ),
            icon: const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      t.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.label)),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

// ─── Small presentational helpers ─────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.bodySmall);
}

/// A selectable chip used for both the audience and category rows.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.onPrimary
        : (accent ?? AppColors.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fixed (non-selectable) target tile — the manager's own branch.
class _FixedTarget extends StatelessWidget {
  const _FixedTarget({
    required this.icon,
    required this.label,
    required this.caption,
  });
  final IconData icon;
  final String label;
  final String caption;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(caption, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });
  final UserEntity user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : user.email;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
          ),
        ),
        child: Row(
          children: [
            UserAvatar.fromUser(user, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The sticky bottom Send CTA.
class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.enabled,
    required this.loading,
    required this.onSend,
  });
  final bool enabled;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.md,
        AppSpacing.pagePadding,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.darkBorder)),
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: 'Send Broadcast',
          isLoading: loading,
          onPressed: enabled ? onSend : null,
          icon: const Icon(
            Icons.send_rounded,
            size: 18,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}
