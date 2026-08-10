import 'package:flutter/material.dart';

const _palette = [
  Color(0xFF6366F1),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFEF4444),
  Color(0xFFF97316),
  Color(0xFF16A34A),
  Color(0xFF0891B2),
  Color(0xFF2563EB),
];

/// Renders [photoUrl] when set; otherwise falls back to initials generated
/// from [username] on a deterministic background color, and also uses those
/// initials as the loading/error state for a broken or slow-loading photo.
class UserAvatar extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final double radius;

  const UserAvatar({super.key, required this.username, this.photoUrl, this.radius = 20});

  static String _initialsFor(String username) {
    final parts = username.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (username.length >= 2) return username.substring(0, 2).toUpperCase();
    if (username.isNotEmpty) return username.substring(0, 1).toUpperCase();
    return '?';
  }

  static Color _colorFor(String username) {
    if (username.isEmpty) return _palette.first;
    final sum = username.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(username.toLowerCase());
    final color = _colorFor(username.toLowerCase());

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.8,
        ),
      ),
    );

    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundImage: NetworkImage(url),
      onForegroundImageError: (_, _) {},
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
