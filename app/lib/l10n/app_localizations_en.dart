// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get language => 'Language';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errorShopInactive => 'This shop is not taking orders right now.';

  @override
  String welcome(String shopName) {
    return 'Welcome to $shopName';
  }

  @override
  String get deliveryTitle => 'Delivery';

  @override
  String deliveryEta(int minutes) {
    return 'Delivery in about $minutes min';
  }

  @override
  String deliveryMinOrder(String amount) {
    return 'Minimum order $amount';
  }

  @override
  String deliveryFee(String amount) {
    return 'Delivery fee $amount';
  }

  @override
  String deliveryFreeAbove(String amount) {
    return 'Free delivery above $amount';
  }

  @override
  String get deliveryUnavailable =>
      'Delivery is not available. Pick up from the store.';

  @override
  String get paymentTitle => 'Payment options';

  @override
  String get paymentCod => 'Cash on delivery';

  @override
  String get paymentUpi => 'UPI';

  @override
  String get featuresTitle => 'Available services';

  @override
  String get featureDeliverySlots => 'Choose a delivery time slot';

  @override
  String get featureStorePickup => 'Store pickup';

  @override
  String get featureReturns => 'Returns and exchange';

  @override
  String get featurePrescriptionUpload => 'Upload prescription';

  @override
  String get featureOrderNotes => 'Add notes to your order';

  @override
  String get featureHandwrittenListUpload =>
      'Upload a photo of your shopping list';
}
