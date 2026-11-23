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

  @override
  String get login => 'लॉग इन';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get account => 'खाता';

  @override
  String get loginTitle => 'आगे बढ़ने के लिए लॉग इन करें';

  @override
  String get loginSubtitle => 'हम आपके मोबाइल नंबर पर 6 अंकों का कोड भेजेंगे।';

  @override
  String get phoneLabel => 'मोबाइल नंबर';

  @override
  String get sendOtp => 'कोड भेजें';

  @override
  String get otpTitle => 'वेरिफ़िकेशन कोड डालें';

  @override
  String otpSubtitle(String phone) {
    return '$phone पर भेजा गया';
  }

  @override
  String get verify => 'सत्यापित करें';

  @override
  String resendIn(int seconds) {
    return '$seconds सेकंड में फिर से भेजें';
  }

  @override
  String get resend => 'कोड फिर से भेजें';

  @override
  String get changeNumber => 'नंबर बदलें';

  @override
  String devOtpHint(String code) {
    return 'डेव कोड: $code';
  }

  @override
  String get nameLabel => 'आपका नाम';

  @override
  String get save => 'सेव करें';

  @override
  String get saved => 'सेव हो गया';

  @override
  String get roleOwner => 'मालिक';

  @override
  String get roleStaff => 'स्टाफ़';

  @override
  String get roleRider => 'डिलीवरी पार्टनर';

  @override
  String get roleCustomer => 'ग्राहक';

  @override
  String get adminTitle => 'दुकान डैशबोर्ड';

  @override
  String adminWelcome(String name) {
    return 'नमस्ते, $name';
  }

  @override
  String get adminComingSoon => 'ऑर्डर, प्रोडक्ट और बिक्री यहां दिखेंगे।';

  @override
  String get riderTitle => 'डिलीवरी';

  @override
  String get riderComingSoon => 'आपको सौंपी गई डिलीवरी यहां दिखेंगी।';

  @override
  String get errorPhoneInvalid => 'मान्य 10 अंकों का मोबाइल नंबर डालें।';

  @override
  String errorOtpInvalid(int attempts) {
    return 'गलत कोड। $attempts प्रयास बाकी।';
  }

  @override
  String get errorOtpExpired => 'कोड की समय सीमा खत्म। नया कोड मंगाएं।';

  @override
  String get errorOtpTooManyAttempts => 'बहुत सारे गलत प्रयास। नया कोड मंगाएं।';

  @override
  String get errorOtpTooSoon => 'दूसरा कोड मंगाने से पहले थोड़ा रुकें।';

  @override
  String get errorOtpTooManyRequests =>
      'बहुत सारे कोड मंगाए गए। थोड़ी देर बाद कोशिश करें।';

  @override
  String get errorUserBlocked =>
      'यह खाता ब्लॉक है। कृपया दुकान से संपर्क करें।';

  @override
  String get errorSmsFailed => 'कोड नहीं भेजा जा सका। फिर से कोशिश करें।';

  @override
  String get sessionExpired => 'आपका सत्र खत्म हो गया। फिर से लॉग इन करें।';
}
