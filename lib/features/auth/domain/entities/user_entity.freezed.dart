// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UserEntity {
  String get uid => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get authProvider => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;

  /// Home / mailing address. Optional contact detail an admin can fill in or
  /// edit at any time (also collected during profile onboarding).
  String? get address => throw _privateConstructorUsedError;

  /// Emergency contact (name/phone). Optional contact detail an admin can fill
  /// in or edit at any time (also collected during profile onboarding).
  String? get emergencyContact => throw _privateConstructorUsedError;
  bool get isEmailVerified => throw _privateConstructorUsedError;
  DateTime? get createdAt =>
      throw _privateConstructorUsedError; // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  UserRole get role => throw _privateConstructorUsedError;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  String? get branchId => throw _privateConstructorUsedError;

  /// Soft-disable flag: an admin can deactivate a user without deletion. This is
  /// the SINGLE access gate — a deactivated account is blocked at login.
  bool get isActive => throw _privateConstructorUsedError;

  /// Shift assigned to the user; null until an admin sets it.
  String? get assignedShift => throw _privateConstructorUsedError;

  /// Job position / role title within the branch (e.g. "Cashier",
  /// "Supervisor"). Optional — null means unspecified. Drives shift-swap role
  /// compatibility when a branch enables `SwapPolicy.restrictToSamePosition`
  /// (an unset position stays compatible with everyone).
  String? get position =>
      throw _privateConstructorUsedError; // ─── Account provisioning (admin-created, no self-registration) ─────
  /// True until the user changes the admin-issued temporary password. While
  /// set, the router confines them to the Force Password Change screen.
  bool get mustChangePassword => throw _privateConstructorUsedError;

  /// True once the user has filled their onboarding profile. While false, the
  /// router confines them to the Profile Completion screen. Defaults true so
  /// legacy / pre-migration documents are never trapped in onboarding.
  bool get isProfileCompleted => throw _privateConstructorUsedError;

  /// True once the user has seen the one-time Welcome screen (shown to
  /// employees right after profile completion). Defaults true so every
  /// existing user is treated as already welcomed and is NEVER interrupted —
  /// only a genuinely new account is seeded `false` at profile completion, so
  /// the router shows Welcome exactly once. Non-employees never see it
  /// regardless of this flag (the gate is employee-scoped).
  bool get hasCompletedOnboarding => throw _privateConstructorUsedError;

  /// HR employment label (`active` / `suspended` / `terminated`). A record
  /// field shown/edited in admin — it does NOT gate access (that's [isActive]).
  String get employmentStatus => throw _privateConstructorUsedError;

  /// The admin uid that provisioned this account (audit). Null for accounts
  /// created out of band (e.g. the bootstrapped first admin).
  String? get createdBy =>
      throw _privateConstructorUsedError; // ─── Single active session ──────────────────────────────────
  /// The id of the ONE sign-in currently allowed to hold this account, minted
  /// per device at sign-in (`generateSessionId`) and claimed on the user
  /// document. A device stays signed in only while this matches the id in its
  /// own `SessionStore`; a newer sign-in elsewhere overwrites it and evicts
  /// every other device (see `AuthCubit`).
  ///
  /// **Null means "no claim on record"** — legacy documents, and any account
  /// that has not signed in since the feature shipped. Null is deliberately
  /// NOT an eviction: it is the back-compat state, so an app upgrade never
  /// signs the whole company out at once.
  String? get activeSessionId => throw _privateConstructorUsedError;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserEntityCopyWith<UserEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserEntityCopyWith<$Res> {
  factory $UserEntityCopyWith(
    UserEntity value,
    $Res Function(UserEntity) then,
  ) = _$UserEntityCopyWithImpl<$Res, UserEntity>;
  @useResult
  $Res call({
    String uid,
    String email,
    String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
    bool isEmailVerified,
    DateTime? createdAt,
    UserRole role,
    String? branchId,
    bool isActive,
    String? assignedShift,
    String? position,
    bool mustChangePassword,
    bool isProfileCompleted,
    bool hasCompletedOnboarding,
    String employmentStatus,
    String? createdBy,
    String? activeSessionId,
  });
}

