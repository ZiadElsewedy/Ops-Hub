// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ProfileEntity {
  // ─── Identity ───────────────────────────────────────────────
  String get uid => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  String get authProvider => throw _privateConstructorUsedError;
  String? get fullName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;
  String? get profileImage => throw _privateConstructorUsedError;
  String? get coverImage =>
      throw _privateConstructorUsedError; // ─── Personal ───────────────────────────────────────────────
  String? get bio => throw _privateConstructorUsedError;
  String? get gender => throw _privateConstructorUsedError;
  DateTime? get birthDate => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get website =>
      throw _privateConstructorUsedError; // ─── Contact & payroll (operations — stored on the same users doc) ──
  /// Home / mailing address. Self-editable.
  String? get address => throw _privateConstructorUsedError;

  /// Emergency contact (name · phone). Self-editable.
  String? get emergencyContact => throw _privateConstructorUsedError;

  /// The phone / wallet / account number the salary is sent to — the one
  /// compensation field the employee edits themselves. The admin-only salary
  /// fields (amount / type / method) are NOT part of the profile contract.
  String? get paymentNumber =>
      throw _privateConstructorUsedError; // ─── Account ────────────────────────────────────────────────
  bool get isVerified => throw _privateConstructorUsedError;
  String get accountStatus => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt =>
      throw _privateConstructorUsedError; // ─── Presence ───────────────────────────────────────────────
  bool get isOnline => throw _privateConstructorUsedError;
  DateTime? get lastSeen =>
      throw _privateConstructorUsedError; // ─── Settings ───────────────────────────────────────────────
  bool get isProfilePublic => throw _privateConstructorUsedError;
  bool get allowMessages => throw _privateConstructorUsedError;
  bool get allowNotifications => throw _privateConstructorUsedError;

  /// Create a copy of ProfileEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProfileEntityCopyWith<ProfileEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileEntityCopyWith<$Res> {
  factory $ProfileEntityCopyWith(
    ProfileEntity value,
    $Res Function(ProfileEntity) then,
  ) = _$ProfileEntityCopyWithImpl<$Res, ProfileEntity>;
  @useResult
  $Res call({
    String uid,
    String email,
    String? phoneNumber,
    String authProvider,
    String? fullName,
    String? username,
    String? profileImage,
    String? coverImage,
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? country,
    String? city,
    String? website,
    String? address,
    String? emergencyContact,
    String? paymentNumber,
    bool isVerified,
    String accountStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isOnline,
    DateTime? lastSeen,
    bool isProfilePublic,
    bool allowMessages,
    bool allowNotifications,
  });
}

