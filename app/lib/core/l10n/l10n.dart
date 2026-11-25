import 'package:material_ui/material_ui.dart' show BuildContext, IconData, Icons;

import '../../features/auth/domain/auth_models.dart';
import '../../features/orders/domain/order_models.dart';
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

extension OrderStatusLabel on OrderStatus {
  String label(AppLocalizations l10n) => switch (this) {
    OrderStatus.placed => l10n.statusPlaced,
    OrderStatus.confirmed => l10n.statusConfirmed,
    OrderStatus.packed => l10n.statusPacked,
    OrderStatus.outForDelivery => l10n.statusOutForDelivery,
    OrderStatus.readyForPickup => l10n.statusReadyForPickup,
    OrderStatus.delivered => l10n.statusDelivered,
    OrderStatus.pickedUp => l10n.statusPickedUp,
    OrderStatus.cancelled => l10n.statusCancelled,
    OrderStatus.rejected => l10n.statusRejected,
  };

  /// Button text when the shop moves an order to this status.
  String actionLabel(AppLocalizations l10n) => switch (this) {
    OrderStatus.confirmed => l10n.actionConfirm,
    OrderStatus.packed => l10n.actionPack,
    OrderStatus.outForDelivery => l10n.actionOutForDelivery,
    OrderStatus.readyForPickup => l10n.actionReadyForPickup,
    OrderStatus.delivered => l10n.actionDelivered,
    OrderStatus.pickedUp => l10n.actionPickedUp,
    OrderStatus.rejected => l10n.rejectOrder,
    OrderStatus.cancelled => l10n.cancelOrder,
    OrderStatus.placed => l10n.statusPlaced,
  };
}

extension PaymentMethodLabel on PaymentMethod {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cod => l10n.paymentCod,
    PaymentMethod.upi => l10n.paymentUpi,
    PaymentMethod.razorpay => l10n.paymentOnlineShort,
  };

  IconData get icon => switch (this) {
    PaymentMethod.cod => Icons.payments_outlined,
    PaymentMethod.upi => Icons.qr_code_2,
    PaymentMethod.razorpay => Icons.credit_card,
  };
}

