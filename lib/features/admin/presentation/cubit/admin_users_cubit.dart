import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drop/core/enums/user_role.dart';
import 'package:drop/core/errors/failures.dart';
import 'package:drop/features/admin/domain/entities/user_compensation.dart';
import 'package:drop/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart';
import 'package:drop/features/branch/domain/entities/branch_entity.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'admin_users_state.dart';

/// Which slice of users a screen is showing. (Public registration / pending
/// approval was removed — accounts are admin-provisioned, so there is no
/// `pending` slice anymore.)
enum AdminUserFilter { managers, employees }

/// Admin user management — backs the Managers + Employees screens and the
/// Create Account flow. Calls the repositories directly (no use-case layer).
class AdminUsersCubit extends Cubit<AdminUsersState> {
  final UserAdminRepository _users;
  final BranchRepository _branches;

  AdminUserFilter _filter = AdminUserFilter.employees;

  AdminUsersCubit(this._users, this._branches)
      : super(const AdminUsersState.initial());

  List<UserEntity> get _current =>
      state.maybeWhen(loaded: (u, _) => u, orElse: () => const []);

  bool get _busy => state.maybeWhen(
        loaded: (_, busy) => busy,
        loading: () => true,
        orElse: () => false,
      );

  Future<void> load(AdminUserFilter filter) async {
    _filter = filter;
    emit(const AdminUsersState.loading());
    try {
      emit(AdminUsersState.loaded(await _fetch(filter)));
    } on Failure catch (e) {
      emit(AdminUsersState.error(e.message));
    } catch (_) {
      emit(const AdminUsersState.error('Failed to load users.'));
    }
  }

  Future<void> refresh() => load(_filter);

  Future<List<UserEntity>> _fetch(AdminUserFilter filter) {
    switch (filter) {
      case AdminUserFilter.managers:
        return _users.getUsersByRole(UserRole.manager);
      case AdminUserFilter.employees:
        return _users.getUsersByRole(UserRole.employee);
    }
  }

  // ─── Provisioning ──────────────────────────────────────────────
  /// Create a brand-new account through the secure backend. Returns the new uid
  /// on success; throws a [Failure] on error (the screen surfaces it). Does not
  /// disturb the shared list state — the management screens pull-to-refresh.
  Future<String> createAccount({
    required String name,
    required String email,
    required String temporaryPassword,
    required UserRole role,
    String? branchId,
    String? assignedShift,
    String? position,
  }) =>
      _users.createAccount(
        name: name,
        email: email,
        temporaryPassword: temporaryPassword,
        role: role,
        branchId: branchId,
        assignedShift: assignedShift,
        position: position,
      );

  /// Reset an account: new temp password + re-force a password change.
  Future<void> resetAccount(UserEntity user, String temporaryPassword) =>
      _mutate(() => _users.resetPassword(
            uid: user.uid,
            temporaryPassword: temporaryPassword,
          ));

  // ─── Actions ───────────────────────────────────────────────────
  Future<void> setActive(UserEntity user, bool isActive) =>
      _mutate(() => _users.setUserActive(user.uid, isActive));

  /// Permanently delete an account and clean up its active references (schedule,
  /// open tasks, pending swaps/requests/sales, notifications). Irreversible.
  /// Goes through [_mutate] so the deleted user drops out of the refreshed list.
  Future<void> deleteAccount(UserEntity user) =>
      _mutate(() => _users.deleteAccount(user.uid));

  Future<void> changeBranch(UserEntity user, String? branchId) =>
      _mutate(() => _users.changeUserBranch(user.uid, branchId));

  /// Set the employee's job position (drives shift-swap role compatibility).
  Future<void> changePosition(UserEntity user, String? position) =>
      _mutate(() => _users.changeUserPosition(user.uid, position));

