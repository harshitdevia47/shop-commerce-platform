import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../orders/domain/order_models.dart';

enum DeliveryStatus {
  assigned('ASSIGNED'),
  pickedUp('PICKED_UP'),
  delivered('DELIVERED'),
  cancelled('CANCELLED');

  const DeliveryStatus(this.wire);
  final String wire;

  static DeliveryStatus parse(String value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => DeliveryStatus.cancelled);

  bool get isActive => this == assigned || this == pickedUp;
}

@immutable
class RiderLocation {
  const RiderLocation({required this.lat, required this.lng, required this.at, this.accuracy});

  factory RiderLocation.fromJson(Map<String, dynamic> json) => RiderLocation(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
    at: DateTime.parse(json['at'] as String),
  );

  final double lat;
  final double lng;
  final double? accuracy;
  final DateTime at;
}

@immutable
class Person {
  const Person({required this.phone, this.id, this.name});

  factory Person.fromJson(Map<String, dynamic> json) =>
      Person(id: json['id'] as String?, name: json['name'] as String?, phone: json['phone'] as String);

  final String? id;
  final String? name;
  final String phone;

  String get display => name ?? phone;
}

/// Shop rider with their open work (assign sheet).
@immutable
class Rider {
  const Rider({required this.id, required this.phone, required this.activeDeliveries, this.name});

  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
    id: json['id'] as String,
    name: json['name'] as String?,
    phone: json['phone'] as String,
    activeDeliveries: json['activeDeliveries'] as int? ?? 0,
  );

  final String id;
  final String? name;
  final String phone;
  final int activeDeliveries;

  String get display => name ?? phone;
}

/// Shop view of an order's delivery (never the door code).
@immutable
class AdminDelivery {
  const AdminDelivery({required this.id, required this.orderId, required this.status, required this.rider, this.location});

  factory AdminDelivery.fromJson(Map<String, dynamic> json) => AdminDelivery(
    id: json['id'] as String,
    orderId: json['orderId'] as String,
    status: DeliveryStatus.parse(json['status'] as String),
    rider: Person.fromJson(json['rider'] as Map<String, dynamic>),
    location: json['location'] == null ? null : RiderLocation.fromJson(json['location'] as Map<String, dynamic>),
  );

  final String id;
  final String orderId;
  final DeliveryStatus status;
  final Person rider;
  final RiderLocation? location;
}

/// Customer view: who is coming, the code to share at the door, where the rider is.
@immutable
class CustomerDelivery {
  const CustomerDelivery({required this.orderId, required this.status, required this.rider, this.otp, this.location});

  factory CustomerDelivery.fromJson(Map<String, dynamic> json) => CustomerDelivery(
    orderId: json['orderId'] as String,
    status: DeliveryStatus.parse(json['status'] as String),
    rider: Person.fromJson(json['rider'] as Map<String, dynamic>),
    otp: json['otp'] as String?,
    location: json['location'] == null ? null : RiderLocation.fromJson(json['location'] as Map<String, dynamic>),
  );

  final String orderId;
  final DeliveryStatus status;
  final Person rider;
  final String? otp;
  final RiderLocation? location;
}

/// Rider's job card.
@immutable
class RiderDelivery {
  const RiderDelivery({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.customer,
    required this.address,
    required this.itemCount,
    required this.totalPaise,
    required this.codPaise,
    required this.otpAttemptsLeft,
    this.note,
  });

  factory RiderDelivery.fromJson(Map<String, dynamic> json) {
    final address = Map<String, dynamic>.of(json['address'] as Map<String, dynamic>);
    address['id'] ??= json['orderId'];
    return RiderDelivery(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as int,
      status: DeliveryStatus.parse(json['status'] as String),
      customer: Person.fromJson(json['customer'] as Map<String, dynamic>),
      address: Address.fromJson(address),
      note: json['note'] as String?,
      itemCount: json['itemCount'] as int,
      totalPaise: json['totalPaise'] as int,
      codPaise: json['codPaise'] as int,
      otpAttemptsLeft: json['otpAttemptsLeft'] as int? ?? 0,
    );
  }

  final String id;
  final String orderId;
  final int orderNumber;
  final DeliveryStatus status;
  final Person customer;
  final Address address;
  final String? note;
  final int itemCount;
  final int totalPaise;
  final int codPaise;
  final int otpAttemptsLeft;
}

/// Shop staff and riders (team screen).
@immutable
class TeamMember {
  const TeamMember({required this.id, required this.phone, required this.role, this.name});

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
    id: json['id'] as String,
    phone: json['phone'] as String,
    name: json['name'] as String?,
    role: json['role'] as String,
  );

  final String id;
  final String phone;
  final String? name;

  /// OWNER | STAFF | RIDER
  final String role;
}

/// Straight-line distance in km (no paid routing APIs).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Rough minutes for a two-wheeler in town: straight line × 1.3 for roads, 18 km/h, at least 1.
int etaMinutes(double km) => math.max(1, (km * 1.3 / 18 * 60).round());

/// Free maps link (no API key): directions to a pin, or a search for the address text.
Uri mapsUri({double? lat, double? lng, String? query}) => lat != null && lng != null
    ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
    : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query ?? '')}');
