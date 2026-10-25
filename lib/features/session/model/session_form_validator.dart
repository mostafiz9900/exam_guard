/// Rules for the exam setup form. Every check returns a translation key
/// (with [args] where the message needs numbers), or null when the value is
/// fine. Bangla and Arabic letters count as letters.
abstract final class SessionFormValidator {
  static const int roomMaxLength = 20;
  static const int instituteMaxLength = 80;
  static const int supervisorMinLength = 2;
  static const int supervisorMaxLength = 50;

  /// Characters a room number may contain: letters, digits, space and
  /// `- / . # ( )` (e.g. "302-B", "Hall 2/A", "Lab #3").
  static final RegExp roomAllowed = RegExp(
    r"[\p{L}\p{M}\p{N} \-/.#()]",
    unicode: true,
  );

  /// Characters a person's name may contain: letters, space and `. ' -`.
  static final RegExp nameAllowed = RegExp(r"[\p{L}\p{M} .'\-]", unicode: true);

  /// Characters never allowed in the institute name (markup / code noise).
  static final RegExp instituteBlocked = RegExp(r'[<>{}\[\]|\\^~`]');

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _digit = RegExp(r'\p{N}', unicode: true);
  static final RegExp _spaces = RegExp(r'\s+');

  /// Trims and collapses repeated whitespace (what gets saved).
  static String clean(String value) => value.trim().replaceAll(_spaces, ' ');

  static String? room(String value) {
    final v = clean(value);
    if (v.isEmpty) return 'room_required';
    if (v.length > roomMaxLength) return 'room_too_long';
    if (!_onlyAllowed(v, roomAllowed)) return 'room_invalid_chars';
    if (!_letterOrDigit.hasMatch(v)) return 'room_invalid_chars';
    return null;
  }

  static String? institute(String value) {
    final v = clean(value);
    if (v.isEmpty) return null;
    if (v.length > instituteMaxLength) return 'institute_too_long';
    if (instituteBlocked.hasMatch(v)) return 'institute_invalid_chars';
    if (!_letter.hasMatch(v)) return 'institute_needs_letters';
    return null;
  }

  static String? supervisor(String value) {
    final v = clean(value);
    if (v.isEmpty) return null;
    if (_digit.hasMatch(v)) return 'supervisor_no_digits';
    if (!_onlyAllowed(v, nameAllowed)) return 'supervisor_invalid_chars';
    if (!_letter.hasMatch(v)) return 'supervisor_invalid_chars';
    if (v.length < supervisorMinLength) return 'supervisor_too_short';
    if (v.length > supervisorMaxLength) return 'supervisor_too_long';
    return null;
  }

  /// Per character (rune), so Bangla vowel signs and emoji are judged
  /// correctly.
  static bool _onlyAllowed(String v, RegExp allowed) =>
      v.runes.every((r) => allowed.hasMatch(String.fromCharCode(r)));
}
