/// Pure, dependency-free `{{placeholder}}` rendering engine for broadcast
/// templates (Communications Center — Phase 2). Lives in `domain` so it can be
/// unit-tested and reused by both the composer (live preview) and the send path.
///
/// Tokens look like `{{employee_name}}` — letters, digits and underscores,
/// optionally surrounded by whitespace inside the braces. The common OpsHub
/// placeholders are `employee_name`, `task_name`, `branch_name`, `date`, and
/// `sender_name`, but the engine is generic over any key.
class TemplateRenderer {
  const TemplateRenderer._();

  static final RegExp _token = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  /// The placeholder **keys** referenced in [text], in first-seen order, without
  /// duplicates.
  static List<String> extract(String text) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final m in _token.allMatches(text)) {
      final key = m.group(1)!;
      if (seen.add(key)) ordered.add(key);
    }
    return ordered;
  }

  /// Replaces every `{{key}}` in [text] for which [context] has a value. Tokens
  /// whose key is absent from [context] are left **untouched** (so the composer
  /// can flag unresolved placeholders) unless [blankMissing] is true, in which
  /// case they render to an empty string.
  static String render(
    String text,
    Map<String, String> context, {
    bool blankMissing = false,
  }) {
    return text.replaceAllMapped(_token, (m) {
      final key = m.group(1)!;
      if (context.containsKey(key)) return context[key] ?? '';
      return blankMissing ? '' : m.group(0)!;
    });
  }

  /// Whether [text] still contains any unresolved token after rendering with
  /// [context] (useful for a "fill in the blanks" warning before send).
  static bool hasUnresolved(String text, Map<String, String> context) {
    for (final m in _token.allMatches(text)) {
      if (!context.containsKey(m.group(1))) return true;
    }
    return false;
  }
}
