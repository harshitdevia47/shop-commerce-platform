import 'package:flutter/widgets.dart';

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

/// Maps backend error codes to user-facing text. Add codes here as features land.
String errorMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return l10n.errorNetwork;
    if (error.code == 'SHOP_INACTIVE') return l10n.errorShopInactive;
  }
  return l10n.errorGeneric;
}