/// @nodoc
class _$ProfileEntityCopyWithImpl<$Res, $Val extends ProfileEntity>
    implements $ProfileEntityCopyWith<$Res> {
  _$ProfileEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProfileEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? phoneNumber = freezed,
    Object? authProvider = null,
    Object? fullName = freezed,
    Object? username = freezed,
    Object? profileImage = freezed,
    Object? coverImage = freezed,
    Object? bio = freezed,
    Object? gender = freezed,
    Object? birthDate = freezed,
    Object? country = freezed,
    Object? city = freezed,
    Object? website = freezed,
    Object? address = freezed,
    Object? emergencyContact = freezed,
    Object? paymentNumber = freezed,
    Object? isVerified = null,
    Object? accountStatus = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? isProfilePublic = null,
    Object? allowMessages = null,
    Object? allowNotifications = null,
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
            phoneNumber: freezed == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            authProvider: null == authProvider
                ? _value.authProvider
                : authProvider // ignore: cast_nullable_to_non_nullable
                      as String,
            fullName: freezed == fullName
                ? _value.fullName
                : fullName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            profileImage: freezed == profileImage
                ? _value.profileImage
                : profileImage // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverImage: freezed == coverImage
                ? _value.coverImage
                : coverImage // ignore: cast_nullable_to_non_nullable
                      as String?,
            bio: freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                      as String?,
            gender: freezed == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as String?,
            birthDate: freezed == birthDate
                ? _value.birthDate
                : birthDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            country: freezed == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            website: freezed == website
                ? _value.website
                : website // ignore: cast_nullable_to_non_nullable
                      as String?,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String?,
            emergencyContact: freezed == emergencyContact
                ? _value.emergencyContact
                : emergencyContact // ignore: cast_nullable_to_non_nullable
                      as String?,
            paymentNumber: freezed == paymentNumber
                ? _value.paymentNumber
                : paymentNumber // ignore: cast_nullable_to_non_nullable
                      as String?,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            accountStatus: null == accountStatus
                ? _value.accountStatus
                : accountStatus // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isOnline: null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastSeen: freezed == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isProfilePublic: null == isProfilePublic
                ? _value.isProfilePublic
                : isProfilePublic // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowMessages: null == allowMessages
                ? _value.allowMessages
                : allowMessages // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowNotifications: null == allowNotifications
                ? _value.allowNotifications
                : allowNotifications // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProfileEntityImplCopyWith<$Res>
    implements $ProfileEntityCopyWith<$Res> {
  factory _$$ProfileEntityImplCopyWith(
    _$ProfileEntityImpl value,
    $Res Function(_$ProfileEntityImpl) then,
  ) = __$$ProfileEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String uid,
    String email,
    String? phoneNumber,
    String authProvider,
    String? fullName,
    String? username,
    String? profileImage,
    String? coverImage,
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? country,
    String? city,
    String? website,
    String? address,
    String? emergencyContact,
    String? paymentNumber,
    bool isVerified,
    String accountStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool isOnline,
    DateTime? lastSeen,
    bool isProfilePublic,
    bool allowMessages,
    bool allowNotifications,
  });
}

