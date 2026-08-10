import 'package:cloud_firestore/cloud_firestore.dart';

class Seller {
  final String id;
  final String name;
  final String? platform; // Facebook · Shopee · Carousell · IG · shop
  final String? contactUrl;
  final double? trustRating; // your own 1–5

  // rollups — maintained by ItemRepository's batched operations, not edited directly.
  final int stashedCount;
  final double stashedValue;
  final DateTime? oldestStashAt; // powers the stash-age warning

  const Seller({
    required this.id,
    required this.name,
    this.platform,
    this.contactUrl,
    this.trustRating,
    this.stashedCount = 0,
    this.stashedValue = 0,
    this.oldestStashAt,
  });

  factory Seller.fromMap(Map<String, dynamic> map, String docId) {
    return Seller(
      id: docId,
      name: map['name'] ?? '',
      platform: map['platform'],
      contactUrl: map['contactUrl'],
      trustRating: (map['trustRating'] as num?)?.toDouble(),
      stashedCount: (map['stashedCount'] as num?)?.toInt() ?? 0,
      stashedValue: (map['stashedValue'] as num?)?.toDouble() ?? 0,
      oldestStashAt: map['oldestStashAt'] is Timestamp
          ? (map['oldestStashAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'platform': platform,
      'contactUrl': contactUrl,
      'trustRating': trustRating,
      'stashedCount': stashedCount,
      'stashedValue': stashedValue,
      'oldestStashAt': oldestStashAt == null ? null : Timestamp.fromDate(oldestStashAt!),
    };
  }
}
