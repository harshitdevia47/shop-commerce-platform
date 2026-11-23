// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Gujarati (`gu`).
class AppLocalizationsGu extends AppLocalizations {
  AppLocalizationsGu([String locale = 'gu']) : super(locale);

  @override
  String get languageName => 'ગુજરાતી';

  @override
  String get language => 'ભાષા';

  @override
  String get retry => 'ફરી પ્રયાસ કરો';

  @override
  String get errorGeneric => 'કંઈક ખોટું થયું. કૃપા કરીને ફરી પ્રયાસ કરો.';

  @override
  String get errorNetwork =>
      'ઇન્ટરનેટ કનેક્શન નથી. તમારું નેટવર્ક તપાસો અને ફરી પ્રયાસ કરો.';

  @override
  String get errorShopInactive => 'આ દુકાન હાલમાં ઓર્ડર લેતી નથી.';

  @override
  String welcome(String shopName) {
    return '$shopName માં આપનું સ્વાગત છે';
  }

  @override
  String get deliveryTitle => 'ડિલિવરી';

  @override
  String deliveryEta(int minutes) {
    return 'આશરે $minutes મિનિટમાં ડિલિવરી';
  }

  @override
  String deliveryMinOrder(String amount) {
    return 'ઓછામાં ઓછો ઓર્ડર $amount';
  }

  @override
  String deliveryFee(String amount) {
    return 'ડિલિવરી ચાર્જ $amount';
  }

  @override
  String deliveryFreeAbove(String amount) {
    return '$amount થી વધુ પર મફત ડિલિવરી';
  }

  @override
  String get deliveryUnavailable => 'ડિલિવરી ઉપલબ્ધ નથી. દુકાનેથી લઈ જાઓ.';

  @override
  String get paymentTitle => 'ચુકવણીના વિકલ્પો';

  @override
  String get paymentCod => 'ડિલિવરી વખતે રોકડ';

  @override
  String get paymentUpi => 'UPI';

  @override
  String get featuresTitle => 'ઉપલબ્ધ સેવાઓ';

  @override
  String get featureDeliverySlots => 'ડિલિવરીનો સમય પસંદ કરો';

  @override
  String get featureStorePickup => 'દુકાનેથી લઈ જાઓ';

  @override
  String get featureReturns => 'પરત અને બદલી';

  @override
  String get featurePrescriptionUpload => 'પ્રિસ્ક્રિપ્શન અપલોડ કરો';

  @override
  String get featureOrderNotes => 'ઓર્ડરમાં નોંધ ઉમેરો';

  @override
  String get featureHandwrittenListUpload =>
      'તમારી ખરીદીની યાદીનો ફોટો અપલોડ કરો';
}