/// @nodoc
class _$UserEntityCopyWithImpl<$Res, $Val extends UserEntity>
    implements $UserEntityCopyWith<$Res> {
  _$UserEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? authProvider = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? address = freezed,
    Object? emergencyContact = freezed,
    Object? isEmailVerified = null,
    Object? createdAt = freezed,
    Object? role = null,
    Object? branchId = freezed,
    Object? isActive = null,
    Object? assignedShift = freezed,
    Object? position = freezed,
    Object? mustChangePassword = null,
    Object? isProfileCompleted = null,
    Object? hasCompletedOnboarding = null,
    Object? employmentStatus = null,
    Object? createdBy = freezed,
    Object? activeSessionId = freezed,
  }) {
    return _then(
      _value.copyWith(
            uid: null == uid
                ? _value.uid
                : uid // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            authProvider: null == authProvider
                ? _value.authProvider
                : authProvider // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            photoUrl: freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            phoneNumber: freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String?,
            emergencyContact: freezed == emergencyContact
                ? _value.emergencyContact
                : emergencyContact // ignore: cast_nullable_to_non_nullable
                      as String?,
            isEmailVerified: null == isEmailVerified
                ? _value.isEmailVerified
                : isEmailVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as UserRole,
            branchId: freezed == branchId
                ? _value.branchId
                : branchId // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            assignedShift: freezed == assignedShift
                ? _value.assignedShift
                : assignedShift // ignore: cast_nullable_to_non_nullable
                      as String?,
            position: freezed == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as String?,
            mustChangePassword: null == mustChangePassword
                ? _value.mustChangePassword
                : mustChangePassword // ignore: cast_nullable_to_non_nullable
                      as bool,
            isProfileCompleted: null == isProfileCompleted
                ? _value.isProfileCompleted
                : isProfileCompleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasCompletedOnboarding: null == hasCompletedOnboarding
                ? _value.hasCompletedOnboarding
                : hasCompletedOnboarding // ignore: cast_nullable_to_non_nullable
                      as bool,
            employmentStatus: null == employmentStatus
                ? _value.employmentStatus
                : employmentStatus // ignore: cast_nullable_to_non_nullable
                      as String,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            activeSessionId: freezed == activeSessionId
                ? _value.activeSessionId
                : activeSessionId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserEntityImplCopyWith<$Res>
    implements $UserEntityCopyWith<$Res> {
  factory _$$UserEntityImplCopyWith(
    _$UserEntityImpl value,
    $Res Function(_$UserEntityImpl) then,
  ) = __$$UserEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String uid,
    String email,
    String authProvider,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    String? address,
    String? emergencyContact,
    bool isEmailVerified,
    DateTime? createdAt,
    UserRole role,
    String? branchId,
    bool isActive,
    String? assignedShift,
    String? position,
    bool mustChangePassword,
    bool isProfileCompleted,
    bool hasCompletedOnboarding,
    String employmentStatus,
    String? createdBy,
    String? activeSessionId,
  });
}

/// @nodoc
class __$$UserEntityImplCopyWithImpl<$Res>
    extends _$UserEntityCopyWithImpl<$Res, _$UserEntityImpl>
    implements _$$UserEntityImplCopyWith<$Res> {
  __$$UserEntityImplCopyWithImpl(
    _$UserEntityImpl _value,
    $Res Function(_$UserEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? authProvider = null,
    Object? displayName = freezed,
    Object? photoUrl = freezed,
    Object? phoneNumber = freezed,
    Object? address = freezed,
    Object? emergencyContact = freezed,
    Object? isEmailVerified = null,
    Object? createdAt = freezed,
    Object? role = null,
    Object? branchId = freezed,
    Object? isActive = null,
    Object? assignedShift = freezed,
    Object? position = freezed,
    Object? mustChangePassword = null,
    Object? isProfileCompleted = null,
    Object? hasCompletedOnboarding = null,
    Object? employmentStatus = null,
    Object? createdBy = freezed,
    Object? activeSessionId = freezed,
  }) {
    return _then(
      _$UserEntityImpl(
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        authProvider: null == authProvider
            ? _value.authProvider
            : authProvider // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        photoUrl: freezed == photoUrl
            ? _value.photoUrl
            : photoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        phoneNumber: freezed == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String?,
        emergencyContact: freezed == emergencyContact
            ? _value.emergencyContact
            : emergencyContact // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEmailVerified: null == isEmailVerified
            ? _value.isEmailVerified
            : isEmailVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as UserRole,
        branchId: freezed == branchId
            ? _value.branchId
            : branchId // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        assignedShift: freezed == assignedShift
            ? _value.assignedShift
            : assignedShift // ignore: cast_nullable_to_non_nullable
                  as String?,
        position: freezed == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as String?,
        mustChangePassword: null == mustChangePassword
            ? _value.mustChangePassword
            : mustChangePassword // ignore: cast_nullable_to_non_nullable
                  as bool,
        isProfileCompleted: null == isProfileCompleted
            ? _value.isProfileCompleted
            : isProfileCompleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasCompletedOnboarding: null == hasCompletedOnboarding
            ? _value.hasCompletedOnboarding
            : hasCompletedOnboarding // ignore: cast_nullable_to_non_nullable
                  as bool,
        employmentStatus: null == employmentStatus
            ? _value.employmentStatus
            : employmentStatus // ignore: cast_nullable_to_non_nullable
                  as String,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        activeSessionId: freezed == activeSessionId
            ? _value.activeSessionId
            : activeSessionId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$UserEntityImpl extends _UserEntity {
  const _$UserEntityImpl({
    required this.uid,
    required this.email,
    required this.authProvider,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    this.isEmailVerified = false,
    this.createdAt,
    this.role = UserRole.employee,
    this.branchId,
    this.isActive = true,
    this.assignedShift,
    this.position,
    this.mustChangePassword = false,
    this.isProfileCompleted = true,
    this.hasCompletedOnboarding = true,
    this.employmentStatus = 'active',
    this.createdBy,
    this.activeSessionId,
  }) : super._();

  @override
  final String uid;
  @override
  final String email;
  @override
  final String authProvider;
  @override
  final String? displayName;
  @override
  final String? photoUrl;
  @override
  final String? phoneNumber;

  /// Home / mailing address. Optional contact detail an admin can fill in or
  /// edit at any time (also collected during profile onboarding).
  @override
  final String? address;

  /// Emergency contact (name/phone). Optional contact detail an admin can fill
  /// in or edit at any time (also collected during profile onboarding).
  @override
  final String? emergencyContact;
  @override
  @JsonKey()
  final bool isEmailVerified;
  @override
  final DateTime? createdAt;
  // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  @override
  @JsonKey()
  final UserRole role;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  @override
  final String? branchId;

  /// Soft-disable flag: an admin can deactivate a user without deletion. This is
  /// the SINGLE access gate — a deactivated account is blocked at login.
  @override
  @JsonKey()
  final bool isActive;

  /// Shift assigned to the user; null until an admin sets it.
  @override
  final String? assignedShift;

  /// Job position / role title within the branch (e.g. "Cashier",
  /// "Supervisor"). Optional — null means unspecified. Drives shift-swap role
  /// compatibility when a branch enables `SwapPolicy.restrictToSamePosition`
  /// (an unset position stays compatible with everyone).
  @override
  final String? position;
  // ─── Account provisioning (admin-created, no self-registration) ─────
  /// True until the user changes the admin-issued temporary password. While
  /// set, the router confines them to the Force Password Change screen.
  @override
  @JsonKey()
  final bool mustChangePassword;

  /// True once the user has filled their onboarding profile. While false, the
  /// router confines them to the Profile Completion screen. Defaults true so
  /// legacy / pre-migration documents are never trapped in onboarding.
  @override
  @JsonKey()
  final bool isProfileCompleted;

  /// True once the user has seen the one-time Welcome screen (shown to
  /// employees right after profile completion). Defaults true so every
  /// existing user is treated as already welcomed and is NEVER interrupted —
  /// only a genuinely new account is seeded `false` at profile completion, so
  /// the router shows Welcome exactly once. Non-employees never see it
  /// regardless of this flag (the gate is employee-scoped).
  @override
  @JsonKey()
  final bool hasCompletedOnboarding;

  /// HR employment label (`active` / `suspended` / `terminated`). A record
  /// field shown/edited in admin — it does NOT gate access (that's [isActive]).
  @override
  @JsonKey()
  final String employmentStatus;

  /// The admin uid that provisioned this account (audit). Null for accounts
  /// created out of band (e.g. the bootstrapped first admin).
  @override
  final String? createdBy;
  // ─── Single active session ──────────────────────────────────
  /// The id of the ONE sign-in currently allowed to hold this account, minted
  /// per device at sign-in (`generateSessionId`) and claimed on the user
  /// document. A device stays signed in only while this matches the id in its
  /// own `SessionStore`; a newer sign-in elsewhere overwrites it and evicts
  /// every other device (see `AuthCubit`).
  ///
  /// **Null means "no claim on record"** — legacy documents, and any account
  /// that has not signed in since the feature shipped. Null is deliberately
  /// NOT an eviction: it is the back-compat state, so an app upgrade never
  /// signs the whole company out at once.
  @override
  final String? activeSessionId;

  @override
  String toString() {
    return 'UserEntity(uid: $uid, email: $email, authProvider: $authProvider, displayName: $displayName, photoUrl: $photoUrl, phoneNumber: $phoneNumber, address: $address, emergencyContact: $emergencyContact, isEmailVerified: $isEmailVerified, createdAt: $createdAt, role: $role, branchId: $branchId, isActive: $isActive, assignedShift: $assignedShift, position: $position, mustChangePassword: $mustChangePassword, isProfileCompleted: $isProfileCompleted, hasCompletedOnboarding: $hasCompletedOnboarding, employmentStatus: $employmentStatus, createdBy: $createdBy, activeSessionId: $activeSessionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserEntityImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.authProvider, authProvider) ||
                other.authProvider == authProvider) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.emergencyContact, emergencyContact) ||
                other.emergencyContact == emergencyContact) &&
            (identical(other.isEmailVerified, isEmailVerified) ||
                other.isEmailVerified == isEmailVerified) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.assignedShift, assignedShift) ||
                other.assignedShift == assignedShift) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.mustChangePassword, mustChangePassword) ||
                other.mustChangePassword == mustChangePassword) &&
            (identical(other.isProfileCompleted, isProfileCompleted) ||
                other.isProfileCompleted == isProfileCompleted) &&
            (identical(other.hasCompletedOnboarding, hasCompletedOnboarding) ||
                other.hasCompletedOnboarding == hasCompletedOnboarding) &&
            (identical(other.employmentStatus, employmentStatus) ||
                other.employmentStatus == employmentStatus) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.activeSessionId, activeSessionId) ||
                other.activeSessionId == activeSessionId));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    uid,
    email,
    authProvider,
    displayName,
    photoUrl,
    phoneNumber,
    address,
    emergencyContact,
    isEmailVerified,
    createdAt,
    role,
    branchId,
    isActive,
    assignedShift,
    position,
    mustChangePassword,
    isProfileCompleted,
    hasCompletedOnboarding,
    employmentStatus,
    createdBy,
    activeSessionId,
  ]);

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      __$$UserEntityImplCopyWithImpl<_$UserEntityImpl>(this, _$identity);
}