/// @nodoc
class __$$ProfileEntityImplCopyWithImpl<$Res>
    extends _$ProfileEntityCopyWithImpl<$Res, _$ProfileEntityImpl>
    implements _$$ProfileEntityImplCopyWith<$Res> {
  __$$ProfileEntityImplCopyWithImpl(
    _$ProfileEntityImpl _value,
    $Res Function(_$ProfileEntityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProfileEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? email = null,
    Object? phoneNumber = freezed,
    Object? authProvider = null,
    Object? fullName = freezed,
    Object? username = freezed,
    Object? profileImage = freezed,
    Object? coverImage = freezed,
    Object? bio = freezed,
    Object? gender = freezed,
    Object? birthDate = freezed,
    Object? country = freezed,
    Object? city = freezed,
    Object? website = freezed,
    Object? address = freezed,
    Object? emergencyContact = freezed,
    Object? paymentNumber = freezed,
    Object? isVerified = null,
    Object? accountStatus = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? isOnline = null,
    Object? lastSeen = freezed,
    Object? isProfilePublic = null,
    Object? allowMessages = null,
    Object? allowNotifications = null,
  }) {
    return _then(
      _$ProfileEntityImpl(
        uid: null == uid
            ? _value.uid
            : uid // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: freezed == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        authProvider: null == authProvider
            ? _value.authProvider
            : authProvider // ignore: cast_nullable_to_non_nullable
                  as String,
        fullName: freezed == fullName
            ? _value.fullName
            : fullName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        profileImage: freezed == profileImage
            ? _value.profileImage
            : profileImage // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverImage: freezed == coverImage
            ? _value.coverImage
            : coverImage // ignore: cast_nullable_to_non_nullable
                  as String?,
        bio: freezed == bio
            ? _value.bio
            : bio // ignore: cast_nullable_to_non_nullable
                  as String?,
        gender: freezed == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as String?,
        birthDate: freezed == birthDate
            ? _value.birthDate
            : birthDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        country: freezed == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        website: freezed == website
            ? _value.website
            : website // ignore: cast_nullable_to_non_nullable
                  as String?,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String?,
        emergencyContact: freezed == emergencyContact
            ? _value.emergencyContact
            : emergencyContact // ignore: cast_nullable_to_non_nullable
                  as String?,
        paymentNumber: freezed == paymentNumber
            ? _value.paymentNumber
            : paymentNumber // ignore: cast_nullable_to_non_nullable
                  as String?,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        accountStatus: null == accountStatus
            ? _value.accountStatus
            : accountStatus // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isOnline: null == isOnline
            ? _value.isOnline
            : isOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastSeen: freezed == lastSeen
            ? _value.lastSeen
            : lastSeen // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isProfilePublic: null == isProfilePublic
            ? _value.isProfilePublic
            : isProfilePublic // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowMessages: null == allowMessages
            ? _value.allowMessages
            : allowMessages // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowNotifications: null == allowNotifications
            ? _value.allowNotifications
            : allowNotifications // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ProfileEntityImpl extends _ProfileEntity {
  const _$ProfileEntityImpl({
    required this.uid,
    required this.email,
    this.phoneNumber,
    this.authProvider = 'unknown',
    this.fullName,
    this.username,
    this.profileImage,
    this.coverImage,
    this.bio,
    this.gender,
    this.birthDate,
    this.country,
    this.city,
    this.website,
    this.address,
    this.emergencyContact,
    this.paymentNumber,
    this.isVerified = false,
    this.accountStatus = 'active',
    this.createdAt,
    this.updatedAt,
    this.isOnline = false,
    this.lastSeen,
    this.isProfilePublic = true,
    this.allowMessages = true,
    this.allowNotifications = true,
  }) : super._();

  // ─── Identity ───────────────────────────────────────────────
  @override
  final String uid;
  @override
  final String email;
  @override
  final String? phoneNumber;
  @override
  @JsonKey()
  final String authProvider;
  @override
  final String? fullName;
  @override
  final String? username;
  @override
  final String? profileImage;
  @override
  final String? coverImage;
  // ─── Personal ───────────────────────────────────────────────
  @override
  final String? bio;
  @override
  final String? gender;
  @override
  final DateTime? birthDate;
  @override
  final String? country;
  @override
  final String? city;
  @override
  final String? website;
  // ─── Contact & payroll (operations — stored on the same users doc) ──
  /// Home / mailing address. Self-editable.
  @override
  final String? address;

  /// Emergency contact (name · phone). Self-editable.
  @override
  final String? emergencyContact;

  /// The phone / wallet / account number the salary is sent to — the one
  /// compensation field the employee edits themselves. The admin-only salary
  /// fields (amount / type / method) are NOT part of the profile contract.
  @override
  final String? paymentNumber;
  // ─── Account ────────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final String accountStatus;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  // ─── Presence ───────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isOnline;
  @override
  final DateTime? lastSeen;
  // ─── Settings ───────────────────────────────────────────────
  @override
  @JsonKey()
  final bool isProfilePublic;
  @override
  @JsonKey()
  final bool allowMessages;
  @override
  @JsonKey()
  final bool allowNotifications;

  @override
  String toString() {
    return 'ProfileEntity(uid: $uid, email: $email, phoneNumber: $phoneNumber, authProvider: $authProvider, fullName: $fullName, username: $username, profileImage: $profileImage, coverImage: $coverImage, bio: $bio, gender: $gender, birthDate: $birthDate, country: $country, city: $city, website: $website, address: $address, emergencyContact: $emergencyContact, paymentNumber: $paymentNumber, isVerified: $isVerified, accountStatus: $accountStatus, createdAt: $createdAt, updatedAt: $updatedAt, isOnline: $isOnline, lastSeen: $lastSeen, isProfilePublic: $isProfilePublic, allowMessages: $allowMessages, allowNotifications: $allowNotifications)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileEntityImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.authProvider, authProvider) ||
                other.authProvider == authProvider) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.profileImage, profileImage) ||
                other.profileImage == profileImage) &&
            (identical(other.coverImage, coverImage) ||
                other.coverImage == coverImage) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.birthDate, birthDate) ||
                other.birthDate == birthDate) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.website, website) || other.website == website) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.emergencyContact, emergencyContact) ||
                other.emergencyContact == emergencyContact) &&
            (identical(other.paymentNumber, paymentNumber) ||
                other.paymentNumber == paymentNumber) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.accountStatus, accountStatus) ||
                other.accountStatus == accountStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen) &&
            (identical(other.isProfilePublic, isProfilePublic) ||
                other.isProfilePublic == isProfilePublic) &&
            (identical(other.allowMessages, allowMessages) ||
                other.allowMessages == allowMessages) &&
            (identical(other.allowNotifications, allowNotifications) ||
                other.allowNotifications == allowNotifications));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    uid,
    email,
    phoneNumber,
    authProvider,
    fullName,
    username,
    profileImage,
    coverImage,
    bio,
    gender,
    birthDate,
    country,
    city,
    website,
    address,
    emergencyContact,
    paymentNumber,
    isVerified,
    accountStatus,
    createdAt,
    updatedAt,
    isOnline,
    lastSeen,
    isProfilePublic,
    allowMessages,
    allowNotifications,
  ]);

  /// Create a copy of ProfileEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileEntityImplCopyWith<_$ProfileEntityImpl> get copyWith =>
      __$$ProfileEntityImplCopyWithImpl<_$ProfileEntityImpl>(this, _$identity);
}

