import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../items/data/item_repository.dart';
import '../domain/user_profile.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseStorageProvider),
  );
});

/// Watched by the router to decide whether onboarding is done — a null
/// value (no `users/{uid}` doc) means onboarding hasn't been completed.
///
/// Depends on the authenticated uid (not just profileRepositoryProvider) so
/// this rebuilds — and re-subscribes to Firestore — whenever sign-in state
/// changes. Without that, a subscription created before login captures a
/// null uid, returns a one-shot `Stream.value(null)`, and never sees the
/// profile doc that gets created once the user actually signs in.
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(authStateChangesProvider.select((auth) => auth.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile();
});

class UsernameTakenException implements Exception {}

class ProfileRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProfileRepository(this._firestore, this._auth, this._storage);

  String? get _currentUserId => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _profileDoc {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Stream<UserProfile?> watchProfile() {
    final doc = _profileDoc;
    if (doc == null) return Stream.value(null);
    return doc.snapshots().map(
          (snap) => snap.exists ? UserProfile.fromMap(snap.data()!, snap.id) : null,
        );
  }

  /// UX hint only — the authoritative check happens server-side when
  /// [claimUsernameAndCreateProfile] tries to create the registry doc.
  Future<bool> isUsernameAvailable(String usernameLower) async {
    final doc = await _firestore.collection('usernames').doc(usernameLower).get();
    return !doc.exists;
  }

  /// Downscaled 512x512 JPEG bytes to `avatars/{uid}/avatar.jpg`. The fixed
  /// filename means a re-upload overwrites in place — no orphaned files if
  /// the user changes their photo again later.
  Future<String> uploadAvatar(Uint8List jpeg) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated.');

    final ref = _storage.ref('avatars/$uid/avatar.jpg');
    await ref.putData(
      jpeg,
      SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=604800'),
    );
    return ref.getDownloadURL();
  }

  /// Claims [usernameLower] and creates the profile doc in one atomic batch.
  /// Firestore rules allow `create` but never `update` on `usernames/{name}`,
  /// so a name that's already taken makes the whole batch fail server-side —
  /// throws [UsernameTakenException] in that case.
  Future<void> claimUsernameAndCreateProfile({
    required String username,
    required String usernameLower,
    String? photoUrl,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated.');

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.set(_firestore.collection('usernames').doc(usernameLower), {
      'uid': uid,
      'createdAt': now.millisecondsSinceEpoch,
    });
    batch.set(
      _firestore.collection('users').doc(uid),
      UserProfile(
        uid: uid,
        username: username,
        usernameLower: usernameLower,
        photoUrl: photoUrl,
        createdAt: now,
      ).toMap(),
    );

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw UsernameTakenException();
      rethrow;
    }
  }
}