abstract class _UserEntity extends UserEntity {
  const factory _UserEntity({
    required final String uid,
    required final String email,
    required final String authProvider,
    final String? displayName,
    final String? photoUrl,
    final String? phoneNumber,
    final String? address,
    final String? emergencyContact,
    final bool isEmailVerified,
    final DateTime? createdAt,
    final UserRole role,
    final String? branchId,
    final bool isActive,
    final String? assignedShift,
    final String? position,
    final bool mustChangePassword,
    final bool isProfileCompleted,
    final bool hasCompletedOnboarding,
    final String employmentStatus,
    final String? createdBy,
    final String? activeSessionId,
  }) = _$UserEntityImpl;
  const _UserEntity._() : super._();

  @override
  String get uid;
  @override
  String get email;
  @override
  String get authProvider;
  @override
  String? get displayName;
  @override
  String? get photoUrl;
  @override
  String? get phoneNumber;

  /// Home / mailing address. Optional contact detail an admin can fill in or
  /// edit at any time (also collected during profile onboarding).
  @override
  String? get address;

  /// Emergency contact (name/phone). Optional contact detail an admin can fill
  /// in or edit at any time (also collected during profile onboarding).
  @override
  String? get emergencyContact;
  @override
  bool get isEmailVerified;
  @override
  DateTime? get createdAt; // ─── Roles & foundation (Phase 1) ───────────────────────────
  /// Access role; drives navigation + route guards. Defaults to [UserRole.employee].
  @override
  UserRole get role;

