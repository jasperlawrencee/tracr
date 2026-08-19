import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../items/data/item_repository.dart';
import '../domain/shipment.dart';

final shipmentRepositoryProvider = Provider<ShipmentRepository>((ref) {
  return ShipmentRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userShipmentsStreamProvider = StreamProvider<List<Shipment>>((ref) {
  return ref.watch(shipmentRepositoryProvider).watchShipments();
});

class ShipmentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ShipmentRepository(this._firestore, this._auth);

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _shipments {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('shipments');
  }

  Stream<List<Shipment>> watchShipments() {
    final collection = _shipments;
    if (collection == null) return Stream.value([]);
    // Status ordering is applied client-side (see ShipmentStatusX.sortRank) so
    // the list groups by delivery progress rather than by enum name.
    return collection
        .orderBy('shippedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Shipment.fromMap(d.data(), d.id)).toList());
  }

  Stream<Shipment?> watchShipment(String id) {
    final collection = _shipments;
    if (collection == null) return Stream.value(null);
    return collection.doc(id).snapshots().map(
          (doc) => doc.exists ? Shipment.fromMap(doc.data()!, doc.id) : null,
        );
  }
}