extension PaymentStatusLabel on PaymentStatus {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentStatus.pending => l10n.paymentPending,
    PaymentStatus.submitted => l10n.paymentSubmitted,
    PaymentStatus.paid => l10n.paymentPaid,
    PaymentStatus.voided => l10n.paymentVoid,
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
    'ORDERS_PAUSED' => l10n.shopPausedTitle,
    'SHOP_SUSPENDED' => l10n.shopSuspendedBody,
    'SETTINGS_INVALID' => l10n.settingsFixFields,
    'VALIDATION_FAILED' => l10n.errorPhoneInvalid,
    'OTP_INVALID' => l10n.errorOtpInvalid(error.detailInt('attemptsLeft') ?? 0),
    'OTP_EXPIRED' => l10n.errorOtpExpired,
    'OTP_TOO_MANY_ATTEMPTS' => l10n.errorOtpTooManyAttempts,
    'OTP_RESEND_TOO_SOON' => l10n.errorOtpTooSoon,
    'OTP_TOO_MANY_REQUESTS' || 'RATE_LIMITED' => l10n.errorOtpTooManyRequests,
    'USER_BLOCKED' => l10n.errorUserBlocked,
    'ACCOUNT_HAS_OPEN_ORDERS' => l10n.errorAccountOpenOrders,
    'ACCOUNT_DELETE_OWNER' || 'ACCOUNT_DELETE_TEAM' => l10n.errorAccountDeleteTeam,
    'SMS_SEND_FAILED' => l10n.errorSmsFailed,
    'REFRESH_TOKEN_INVALID' || 'REFRESH_TOKEN_EXPIRED' || 'REFRESH_TOKEN_REUSED' => l10n.sessionExpired,
    'PRODUCT_INVALID_VARIANTS' => l10n.errorInvalidVariants,
    'PRODUCT_INVALID_CUSTOM_FIELDS' => l10n.errorInvalidDetails,
    'CATEGORY_NOT_EMPTY' => l10n.errorCategoryNotEmpty,
    'CATEGORY_PARENT_INVALID' => l10n.errorCategoryParent,
    'MEDIA_TOO_LARGE' || 'PAYLOAD_TOO_LARGE' => l10n.errorPhotoTooLarge,
    'MEDIA_INVALID_IMAGE' || 'MEDIA_INVALID_UPLOAD' => l10n.errorPhotoInvalid,
    'PRODUCT_NOT_FOUND' ||
    'CATEGORY_NOT_FOUND' ||
    'VARIANT_NOT_FOUND' ||
    'MEDIA_NOT_FOUND' ||
    'ORDER_NOT_FOUND' ||
    'ADDRESS_NOT_FOUND' => l10n.errorNotFound,
    'CART_CHANGED' || 'PRICE_CHANGED' => l10n.errorCartChanged,
    'OUT_OF_STOCK' => l10n.errorOutOfStock,
    'BELOW_MINIMUM_ORDER' => l10n.errorBelowMinimum,
    'OUTSIDE_DELIVERY_AREA' => l10n.errorOutsideArea,
    'ADDRESS_REQUIRED' => l10n.errorAddressRequired,
    'DELIVERY_UNAVAILABLE' || 'PICKUP_UNAVAILABLE' || 'PAYMENT_METHOD_UNAVAILABLE' || 'FEATURE_DISABLED' =>
      l10n.errorOptionUnavailable,
    'ORDER_NOT_CANCELLABLE' => l10n.errorNotCancellable,
    'ORDER_STATUS_CHANGED' || 'ORDER_STATUS_INVALID' => l10n.errorOrderChanged,
    'PAYMENT_CLOSED' => l10n.errorPaymentClosed,
    'ADDRESS_LIMIT' => l10n.errorAddressLimit,
    'PAYMENT_SIGNATURE_INVALID' => l10n.errorPaymentVerify,
    'PAYMENT_PROVIDER_UNAVAILABLE' => l10n.errorOnlineUnavailable,
    'ORDER_NOT_PACKED' => l10n.errorOrderNotPacked,
    'DELIVERY_OTP_INVALID' => l10n.errorDeliveryOtp(error.detailInt('attemptsLeft') ?? 0),
    'OTP_ATTEMPTS_EXCEEDED' => l10n.errorDeliveryOtpLocked,
    'DELIVERY_NOT_ASSIGNABLE' || 'NOT_A_DELIVERY_ORDER' => l10n.errorDeliveryNotAssignable,
    'DELIVERY_ALREADY_STARTED' => l10n.errorDeliveryStarted,
    'DELIVERY_CLOSED' || 'DELIVERY_NOT_STARTED' || 'ORDER_CLOSED' || 'DELIVERY_CHANGED' => l10n.errorDeliveryClosed,
    'OWNER_ROLE_LOCKED' => l10n.errorOwnerLocked,
    'SLOT_REQUIRED' || 'SLOT_UNAVAILABLE' || 'SLOT_FULL' || 'SLOT_NOT_OFFERED' => l10n.errorSlot,
    'CART_EMPTY' => l10n.errorListEmpty,
    'PRICE_REQUIRED' => l10n.errorPriceRequired,
    'RETURN_WINDOW_CLOSED' => l10n.errorReturnWindow,
    'RETURN_ALREADY_REQUESTED' => l10n.errorReturnExists,
    'RETURN_ITEMS_REQUIRED' || 'RETURN_ITEMS_INVALID' => l10n.errorReturnItems,
    'RETURN_NOT_ALLOWED' => l10n.errorReturnNotAllowed,
    'EXCHANGE_NOT_OFFERED' => l10n.errorOptionUnavailable,
    'REASON_REQUIRED' => l10n.errorReasonRequired,
    'RETURN_STATUS_INVALID' || 'RETURN_CHANGED' => l10n.errorOrderChanged,
    'MEDIA_NOT_FOUND' || 'RETURN_NOT_FOUND' => l10n.errorNotFound,
    'RIDER_NOT_FOUND' || 'DELIVERY_NOT_FOUND' || 'TEAM_MEMBER_NOT_FOUND' => l10n.errorNotFound,
    _ => l10n.errorGeneric,
  };
}
