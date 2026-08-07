import 'package:flutter/services.dart';

/// Shared input validators for user-entered fields (profile completion, admin
/// create / edit account). Pure & null-safe: each returns `null` when valid or
/// a short error string suitable for a `TextFormField.validator`.
///
/// Unicode-aware (`\p{L}`) so Arabic names and addresses pass. Phone validation
/// guarantees an actual **number** — never an email or free text — which is the
/// core requirement: a field that must hold a number rejects letters and `@`.
///
/// Each validator takes `required` so the same rule serves a mandatory field
/// (onboarding) and an optional one (admin "Edit details", where an empty value
/// intentionally clears the field) — when not required, an empty value passes
/// but a *non-empty* value is still format-checked.
class Validators {
  Validators._();

  /// Live input filter for phone fields — allows digits and the punctuation a
  /// phone number can contain. Use as `inputFormatters: [Validators.phoneInput]`
  /// so letters / `@` can't even be typed (belt-and-suspenders with [phone]).
  static final FilteringTextInputFormatter phoneInput =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-()\s]'));

  /// A phone number: digits + ` + - ( ) ` and spaces only, 7–15 digits.
  static String? phone(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter a phone number' : null;
    if (!RegExp(r'^[0-9+\-()\s]+$').hasMatch(v)) {
      return 'Numbers only — no letters or @';
    }
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// A person's name: letters (any language), spaces, and `. ' -` only — no
  /// digits or symbols.
  static String? name(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter a full name' : null;
    if (v.length < 2) return 'Name is too short';
    if (!RegExp(r"^[\p{L}\s.'-]+$", unicode: true).hasMatch(v)) {
      return 'Letters only — no numbers or symbols';
    }
    return null;
  }

  /// A street address: free text, but at least minimally complete.
  static String? address(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter an address' : null;
    if (v.length < 5) return 'Enter a more complete address';
    return null;
  }

  /// An emergency contact ("Name · phone"): must contain a phone number.
  static String? emergencyContact(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter an emergency contact' : null;
    if (v.length < 5) return 'Include a name and phone number';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include a phone number';
    return null;
  }

  /// Live input filter for the username field — lowercase letters, digits,
  /// `_` and `.` only, so an invalid handle cannot even be typed. Deliberately
  /// ASCII: the handle is an identifier, not a display name (that is
  /// `fullName`, which is Unicode-aware).
  static final TextInputFormatter usernameInput =
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]'));

  /// A `@handle`: 3–20 characters of letters, digits, `_` or `.`, starting with
  /// a letter. Stored lowercase (the repository lowercases on write and the
  /// availability check is case-insensitive), so `Ziad` and `ziad` are the same
  /// handle and cannot both exist.
  static String? username(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Choose a username' : null;
    if (v.length < 3) return 'At least 3 characters';
    if (v.length > 20) return 'At most 20 characters';
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9._]*$').hasMatch(v)) {
      return 'Letters, numbers, . and _ — start with a letter';
    }
    return null;
  }

  /// An email address.
  static String? email(String? value, {bool required = true}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return required ? 'Enter an email' : null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email';
    }
    return null;
  }
}
