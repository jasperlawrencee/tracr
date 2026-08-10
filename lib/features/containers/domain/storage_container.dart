enum ContainerType { binder, deckBox, toploaderCase, displayShelf, storageBox, safe }

extension ContainerTypeX on ContainerType {
  String get label {
    switch (this) {
      case ContainerType.binder:
        return 'Binder';
      case ContainerType.deckBox:
        return 'Deck Box';
      case ContainerType.toploaderCase:
        return 'Toploader Case';
      case ContainerType.displayShelf:
        return 'Display Shelf';
      case ContainerType.storageBox:
        return 'Storage Box';
      case ContainerType.safe:
        return 'Safe';
    }
  }
}

class StorageContainer {
  final String id;
  final String name; // "Binder 1 — Vintage"
  final ContainerType type;
  final int? capacity; // 9-pocket × 20 pages = 360
  final String? colorHex; // visual identity in the UI
  final String? location; // "Bedroom shelf"

  // rollups — maintained by ItemRepository / ContainerRepository batched ops.
  final int itemCount;
  final double totalValue;

  const StorageContainer({
    required this.id,
    required this.name,
    this.type = ContainerType.binder,
    this.capacity,
    this.colorHex,
    this.location,
    this.itemCount = 0,
    this.totalValue = 0,
  });

  factory StorageContainer.fromMap(Map<String, dynamic> map, String docId) {
    return StorageContainer(
      id: docId,
      name: map['name'] ?? '',
      type: ContainerType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ContainerType.binder,
      ),
      capacity: (map['capacity'] as num?)?.toInt(),
      colorHex: map['colorHex'],
      location: map['location'],
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      totalValue: (map['totalValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'capacity': capacity,
      'colorHex': colorHex,
      'location': location,
      'itemCount': itemCount,
      'totalValue': totalValue,
    };
  }
}
