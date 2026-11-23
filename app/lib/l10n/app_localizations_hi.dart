// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get languageName => 'हिन्दी';

  @override
  String get language => 'भाषा';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get errorGeneric => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get errorNetwork =>
      'इंटरनेट कनेक्शन नहीं है। अपना नेटवर्क जांचें और फिर से कोशिश करें।';

  @override
  String get errorShopInactive => 'यह दुकान अभी ऑर्डर नहीं ले रही है।';

  @override
  String welcome(String shopName) {
    return '$shopName में आपका स्वागत है';
  }

  @override
  String get deliveryTitle => 'डिलीवरी';

  @override
  String deliveryEta(int minutes) {
    return 'लगभग $minutes मिनट में डिलीवरी';
  }

  @override
  String deliveryMinOrder(String amount) {
    return 'न्यूनतम ऑर्डर $amount';
  }

  @override
  String deliveryFee(String amount) {
    return 'डिलीवरी शुल्क $amount';
  }

  @override
  String deliveryFreeAbove(String amount) {
    return '$amount से ऊपर मुफ़्त डिलीवरी';
  }

  @override
  String get deliveryUnavailable => 'डिलीवरी उपलब्ध नहीं है। दुकान से ले जाएं।';

  @override
  String get paymentTitle => 'भुगतान के विकल्प';

  @override
  String get paymentCod => 'डिलीवरी पर नकद';

  @override
  String get paymentUpi => 'UPI';

  @override
  String get featuresTitle => 'उपलब्ध सेवाएं';

  @override
  String get featureDeliverySlots => 'डिलीवरी का समय चुनें';

  @override
  String get featureStorePickup => 'दुकान से पिकअप';

  @override
  String get featureReturns => 'वापसी और बदलाव';

  @override
  String get featurePrescriptionUpload => 'पर्चा अपलोड करें';

  @override
  String get featureOrderNotes => 'ऑर्डर में नोट जोड़ें';

  @override
  String get featureHandwrittenListUpload =>
      'अपनी खरीदारी की सूची की फ़ोटो अपलोड करें';
}