  /// Store branch the user belongs to. Assigned by an admin; null until then.
  @override
  String? get branchId;

  /// Soft-disable flag: an admin can deactivate a user without deletion. This is
  /// the SINGLE access gate — a deactivated account is blocked at login.
  @override
  bool get isActive;

  /// Shift assigned to the user; null until an admin sets it.
  @override
  String? get assignedShift;

  /// Job position / role title within the branch (e.g. "Cashier",
  /// "Supervisor"). Optional — null means unspecified. Drives shift-swap role
  /// compatibility when a branch enables `SwapPolicy.restrictToSamePosition`
  /// (an unset position stays compatible with everyone).
  @override
  String? get position; // ─── Account provisioning (admin-created, no self-registration) ─────
  /// True until the user changes the admin-issued temporary password. While
  /// set, the router confines them to the Force Password Change screen.
  @override
  bool get mustChangePassword;

  /// True once the user has filled their onboarding profile. While false, the
  /// router confines them to the Profile Completion screen. Defaults true so
  /// legacy / pre-migration documents are never trapped in onboarding.
  @override
  bool get isProfileCompleted;

  /// True once the user has seen the one-time Welcome screen (shown to
  /// employees right after profile completion). Defaults true so every
  /// existing user is treated as already welcomed and is NEVER interrupted —
  /// only a genuinely new account is seeded `false` at profile completion, so
  /// the router shows Welcome exactly once. Non-employees never see it
  /// regardless of this flag (the gate is employee-scoped).
  @override
  bool get hasCompletedOnboarding;

  /// HR employment label (`active` / `suspended` / `terminated`). A record
  /// field shown/edited in admin — it does NOT gate access (that's [isActive]).
  @override
  String get employmentStatus;

  /// The admin uid that provisioned this account (audit). Null for accounts
  /// created out of band (e.g. the bootstrapped first admin).
  @override
  String? get createdBy; // ─── Single active session ──────────────────────────────────
  /// The id of the ONE sign-in currently allowed to hold this account, minted
  /// per device at sign-in (`generateSessionId`) and claimed on the user
  /// document. A device stays signed in only while this matches the id in its
  /// own `SessionStore`; a newer sign-in elsewhere overwrites it and evicts
  /// every other device (see `AuthCubit`).
  ///
  /// **Null means "no claim on record"** — legacy documents, and any account
  /// that has not signed in since the feature shipped. Null is deliberately
  /// NOT an eviction: it is the back-compat state, so an app upgrade never
  /// signs the whole company out at once.
  @override
  String? get activeSessionId;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserEntityImplCopyWith<_$UserEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
