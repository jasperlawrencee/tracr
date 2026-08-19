import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../containers/domain/storage_container.dart';
import '../../sellers/domain/seller.dart';
import '../../shipments/domain/shipment.dart';
import '../domain/item.dart';
import '../domain/item_event.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userItemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final repo = ref.watch(itemRepositoryProvider);
  return repo.watchUserItems();
});

class ItemRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ItemRepository(this._firestore, this._auth);

  String? get _currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _userCollection(String name) {
    final uid = _currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection(name);
  }

  CollectionReference<Map<String, dynamic>>? get _items => _userCollection('items');
  CollectionReference<Map<String, dynamic>>? get _sellers => _userCollection('sellers');
  CollectionReference<Map<String, dynamic>>? get _shipments => _userCollection('shipments');
  CollectionReference<Map<String, dynamic>>? get _containers => _userCollection('containers');

  Stream<List<Item>> watchUserItems() {
    final collection = _items;
    if (collection == null) return Stream.value([]);
    return collection.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => Item.fromMap(d.data(), d.id)).toList(),
        );
  }

  Stream<List<ItemEvent>> watchItemEvents(String itemId) {
    final collection = _items;
    if (collection == null) return Stream.value([]);
    return collection
        .doc(itemId)
        .collection('events')
        .orderBy('at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ItemEvent.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addItem(Item item) async {
    final collection = _items;
    if (collection == null) throw Exception('User not authenticated.');

    final docRef = await collection.add(item.toMap());
    await docRef.collection('events').add(
          ItemEvent(id: '', type: ItemEventType.created, toStage: item.stage, at: DateTime.now())
              .toMap(),
        );
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> patch) async {
    final collection = _items;
    if (collection == null) return;
    await collection.doc(itemId).update(patch);
  }

  Future<void> deleteItem(Item item) async {
    final items = _items;
    if (items == null) return;

    final itemRef = items.doc(item.id);
    final eventsSnap = await itemRef.collection('events').get();

    final batch = _firestore.batch();
    for (final doc in eventsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(itemRef);

    switch (item.stage) {
      case ItemStage.stashed:
        final sellers = _sellers;
        if (sellers != null && item.sellerId != null) {
          batch.update(sellers.doc(item.sellerId), {
            'stashedCount': FieldValue.increment(-1),
            'stashedValue': FieldValue.increment(-(item.pricePaid ?? 0)),
          });
        }
        break;
      case ItemStage.inTransit:
        final shipments = _shipments;
        if (shipments != null && item.shipmentId != null) {
          batch.update(shipments.doc(item.shipmentId), {
            'itemCount': FieldValue.increment(-1),
          });
        }
        break;
      case ItemStage.inHand:
        final containers = _containers;
        if (containers != null && item.containerId != null) {
          batch.update(containers.doc(item.containerId), {
            'itemCount': FieldValue.increment(-1),
            'totalValue': FieldValue.increment(-(item.marketValue ?? 0)),
          });
        }
        break;
      case ItemStage.wishlist:
      case ItemStage.archived:
        break;
    }

    await batch.commit();
  }

  Future<void> purchase({
    required String itemId,
    Seller? existingSeller,
    String? newSellerName,
    String? newSellerPlatform,
    required double pricePaid,
  }) async {
    final items = _items;
    final sellers = _sellers;
    if (items == null || sellers == null) throw Exception('User not authenticated.');
    if (existingSeller == null && (newSellerName == null || newSellerName.trim().isEmpty)) {
      throw ArgumentError('Provide either an existing seller or a new seller name.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    late final String sellerId;
    late final String sellerName;

    if (existingSeller != null) {
      sellerId = existingSeller.id;
      sellerName = existingSeller.name;
      final update = <String, dynamic>{
        'stashedCount': FieldValue.increment(1),
        'stashedValue': FieldValue.increment(pricePaid),
      };
      if (existingSeller.stashedCount == 0) {
        update['oldestStashAt'] = Timestamp.fromDate(now);
      }
      batch.update(sellers.doc(sellerId), update);
    } else {
      final sellerRef = sellers.doc();
      sellerId = sellerRef.id;
      sellerName = newSellerName!.trim();
      batch.set(
        sellerRef,
        Seller(
          id: sellerId,
          name: sellerName,
          platform: newSellerPlatform,
          stashedCount: 1,
          stashedValue: pricePaid,
          oldestStashAt: now,
        ).toMap(),
      );
    }

    final itemRef = items.doc(itemId);
    batch.update(itemRef, {
      'stage': ItemStage.stashed.name,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'pricePaid': pricePaid,
      'purchasedAt': Timestamp.fromDate(now),
    });
    batch.set(
      itemRef.collection('events').doc(),
      ItemEvent(
        id: '',
        type: ItemEventType.stageChanged,
        fromStage: ItemStage.wishlist,
        toStage: ItemStage.stashed,
        detail: 'Bought from $sellerName',
        at: now,
      ).toMap(),
    );

    await batch.commit();
  }

  Future<String> consolidate({
    required String sellerId,
    required List<Item> items,
    required Courier courier,
    required String trackingNumber,
    double? shippingCost,
  }) async {
    final itemsCol = _items;
    final sellers = _sellers;
    final shipments = _shipments;
    if (itemsCol == null || sellers == null || shipments == null) {
      throw Exception('User not authenticated.');
    }
    if (items.isEmpty) throw ArgumentError('Select at least one item to ship.');

    final now = DateTime.now();
    final shipRef = shipments.doc();
    final movingIds = items.map((i) => i.id).toSet();

    final remainingSnap = await itemsCol
        .where('sellerId', isEqualTo: sellerId)
        .where('stage', isEqualTo: ItemStage.stashed.name)
        .orderBy('purchasedAt')
        .limit(movingIds.length + 1)
        .get();
    Timestamp? newOldestStashAt;
    for (final doc in remainingSnap.docs) {
      if (movingIds.contains(doc.id)) continue;
      final purchasedAt = doc.data()['purchasedAt'];
      if (purchasedAt is Timestamp) newOldestStashAt = purchasedAt;
      break;
    }

    final batch = _firestore.batch();

    batch.set(
      shipRef,
      Shipment(
        id: shipRef.id,
        sellerId: sellerId,
        courier: courier,
        trackingNumber: trackingNumber,
        status: ShipmentStatus.inTransit,
        shippingCost: shippingCost,
        shippedAt: now,
        itemCount: items.length,
      ).toMap(),
    );

    var movedValue = 0.0;
    for (final item in items) {
      movedValue += item.pricePaid ?? 0;
      final itemRef = itemsCol.doc(item.id);
      batch.update(itemRef, {
        'stage': ItemStage.inTransit.name,
        'shipmentId': shipRef.id,
        'shippedAt': Timestamp.fromDate(now),
      });
      batch.set(
        itemRef.collection('events').doc(),
        ItemEvent(
          id: '',
          type: ItemEventType.stageChanged,
          fromStage: ItemStage.stashed,
          toStage: ItemStage.inTransit,
          detail: 'Consolidated into shipment $trackingNumber',
          at: now,
        ).toMap(),
      );
    }

    batch.update(sellers.doc(sellerId), {
      'stashedCount': FieldValue.increment(-items.length),
      'stashedValue': FieldValue.increment(-movedValue),
      'oldestStashAt': newOldestStashAt,
    });

    await batch.commit();
    return shipRef.id;
  }

  Future<void> receive(
    String shipmentId, {
    required List<Item> items,
    required Map<String, StorageContainer> placements,
  }) async {
    final itemsCol = _items;
    final shipments = _shipments;
    final containers = _containers;
    if (itemsCol == null || shipments == null || containers == null) {
      throw Exception('User not authenticated.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.update(shipments.doc(shipmentId), {
      'status': ShipmentStatus.delivered.name,
      'deliveredAt': Timestamp.fromDate(now),
    });

    final containerCounts = <String, int>{};
    final containerValues = <String, double>{};

    for (final item in items) {
      final container = placements[item.id];
      if (container == null) continue;

      final itemRef = itemsCol.doc(item.id);
      batch.update(itemRef, {
        'stage': ItemStage.inHand.name,
        'containerId': container.id,
        'containerName': container.name,
        'receivedAt': Timestamp.fromDate(now),
      });
      batch.set(
        itemRef.collection('events').doc(),
        ItemEvent(
          id: '',
          type: ItemEventType.stageChanged,
          fromStage: ItemStage.inTransit,
          toStage: ItemStage.inHand,
          detail: 'Placed in ${container.name}',
          at: now,
        ).toMap(),
      );

      containerCounts[container.id] = (containerCounts[container.id] ?? 0) + 1;
      containerValues[container.id] = (containerValues[container.id] ?? 0) + (item.marketValue ?? 0);
    }

    for (final containerId in containerCounts.keys) {
      batch.update(containers.doc(containerId), {
        'itemCount': FieldValue.increment(containerCounts[containerId]!),
        'totalValue': FieldValue.increment(containerValues[containerId]!),
      });
    }

    await batch.commit();
  }

  Future<String> shipOne(
    Item item,
    Courier courier,
    String trackingNumber, {
    double? shippingCost,
  }) {
    if (item.sellerId == null) {
      throw ArgumentError('Item has no seller to ship from.');
    }
    return consolidate(
      sellerId: item.sellerId!,
      items: [item],
      courier: courier,
      trackingNumber: trackingNumber,
      shippingCost: shippingCost,
    );
  }

  Future<void> receiveOne(String shipmentId, Item item, StorageContainer container) {
    return receive(shipmentId, items: [item], placements: {item.id: container});
  }

  Future<void> editItem(
    Item current, {
    required String name,
    required String category,
    required int quantity,
    double? marketValue,
    double? targetPrice,
    double? pricePaid,
    required Priority priority,
    String? sourceUrl,
    Condition? condition,
    Grading? grading,
    required bool isForSale,
    required List<String> tags,
    required List<ItemAttribute> attributes,
    String? notes,
  }) async {
    final items = _items;
    if (items == null) throw Exception('User not authenticated.');

    final batch = _firestore.batch();
    batch.update(items.doc(current.id), {
      'name': name,
      'category': category,
      'quantity': quantity,
      'marketValue': marketValue,
      'targetPrice': targetPrice,
      'pricePaid': pricePaid,
      'priority': priority.name,
      'sourceUrl': sourceUrl,
      'condition': condition?.name,
      'grading': grading?.toMap(),
      'isForSale': isForSale,
      'tags': tags,
      'attributes': attributes.map((a) => a.toMap()).toList(),
      'notes': notes,
    });

    if (current.stage == ItemStage.inHand && current.containerId != null) {
      final delta = (marketValue ?? 0) - (current.marketValue ?? 0);
      final containers = _containers;
      if (delta != 0 && containers != null) {
        batch.update(containers.doc(current.containerId), {'totalValue': FieldValue.increment(delta)});
      }
    }

    if (current.stage == ItemStage.stashed && current.sellerId != null) {
      final delta = (pricePaid ?? 0) - (current.pricePaid ?? 0);
      final sellers = _sellers;
      if (delta != 0 && sellers != null) {
        batch.update(sellers.doc(current.sellerId), {'stashedValue': FieldValue.increment(delta)});
      }
    }

    batch.set(
      items.doc(current.id).collection('events').doc(),
      ItemEvent(id: '', type: ItemEventType.priceUpdated, detail: 'Details edited', at: DateTime.now())
          .toMap(),
    );

    await batch.commit();
  }
}
