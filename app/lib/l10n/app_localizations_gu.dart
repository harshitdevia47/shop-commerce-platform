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

  @override
  String get login => 'લૉગિન';

  @override
  String get logout => 'લૉગઆઉટ';

  @override
  String get account => 'એકાઉન્ટ';

  @override
  String get loginTitle => 'આગળ વધવા માટે લૉગિન કરો';

  @override
  String get loginSubtitle => 'અમે તમારા મોબાઇલ નંબર પર 6 અંકનો કોડ મોકલીશું.';

  @override
  String get phoneLabel => 'મોબાઇલ નંબર';

  @override
  String get sendOtp => 'કોડ મોકલો';

  @override
  String get otpTitle => 'વેરિફિકેશન કોડ દાખલ કરો';

  @override
  String otpSubtitle(String phone) {
    return '$phone પર મોકલ્યો';
  }

  @override
  String get verify => 'ચકાસો';

  @override
  String resendIn(int seconds) {
    return '$seconds સેકન્ડમાં ફરી મોકલો';
  }

  @override
  String get resend => 'કોડ ફરી મોકલો';

  @override
  String get changeNumber => 'નંબર બદલો';

  @override
  String devOtpHint(String code) {
    return 'ડેવ કોડ: $code';
  }

  @override
  String get nameLabel => 'તમારું નામ';

  @override
  String get save => 'સાચવો';

  @override
  String get saved => 'સાચવ્યું';

  @override
  String get roleOwner => 'માલિક';

  @override
  String get roleStaff => 'સ્ટાફ';

  @override
  String get roleRider => 'ડિલિવરી પાર્ટનર';

  @override
  String get roleCustomer => 'ગ્રાહક';

  @override
  String get adminTitle => 'દુકાન ડેશબોર્ડ';

  @override
  String adminWelcome(String name) {
    return 'નમસ્તે, $name';
  }

  @override
  String get adminComingSoon => 'ઓર્ડર, પ્રોડક્ટ અને વેચાણ અહીં દેખાશે.';

  @override
  String get riderTitle => 'ડિલિવરી';

  @override
  String get riderComingSoon => 'તમને સોંપેલી ડિલિવરી અહીં દેખાશે.';

  @override
  String get errorPhoneInvalid => 'માન્ય 10 અંકનો મોબાઇલ નંબર દાખલ કરો.';

  @override
  String errorOtpInvalid(int attempts) {
    return 'ખોટો કોડ. $attempts પ્રયાસ બાકી.';
  }

  @override
  String get errorOtpExpired => 'કોડની મુદત પૂરી થઈ. નવો કોડ મંગાવો.';

  @override
  String get errorOtpTooManyAttempts => 'ઘણા ખોટા પ્રયાસ. નવો કોડ મંગાવો.';

  @override
  String get errorOtpTooSoon => 'બીજો કોડ મંગાવતા પહેલાં થોડી રાહ જુઓ.';

  @override
  String get errorOtpTooManyRequests =>
      'ઘણા કોડ મંગાવ્યા. થોડી વાર પછી પ્રયાસ કરો.';

  @override
  String get errorUserBlocked =>
      'આ એકાઉન્ટ બ્લૉક છે. કૃપા કરીને દુકાનનો સંપર્ક કરો.';

  @override
  String get errorSmsFailed => 'કોડ મોકલી શકાયો નહીં. ફરી પ્રયાસ કરો.';

  @override
  String get sessionExpired => 'તમારું સત્ર પૂરું થયું. ફરી લૉગિન કરો.';
}
