import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../items/data/item_repository.dart';
import '../../items/domain/item.dart';
import '../../items/domain/item_event.dart';
import '../domain/storage_container.dart';

final containerRepositoryProvider = Provider<ContainerRepository>((ref) {
  return ContainerRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userContainersStreamProvider = StreamProvider<List<StorageContainer>>((ref) {
  return ref.watch(containerRepositoryProvider).watchContainers();
});

/// Shared by the In Hand list page (inline item previews) and the container
/// detail page (the full editable grid) so both read from one cached stream
/// per container instead of each opening their own Firestore listener.
final itemsInContainerProvider = StreamProvider.autoDispose.family<List<Item>, String>(
  (ref, containerId) => ref.watch(containerRepositoryProvider).watchItemsInContainer(containerId),
);

class ContainerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ContainerRepository(this._firestore, this._auth);

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _userCollection(String name) {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection(name);
  }

  CollectionReference<Map<String, dynamic>>? get _containers => _userCollection('containers');
  CollectionReference<Map<String, dynamic>>? get _items => _userCollection('items');

  Stream<List<StorageContainer>> watchContainers() {
    final collection = _containers;
    if (collection == null) return Stream.value([]);
    return collection.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => StorageContainer.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<StorageContainer?> watchContainer(String id) {
    final collection = _containers;
    if (collection == null) return Stream.value(null);
    return collection.doc(id).snapshots().map(
          (doc) => doc.exists ? StorageContainer.fromMap(doc.data()!, doc.id) : null,
        );
  }

  Stream<List<Item>> watchItemsInContainer(String containerId) {
    final collection = _items;
    if (collection == null) return Stream.value([]);
    return collection
        .where('containerId', isEqualTo: containerId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Item.fromMap(d.data(), d.id)).toList());
  }

  Future<String> addContainer({
    required String name,
    ContainerType type = ContainerType.binder,
    int? capacity,
    String? colorHex,
    String? location,
  }) async {
    final collection = _containers;
    if (collection == null) throw Exception('User not authenticated.');
    final ref = collection.doc();
    await ref.set(
      StorageContainer(
        id: ref.id,
        name: name,
        type: type,
        capacity: capacity,
        colorHex: colorHex,
        location: location,
      ).toMap(),
    );
    return ref.id;
  }

  Future<void> updateContainer(
    String id, {
    String? name,
    ContainerType? type,
    int? capacity,
    String? colorHex,
    String? location,
  }) async {
    final collection = _containers;
    if (collection == null) return;

    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (type != null) patch['type'] = type.name;
    if (capacity != null) patch['capacity'] = capacity;
    if (colorHex != null) patch['colorHex'] = colorHex;
    if (location != null) patch['location'] = location;
    if (patch.isEmpty) return;

    await collection.doc(id).update(patch);
  }

  /// Rehouses [items] (all currently in [fromContainerId]) into
  /// [toContainerId], one WriteBatch. Decrements/increments itemCount and
  /// totalValue on both containers — the source design flags this rollup as
  /// needed but doesn't spell it out; this is the concrete implementation.
  Future<void> moveItems({
    required List<Item> items,
    required String fromContainerId,
    required StorageContainer toContainer,
  }) async {
    final itemsCol = _items;
    final containers = _containers;
    if (itemsCol == null || containers == null) throw Exception('User not authenticated.');
    if (items.isEmpty) return;

    final batch = _firestore.batch();
    var movedValue = 0.0;

    for (final item in items) {
      movedValue += item.marketValue ?? 0;
      batch.update(itemsCol.doc(item.id), {
        'containerId': toContainer.id,
        'containerName': toContainer.name,
      });
      batch.set(
        itemsCol.doc(item.id).collection('events').doc(),
        ItemEvent(
          id: '',
          type: ItemEventType.moved,
          detail: 'Moved to ${toContainer.name}',
          at: DateTime.now(),
        ).toMap(),
      );
    }

    batch.update(containers.doc(fromContainerId), {
      'itemCount': FieldValue.increment(-items.length),
      'totalValue': FieldValue.increment(-movedValue),
    });
    batch.update(containers.doc(toContainer.id), {
      'itemCount': FieldValue.increment(items.length),
      'totalValue': FieldValue.increment(movedValue),
    });

    await batch.commit();
  }
}
