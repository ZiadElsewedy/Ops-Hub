// THROWAWAY visual-verification entrypoint for the redesigned EmployeeCard.
// Run with: flutter run -d chrome -t tool/employee_card_preview.dart
// Delete before committing.
import 'package:flutter/material.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/theme/app_colors.dart';
import 'package:drop/core/theme/app_spacing.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/core/theme/app_typography.dart';
import 'package:drop/features/admin/presentation/widgets/admin_user_card.dart';
import 'package:drop/features/admin/presentation/widgets/employee_card.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';

void main() => runApp(const _PreviewApp());

UserEntity _user({
  required String uid,
  required String name,
  String? branchId,
  bool isActive = true,
  UserRole role = UserRole.employee,
}) => UserEntity(
  uid: uid,
  email: '$uid@drop.test',
  authProvider: 'password',
  displayName: name,
  role: role,
  branchId: branchId,
  isActive: isActive,
);

final _people = <UserEntity>[
  _user(uid: 'u1', name: 'Abdelrahman Elsewedy', branchId: 'arkan'),
  _user(uid: 'u2', name: 'Ahmed Test Acc', branchId: 'lmd'),
  _user(uid: 'u3', name: 'Moataz', branchId: 'arkan', isActive: false),
  _user(uid: 'u4', name: 'Mohamed khaled', branchId: 'arkan'),
  _user(uid: 'u5', name: 'Richard'),
  _user(uid: 'u6', name: 'Salama', branchId: 'arkan', role: UserRole.manager),
];

const _branchNames = {
  'arkan': 'Drop the shop | Arkan',
  'lmd': 'Drop The Shop | LMD',
};

List<Widget> _actions(UserEntity u) => [
  AdminActionButton(
    label: 'Details',
    icon: Icons.info_outline_rounded,
    onPressed: () {},
  ),
  AdminActionButton(
    label: 'Edit',
    icon: Icons.edit_outlined,
    onPressed: () {},
  ),
  EmployeeOverflowMenu(
    employeeName: u.displayName!,
    actions: const [
      EmployeeOverflowAction(
        label: 'Change Branch',
        icon: Icons.store_mall_directory_outlined,
        onSelected: _noOp,
      ),
      EmployeeOverflowAction(
        label: 'Deactivate',
        icon: Icons.block_rounded,
        destructive: true,
        onSelected: _noOp,
      ),
    ],
  ),
];

void _noOp() {}

Widget _card(UserEntity u) => EmployeeCard(
  user: u,
  branchLabel: u.branchId == null ? null : _branchNames[u.branchId],
  onTap: () {},
  actions: _actions(u),
);

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppColors.darkBg,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Heading('List view — full width'),
              for (final u in _people) ...[
                _card(u),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xl),
              const _Heading('Grid view — two columns'),
              for (var i = 0; i < _people.length; i += 2) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _card(_people[i])),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _card(_people[i + 1])),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.xl),
              const _Heading('Narrow / mobile — 340px'),
              SizedBox(
                width: 340,
                child: Column(
                  children: [
                    for (final u in _people.take(3)) ...[
                      _card(u),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text.toUpperCase(),
      style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
    ),
  );
}
