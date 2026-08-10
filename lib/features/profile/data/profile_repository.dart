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

  Future<bool> isUsernameAvailable(String usernameLower) async {
    final doc = await _firestore.collection('usernames').doc(usernameLower).get();
    return !doc.exists;
  }

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
