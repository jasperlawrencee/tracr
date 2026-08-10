class UserProfile {
  final String uid;
  final String username;
  final String usernameLower;
  final String? photoUrl;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.usernameLower,
    this.photoUrl,
    required this.createdAt,
  });

  bool get isOnboardingComplete => username.isNotEmpty;

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      username: map['username'] ?? '',
      usernameLower: map['usernameLower'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'usernameLower': usernameLower,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