  /// Edit the user's contact details (name / phone / address / emergency
  /// contact). Only non-null contact fields are written. When
  /// [writeCompensation] is set, the four compensation fields are ALSO written
  /// (all four keys, null clears) in the same busy cycle — the Edit Info sheet
  /// saves both blocks with one action.
  Future<void> updateDetails(
    UserEntity user, {
    String? displayName,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
    bool writeCompensation = false,
    double? salaryAmount,
    String? salaryType,
    String? paymentMethod,
    String? paymentNumber,
  }) =>
      _mutate(() async {
        await _users.updateUserDetails(
          user.uid,
          displayName: displayName,
          phoneNumber: phoneNumber,
          address: address,
          emergencyContact: emergencyContact,
        );
        if (writeCompensation) {
          await _users.updateUserCompensation(
            user.uid,
            salaryAmount: salaryAmount,
            salaryType: salaryType,
            paymentMethod: paymentMethod,
            paymentNumber: paymentNumber,
          );
        }
      });

  /// Compensation write for a just-provisioned account (Create Account flow).
  /// Bypasses [_mutate] — no user list is loaded on that screen, so there is
  /// nothing to refresh. Throws a [Failure] so the screen can warn without
  /// blocking the credentials hand-off (the account itself already exists).
  Future<void> setCompensation(
    String uid, {
    required double? salaryAmount,
    required String? salaryType,
    required String? paymentMethod,
    required String? paymentNumber,
  }) =>
      _users.updateUserCompensation(
        uid,
        salaryAmount: salaryAmount,
        salaryType: salaryType,
        paymentMethod: paymentMethod,
        paymentNumber: paymentNumber,
      );

  /// The user's private compensation record, loaded on demand for the admin
  /// Details / Edit-Info / inspector surfaces (C2 fix — compensation is no
  /// longer part of the user list). Non-emitting, best-effort: an error shows
  /// as "no record" rather than failing the surface.
  Future<UserCompensation?> compensationFor(String uid) async {
    try {
      return await _users.getUserCompensation(uid);
    } catch (_) {
      return null;
    }
  }

  /// Set the HR employment label (active / suspended / terminated).
  Future<void> changeEmploymentStatus(UserEntity user, String status) =>
      _mutate(() => _users.changeUserEmploymentStatus(user.uid, status));

  Future<void> changeRole(UserEntity user, UserRole role) =>
      _mutate(() => _users.changeUserRole(user.uid, role));

  /// Promote an existing employee to manager. Pass [branchId] to move them to a
  /// branch; when omitted the employee's existing branch is preserved.
  Future<void> promoteToManager(UserEntity user, {String? branchId}) =>
      _mutate(() async {
        await _users.changeUserRole(user.uid, UserRole.manager);
        if (branchId != null) {
          await _users.changeUserBranch(user.uid, branchId);
        }
      });

  // ─── Picker data ───────────────────────────────────────────────
  Future<List<BranchEntity>> branches() async {
    try {
      final list = await _branches.getBranches();
      return list.where((b) => b.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Active employees that can be promoted to manager.
  Future<List<UserEntity>> promotableEmployees() async {
    try {
      final list = await _users.getUsersByRole(UserRole.employee);
      return list.where((u) => u.isActive).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Read-only fetch of users by [role] (does not touch the list state) — used
  /// by the Branches page to resolve each branch's manager + employee count.
  Future<List<UserEntity>> usersWithRole(UserRole role) async {
    try {
      return await _users.getUsersByRole(role);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (_busy) return;
    final prev = _current;
    emit(AdminUsersState.loaded(prev, busy: true));
    try {
      await action();
      emit(AdminUsersState.loaded(await _fetch(_filter)));
    } on Failure catch (e) {
      emit(AdminUsersState.error(e.message));
      emit(AdminUsersState.loaded(prev));
    } catch (_) {
      emit(const AdminUsersState.error('Something went wrong. Please try again.'));
      emit(AdminUsersState.loaded(prev));
    }
  }
}
