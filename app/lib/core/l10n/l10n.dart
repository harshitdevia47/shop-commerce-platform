import 'package:flutter/widgets.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../l10n/app_localizations.dart';
import '../config/shop_settings.dart';
import '../network/api_exception.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension FeatureLabel on Feature {
  String label(AppLocalizations l10n) => switch (this) {
    Feature.deliverySlots => l10n.featureDeliverySlots,
    Feature.storePickup => l10n.featureStorePickup,
    Feature.returns => l10n.featureReturns,
    Feature.prescriptionUpload => l10n.featurePrescriptionUpload,
    Feature.orderNotes => l10n.featureOrderNotes,
    Feature.handwrittenListUpload => l10n.featureHandwrittenListUpload,
  };
}

extension RoleLabel on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
    UserRole.owner => l10n.roleOwner,
    UserRole.staff => l10n.roleStaff,
    UserRole.rider => l10n.roleRider,
    UserRole.customer => l10n.roleCustomer,
  };
}

/// Label of a variant option axis (backend `VARIANT_AXES`).
String axisLabel(AppLocalizations l10n, String axis) => switch (axis) {
  'size' => l10n.axisSize,
  'color' => l10n.axisColor,
  'material' => l10n.axisMaterial,
  'flavour' => l10n.axisFlavour,
  'storage' => l10n.axisStorage,
  _ => axis,
};

/// Maps backend error codes to user-facing text. Add codes here as features land.
String errorMessage(AppLocalizations l10n, Object error) {
  if (error is! ApiException) return l10n.errorGeneric;
  if (error.isNetwork) return l10n.errorNetwork;
  return switch (error.code) {
    'SHOP_INACTIVE' => l10n.errorShopInactive,
    'VALIDATION_FAILED' => l10n.errorPhoneInvalid,
    'OTP_INVALID' => l10n.errorOtpInvalid(error.detailInt('attemptsLeft') ?? 0),
    'OTP_EXPIRED' => l10n.errorOtpExpired,
    'OTP_TOO_MANY_ATTEMPTS' => l10n.errorOtpTooManyAttempts,
    'OTP_RESEND_TOO_SOON' => l10n.errorOtpTooSoon,
    'OTP_TOO_MANY_REQUESTS' || 'RATE_LIMITED' => l10n.errorOtpTooManyRequests,
    'USER_BLOCKED' => l10n.errorUserBlocked,
    'SMS_SEND_FAILED' => l10n.errorSmsFailed,
    'REFRESH_TOKEN_INVALID' || 'REFRESH_TOKEN_EXPIRED' || 'REFRESH_TOKEN_REUSED' => l10n.sessionExpired,
    'PRODUCT_INVALID_VARIANTS' => l10n.errorInvalidVariants,
    'PRODUCT_INVALID_CUSTOM_FIELDS' => l10n.errorInvalidDetails,
    'CATEGORY_NOT_EMPTY' => l10n.errorCategoryNotEmpty,
    'CATEGORY_PARENT_INVALID' => l10n.errorCategoryParent,
    'MEDIA_TOO_LARGE' || 'PAYLOAD_TOO_LARGE' => l10n.errorPhotoTooLarge,
    'MEDIA_INVALID_IMAGE' || 'MEDIA_INVALID_UPLOAD' => l10n.errorPhotoInvalid,
    'PRODUCT_NOT_FOUND' || 'CATEGORY_NOT_FOUND' || 'VARIANT_NOT_FOUND' || 'MEDIA_NOT_FOUND' => l10n.errorNotFound,
    _ => l10n.errorGeneric,
  };
}