abstract class _ProfileEntity extends ProfileEntity {
  const factory _ProfileEntity({
    required final String uid,
    required final String email,
    final String? phoneNumber,
    final String authProvider,
    final String? fullName,
    final String? username,
    final String? profileImage,
    final String? coverImage,
    final String? bio,
    final String? gender,
    final DateTime? birthDate,
    final String? country,
    final String? city,
    final String? website,
    final String? address,
    final String? emergencyContact,
    final String? paymentNumber,
    final bool isVerified,
    final String accountStatus,
    final DateTime? createdAt,
    final DateTime? updatedAt,
    final bool isOnline,
    final DateTime? lastSeen,
    final bool isProfilePublic,
    final bool allowMessages,
    final bool allowNotifications,
  }) = _$ProfileEntityImpl;
  const _ProfileEntity._() : super._();

  // ─── Identity ───────────────────────────────────────────────
  @override
  String get uid;
  @override
  String get email;
  @override
  String? get phoneNumber;
  @override
  String get authProvider;
  @override
  String? get fullName;
  @override
  String? get username;
  @override
  String? get profileImage;
  @override
  String? get coverImage; // ─── Personal ───────────────────────────────────────────────
  @override
  String? get bio;
  @override
  String? get gender;
  @override
  DateTime? get birthDate;
  @override
  String? get country;
  @override
  String? get city;
  @override
  String? get website; // ─── Contact & payroll (operations — stored on the same users doc) ──
  /// Home / mailing address. Self-editable.
  @override
  String? get address;

  /// Emergency contact (name · phone). Self-editable.
  @override
  String? get emergencyContact;

  /// The phone / wallet / account number the salary is sent to — the one
  /// compensation field the employee edits themselves. The admin-only salary
  /// fields (amount / type / method) are NOT part of the profile contract.
  @override
  String? get paymentNumber; // ─── Account ────────────────────────────────────────────────
  @override
  bool get isVerified;
  @override
  String get accountStatus;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt; // ─── Presence ───────────────────────────────────────────────
  @override
  bool get isOnline;
  @override
  DateTime? get lastSeen; // ─── Settings ───────────────────────────────────────────────
  @override
  bool get isProfilePublic;
  @override
  bool get allowMessages;
  @override
  bool get allowNotifications;

  /// Create a copy of ProfileEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProfileEntityImplCopyWith<_$ProfileEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
