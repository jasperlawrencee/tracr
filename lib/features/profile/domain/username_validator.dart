const reservedUsernames = {
  'admin',
  'root',
  'support',
  'tracr',
  'api',
  'help',
  'about',
  'settings',
  'login',
  'signup',
  'me',
  'new',
  'null',
  'undefined',
};

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

String? usernameValidationError(String raw) {
  final lower = raw.trim().toLowerCase();

  if (lower.isEmpty) return 'Enter a display name.';
  if (!_usernamePattern.hasMatch(lower)) {
    return '3-20 characters: lowercase letters, numbers, and underscores only.';
  }
  if (lower.startsWith('_') || lower.endsWith('_')) {
    return "Can't start or end with an underscore.";
  }
  if (lower.contains('__')) return "Can't contain consecutive underscores.";
  if (reservedUsernames.contains(lower)) return 'That name is reserved.';

  return null;
}
