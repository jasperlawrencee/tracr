import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../items/data/item_repository.dart';
import '../domain/seller.dart';

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  return SellerRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userSellersStreamProvider = StreamProvider<List<Seller>>((ref) {
  return ref.watch(sellerRepositoryProvider).watchSellers();
});

/// Plain field edits only (name/platform/contactUrl/trustRating). The
/// stashedCount/stashedValue/oldestStashAt rollups are only ever touched
/// from ItemRepository's batched operations (purchase/consolidate/delete) so
/// there is exactly one place that can drift them out of sync — don't add a
/// second update path for those fields here.
class SellerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SellerRepository(this._firestore, this._auth);

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _sellers {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('sellers');
  }

  Stream<List<Seller>> watchSellers() {
    final collection = _sellers;
    if (collection == null) return Stream.value([]);
    return collection.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Seller.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<Seller?> watchSeller(String id) {
    final collection = _sellers;
    if (collection == null) return Stream.value(null);
    return collection.doc(id).snapshots().map(
          (doc) => doc.exists ? Seller.fromMap(doc.data()!, doc.id) : null,
        );
  }

  Future<String> addSeller({
    required String name,
    String? platform,
    String? contactUrl,
    double? trustRating,
  }) async {
    final collection = _sellers;
    if (collection == null) throw Exception('User not authenticated.');
    final ref = collection.doc();
    await ref.set(
      Seller(id: ref.id, name: name, platform: platform, contactUrl: contactUrl, trustRating: trustRating)
          .toMap(),
    );
    return ref.id;
  }

  Future<void> updateSeller(
    String id, {
    String? name,
    String? platform,
    String? contactUrl,
    double? trustRating,
  }) async {
    final collection = _sellers;
    if (collection == null) return;

    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (platform != null) patch['platform'] = platform;
    if (contactUrl != null) patch['contactUrl'] = contactUrl;
    if (trustRating != null) patch['trustRating'] = trustRating;
    if (patch.isEmpty) return;

    await collection.doc(id).update(patch);
  }
}
