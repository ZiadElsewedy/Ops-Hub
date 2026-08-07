import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/services/notification_preferences_store.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_radius.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/core/widgets/adaptive_scaffold.dart';
import 'package:drop/core/widgets/settings_tiles.dart';
import 'package:drop/core/widgets/skeleton.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';

/// Notification preferences for the signed-in user, **on this device**.
///
/// Values persist locally through [NotificationPreferencesStore] (a JSON file in
/// the app-support directory, the same mechanism the seen-stores use). There is
/// deliberately **no Firebase write and no delivery wiring yet** — this screen
/// owns the user's choices; consuming them to suppress a push is the next step.
///
/// **Enable Notifications is the master.** With it off the other five dim and
/// stop accepting input, but keep their stored values, so turning it back on
/// restores exactly the set the user had chosen.
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key, this.store});

  /// Injectable for tests; defaults to the app-wide store.
  final NotificationPreferencesStore? store;

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  late final NotificationPreferencesStore _store =
      widget.store ?? AppDependencies.notificationPreferences;

  NotificationPreferences _prefs = const NotificationPreferences();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthCubit>().state.maybeWhen(
      authenticated: (u) => u.uid,
      orElse: () => '',
    );
    final ready = _store.loadedFor(uid);
    if (ready != null) {
      _prefs = ready;
      _loaded = true;
    } else {
      _load(uid);
    }
  }

  Future<void> _load(String uid) async {
    final loaded = await _store.load(uid);
    if (!mounted) return;
    setState(() {
      _prefs = loaded;
      _loaded = true;
    });
  }

  void _update(NotificationPreferences next) {
    setState(() => _prefs = next);
    _store.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Notifications',
      contentMaxWidth: 680,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsReveal(
              index: 0,
              child: SettingsSectionHeader(label: 'Delivery'),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsReveal(
              index: 1,
              child: _loaded ? _deliveryGroup() : const _RowsSkeleton(rows: 1),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SettingsReveal(
              index: 2,
              child: SettingsSectionHeader(label: 'What you are told about'),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsReveal(
              index: 3,
              child: _loaded ? _categoryGroup() : const _RowsSkeleton(rows: 4),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SettingsReveal(
              index: 4,
              child: SettingsSectionHeader(label: 'Alerts'),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsReveal(
              index: 5,
              child: _loaded ? _soundGroup() : const _RowsSkeleton(rows: 1),
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsReveal(
              index: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _prefs.enabled
                      ? 'These preferences are saved on this device.'
                      : 'Notifications are off, so nothing below is delivered. '
                            'Your choices are kept for when you turn them back '
                            'on.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryGroup() => SettingsGroup(
    children: [
      SettingsSwitchRow(
        icon: Icons.notifications_active_outlined,
        label: 'Enable Notifications',
        subtitle: 'Turn every DROP notification on or off',
        value: _prefs.enabled,
        onChanged: (v) => _update(_prefs.copyWith(enabled: v)),
        isFirst: true,
        isLast: true,
      ),
    ],
  );

  Widget _categoryGroup() {
    final on = _prefs.enabled;
    return SettingsGroup(
      children: [
        SettingsSwitchRow(
          icon: Icons.task_alt_rounded,
          label: 'Task Reminders',
          subtitle: 'Work due soon, late or needing rework',
          value: _prefs.taskReminders,
          enabled: on,
          onChanged: (v) => _update(_prefs.copyWith(taskReminders: v)),
          isFirst: true,
        ),
        SettingsSwitchRow(
          icon: Icons.calendar_month_rounded,
          label: 'Schedule Updates',
          subtitle: 'Roster changes, shift swaps and leave decisions',
          value: _prefs.scheduleUpdates,
          enabled: on,
          onChanged: (v) => _update(_prefs.copyWith(scheduleUpdates: v)),
        ),
        SettingsSwitchRow(
          icon: Icons.forum_outlined,
          label: 'Case Messages',
          subtitle: 'Replies in your private support conversations',
          value: _prefs.caseMessages,
          enabled: on,
          onChanged: (v) => _update(_prefs.copyWith(caseMessages: v)),
        ),
        SettingsSwitchRow(
          icon: Icons.campaign_outlined,
          label: 'Announcements',
          subtitle: 'Broadcasts from management',
          value: _prefs.announcements,
          enabled: on,
          onChanged: (v) => _update(_prefs.copyWith(announcements: v)),
          isLast: true,
        ),
      ],
    );
  }

  Widget _soundGroup() => SettingsGroup(
    children: [
      SettingsSwitchRow(
        icon: Icons.volume_up_outlined,
        label: 'Sound',
        subtitle: 'Play a sound when a notification arrives',
        value: _prefs.sound,
        enabled: _prefs.enabled,
        onChanged: (v) => _update(_prefs.copyWith(sound: v)),
        isFirst: true,
        isLast: true,
      ),
    ],
  );
}

/// Holds the shape of the arriving rows while the preferences file is read, so
/// the switches never paint a default the user did not choose and then flip.
class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton({required this.rows});

  final int rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.darkSurface,
      borderRadius: AppRadius.cardAll,
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SettingsRowDivider(),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Skeleton(width: 40, height: 40),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: Skeleton(height: 12)),
                  SizedBox(width: AppSpacing.sm),
                  Skeleton(width: 44, height: 24),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
