import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemStage { wishlist, stashed, inTransit, inHand, archived }

enum Priority {
  someday,
  want,
  mustHave;

  /// Higher rank sorts first — mustHave is always the top of a wishlist.
  int get sortRank => index;
}

enum Condition { nm, lp, mp, hp, dmg }

/// Why an item left the active collection.
enum Disposition { sold, traded, lost, returned }

/// A user-defined label/value pair, e.g. ("Set", "Scarlet & Violet 151") for
/// a card, ("Pop Number", "1245") for a Funko, ("Edition", "1st Print") for
/// a sealed box. Lets the item form adapt to whatever kind of collectible
/// the category actually is instead of hardcoding TCG-specific fields.
class ItemAttribute {
  final String label;
  final String value;

  const ItemAttribute({required this.label, required this.value});

  factory ItemAttribute.fromMap(Map<String, dynamic> map) {
    return ItemAttribute(label: map['label'] ?? '', value: map['value'] ?? '');
  }

  Map<String, dynamic> toMap() => {'label': label, 'value': value};
}

class Grading {
  final String company; // PSA, BGS, CGC
  final double grade; // 9.5
  final String? certNo;

  const Grading({required this.company, required this.grade, this.certNo});

  factory Grading.fromMap(Map<String, dynamic> map) {
    return Grading(
      company: map['company'] ?? '',
      grade: (map['grade'] as num?)?.toDouble() ?? 0.0,
      certNo: map['certNo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'company': company, 'grade': grade, 'certNo': certNo};
  }
}

DateTime? _dateFromField(dynamic field) {
  if (field == null) return null;
  if (field is Timestamp) return field.toDate();
  if (field is int) return DateTime.fromMillisecondsSinceEpoch(field);
  return null;
}

class Item {
  final String id;
  final String userId;
  final String name;
  final List<ItemAttribute> attributes;
  final String category;
  final int quantity;
  final ItemStage stage;

  final double? targetPrice;
  final double? marketValue;
  final double? pricePaid;
  final Priority priority;
  final String? sourceUrl;

  final String? sellerId;
  final String? sellerName;

  final String? shipmentId;

  final String? containerId;
  final String? containerName;
  final String? slot;
  final Condition? condition;
  final Grading? grading;
  final bool isForSale;

  final Disposition? disposition;

  final List<String> tags;
  final String? imageUrl;
  final String? notes;

  final DateTime createdAt;
  final DateTime? purchasedAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;

  const Item({
    required this.id,
    required this.userId,
    required this.name,
    this.attributes = const [],
    required this.category,
    this.quantity = 1,
    required this.stage,
    this.targetPrice,
    this.marketValue,
    this.pricePaid,
    this.priority = Priority.want,
    this.sourceUrl,
    this.sellerId,
    this.sellerName,
    this.shipmentId,
    this.containerId,
    this.containerName,
    this.slot,
    this.condition,
    this.grading,
    this.isForSale = false,
    this.disposition,
    this.tags = const [],
    this.imageUrl,
    this.notes,
    required this.createdAt,
    this.purchasedAt,
    this.shippedAt,
    this.receivedAt,
  });

  factory Item.fromMap(Map<String, dynamic> map, String docId) {
    return Item(
      id: docId,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      attributes: map['attributes'] == null
          ? const []
          : List<Map<String, dynamic>>.from(
              (map['attributes'] as List).map((e) => Map<String, dynamic>.from(e)),
            ).map(ItemAttribute.fromMap).toList(),
      category: map['category'] ?? 'General',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      stage: ItemStage.values.firstWhere(
        (e) => e.name == map['stage'],
        orElse: () => ItemStage.wishlist,
      ),
      targetPrice: (map['targetPrice'] as num?)?.toDouble(),
      marketValue: (map['marketValue'] as num?)?.toDouble(),
      pricePaid: (map['pricePaid'] as num?)?.toDouble(),
      priority: Priority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => Priority.want,
      ),
      sourceUrl: map['sourceUrl'],
      sellerId: map['sellerId'],
      sellerName: map['sellerName'],
      shipmentId: map['shipmentId'],
      containerId: map['containerId'],
      containerName: map['containerName'],
      slot: map['slot'],
      condition: map['condition'] == null
          ? null
          : Condition.values.firstWhere(
              (e) => e.name == map['condition'],
              orElse: () => Condition.nm,
            ),
      grading: map['grading'] == null
          ? null
          : Grading.fromMap(Map<String, dynamic>.from(map['grading'])),
      isForSale: map['isForSale'] ?? false,
      disposition: map['disposition'] == null
          ? null
          : Disposition.values.firstWhere(
              (e) => e.name == map['disposition'],
              orElse: () => Disposition.sold,
            ),
      tags: map['tags'] == null ? const [] : List<String>.from(map['tags']),
      imageUrl: map['imageUrl'],
      notes: map['notes'],
      createdAt: _dateFromField(map['createdAt']) ?? DateTime.now(),
      purchasedAt: _dateFromField(map['purchasedAt']),
      shippedAt: _dateFromField(map['shippedAt']),
      receivedAt: _dateFromField(map['receivedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'attributes': attributes.map((a) => a.toMap()).toList(),
      'category': category,
      'quantity': quantity,
      'stage': stage.name,
      'targetPrice': targetPrice,
      'marketValue': marketValue,
      'pricePaid': pricePaid,
      'priority': priority.name,
      'sourceUrl': sourceUrl,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'shipmentId': shipmentId,
      'containerId': containerId,
      'containerName': containerName,
      'slot': slot,
      'condition': condition?.name,
      'grading': grading?.toMap(),
      'isForSale': isForSale,
      'disposition': disposition?.name,
      'tags': tags,
      'imageUrl': imageUrl,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'purchasedAt': purchasedAt == null ? null : Timestamp.fromDate(purchasedAt!),
      'shippedAt': shippedAt == null ? null : Timestamp.fromDate(shippedAt!),
      'receivedAt': receivedAt == null ? null : Timestamp.fromDate(receivedAt!),
    };
  }
}

/// Shared free-text search used by every module page's search bar (Wishlist,
/// Stash, Tracking, In Hand) — one definition of "does this item match"
/// instead of each page reinventing its own substring checks.
extension ItemSearch on Item {
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    bool has(String? field) => field != null && field.toLowerCase().contains(q);

    return has(name) ||
        has(category) ||
        has(sellerName) ||
        has(containerName) ||
        has(sourceUrl) ||
        has(notes) ||
        has(grading?.company) ||
        tags.any((t) => t.toLowerCase().contains(q)) ||
        attributes.any((a) => a.label.toLowerCase().contains(q) || a.value.toLowerCase().contains(q));
  }
}
