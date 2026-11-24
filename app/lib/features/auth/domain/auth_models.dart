import 'package:flutter/foundation.dart';

/// Mirrors backend `Role`.
enum UserRole {
  customer,
  owner,
  staff,
  rider;

  static UserRole fromWire(String value) => switch (value) {
    'OWNER' => UserRole.owner,
    'STAFF' => UserRole.staff,
    'RIDER' => UserRole.rider,
    _ => UserRole.customer,
  };

  String get wire => name.toUpperCase();

  bool get isAdmin => this == UserRole.owner || this == UserRole.staff;
}

@immutable
class AppUser {
  const AppUser({required this.id, required this.phone, required this.role, this.name, this.locale});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    phone: json['phone'] as String,
    name: json['name'] as String?,
    role: UserRole.fromWire(json['role'] as String),
    locale: json['locale'] as String?,
  );

  final String id;

  /// E.164, e.g. +919876543210
  final String phone;
  final String? name;
  final UserRole role;
  final String? locale;

  Map<String, dynamic> toJson() => {'id': id, 'phone': phone, 'name': name, 'role': role.wire, 'locale': locale};

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.phone == phone &&
      other.name == name &&
      other.role == role &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(id, phone, name, role, locale);
}

/// Tokens + user from `/auth/otp/verify` and `/auth/refresh`. Persisted in secure storage.
@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    accessTokenExpiresAt: DateTime.parse(json['accessTokenExpiresAt'] as String),
    refreshToken: json['refreshToken'] as String,
    refreshTokenExpiresAt: DateTime.parse(json['refreshTokenExpiresAt'] as String),
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final AppUser user;

  bool isRefreshExpired(DateTime now) => !refreshTokenExpiresAt.isAfter(now);

  AuthSession withUser(AppUser user) => AuthSession(
    accessToken: accessToken,
    accessTokenExpiresAt: accessTokenExpiresAt,
    refreshToken: refreshToken,
    refreshTokenExpiresAt: refreshTokenExpiresAt,
    user: user,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };
}

@immutable
class OtpRequestResult {
  const OtpRequestResult({required this.expiresInSeconds, required this.resendAfterSeconds, this.debugCode, this.viaWhatsApp = false});

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) => OtpRequestResult(
    expiresInSeconds: json['expiresInSeconds'] as int,
    resendAfterSeconds: json['resendAfterSeconds'] as int,
    debugCode: json['debugCode'] as String?,
    viaWhatsApp: json['channel'] == 'whatsapp',
  );

  final int expiresInSeconds;
  final int resendAfterSeconds;

  /// Only from a dev backend with OTP_DEV_ECHO on.
  final String? debugCode;

  /// The code went to WhatsApp (not SMS): the code screen says where to look.
  final bool viaWhatsApp;
}
