import 'package:cloud_firestore/cloud_firestore.dart';
import 'item.dart';

enum ItemEventType { created, stageChanged, priceUpdated, moved, noteAdded }

class ItemEvent {
  final String id;
  final ItemEventType type;
  final ItemStage? fromStage;
  final ItemStage? toStage;
  final String? detail;
  final DateTime at;

  const ItemEvent({
    required this.id,
    required this.type,
    this.fromStage,
    this.toStage,
    this.detail,
    required this.at,
  });

  factory ItemEvent.fromMap(Map<String, dynamic> map, String docId) {
    return ItemEvent(
      id: docId,
      type: ItemEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ItemEventType.noteAdded,
      ),
      fromStage: map['fromStage'] == null
          ? null
          : ItemStage.values.firstWhere(
              (e) => e.name == map['fromStage'],
              orElse: () => ItemStage.wishlist,
            ),
      toStage: map['toStage'] == null
          ? null
          : ItemStage.values.firstWhere(
              (e) => e.name == map['toStage'],
              orElse: () => ItemStage.wishlist,
            ),
      detail: map['detail'],
      at: map['at'] is Timestamp
          ? (map['at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'fromStage': fromStage?.name,
      'toStage': toStage?.name,
      'detail': detail,
      'at': Timestamp.fromDate(at),
    };
  }
}
