import 'package:cloud_firestore/cloud_firestore.dart';

enum ShipmentStatus { pending, inTransit, outForDelivery, delivered, delayed, lost }

enum Courier { jnt, lbc, ninjaVan, flashExpress, jrs, other }

extension ShipmentStatusX on ShipmentStatus {
  String get label {
    switch (this) {
      case ShipmentStatus.pending:
        return 'Pending';
      case ShipmentStatus.inTransit:
        return 'In Transit';
      case ShipmentStatus.outForDelivery:
        return 'Out for Delivery';
      case ShipmentStatus.delivered:
        return 'Delivered';
      case ShipmentStatus.delayed:
        return 'Delayed';
      case ShipmentStatus.lost:
        return 'Lost';
    }
  }

  bool get isDelivered => this == ShipmentStatus.delivered;

  // Still-moving shipments sort ahead of delivered ones; within each group the
  // closer-to-arrival statuses come first.
  int get sortRank {
    switch (this) {
      case ShipmentStatus.outForDelivery:
        return 0;
      case ShipmentStatus.inTransit:
        return 1;
      case ShipmentStatus.delayed:
        return 2;
      case ShipmentStatus.pending:
        return 3;
      case ShipmentStatus.lost:
        return 4;
      case ShipmentStatus.delivered:
        return 5;
    }
  }
}

// TODO: verify these URL patterns before shipping — courier sites change
// tracking-page URLs without notice, and query-param formats are not
// officially documented by most PH couriers.
extension CourierX on Courier {
  String get label {
    switch (this) {
      case Courier.jnt:
        return 'J&T Express';
      case Courier.lbc:
        return 'LBC';
      case Courier.ninjaVan:
        return 'Ninja Van';
      case Courier.flashExpress:
        return 'Flash Express';
      case Courier.jrs:
        return 'JRS Express';
      case Courier.other:
        return 'Other';
    }
  }

  String? trackingUrl(String trackingNumber) {
    final encoded = Uri.encodeComponent(trackingNumber);
    switch (this) {
      case Courier.jnt:
        return 'https://www.jtexpress.ph/index/query/gzquery.html?bill_code=$encoded';
      case Courier.lbc:
        return 'https://www.lbcexpress.com/track/?tracking_no=$encoded';
      case Courier.ninjaVan:
        return 'https://www.ninjavan.co/en-ph/tracking?id=$encoded';
      case Courier.flashExpress:
        return 'https://www.flashexpress.ph/fle/track_new?se=$encoded';
      case Courier.jrs:
      case Courier.other:
        return null;
    }
  }
}

class Shipment {
  final String id;
  final String? sellerId;
  final Courier courier;
  final String trackingNumber;
  final ShipmentStatus status;
  final double? shippingCost;
  final DateTime shippedAt;
  final DateTime? estimatedArrival;
  final DateTime? deliveredAt;
  final int itemCount; // rollup
  final String? lastCheckpoint;

  const Shipment({
    required this.id,
    this.sellerId,
    required this.courier,
    required this.trackingNumber,
    this.status = ShipmentStatus.inTransit,
    this.shippingCost,
    required this.shippedAt,
    this.estimatedArrival,
    this.deliveredAt,
    this.itemCount = 0,
    this.lastCheckpoint,
  });

  bool get isStale =>
      status != ShipmentStatus.delivered &&
      estimatedArrival != null &&
      estimatedArrival!.isBefore(DateTime.now());

  factory Shipment.fromMap(Map<String, dynamic> map, String docId) {
    return Shipment(
      id: docId,
      sellerId: map['sellerId'],
      courier: Courier.values.firstWhere(
        (e) => e.name == map['courier'],
        orElse: () => Courier.other,
      ),
      trackingNumber: map['trackingNumber'] ?? '',
      status: ShipmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ShipmentStatus.inTransit,
      ),
      shippingCost: (map['shippingCost'] as num?)?.toDouble(),
      shippedAt: map['shippedAt'] is Timestamp
          ? (map['shippedAt'] as Timestamp).toDate()
          : DateTime.now(),
      estimatedArrival: map['estimatedArrival'] is Timestamp
          ? (map['estimatedArrival'] as Timestamp).toDate()
          : null,
      deliveredAt: map['deliveredAt'] is Timestamp
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      lastCheckpoint: map['lastCheckpoint'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'courier': courier.name,
      'trackingNumber': trackingNumber,
      'status': status.name,
      'shippingCost': shippingCost,
      'shippedAt': Timestamp.fromDate(shippedAt),
      'estimatedArrival': estimatedArrival == null ? null : Timestamp.fromDate(estimatedArrival!),
      'deliveredAt': deliveredAt == null ? null : Timestamp.fromDate(deliveredAt!),
      'itemCount': itemCount,
      'lastCheckpoint': lastCheckpoint,
    };
  }
}
