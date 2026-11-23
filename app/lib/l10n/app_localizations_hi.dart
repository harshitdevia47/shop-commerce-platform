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
  String get adminComingSoon => 'ऑर्डर और बिक्री यहां दिखेंगे।';

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

  @override
  String get searchHint => 'प्रोडक्ट खोजें';

  @override
  String get categoriesTitle => 'श्रेणी के अनुसार खरीदें';

  @override
  String get allProducts => 'सभी प्रोडक्ट';

  @override
  String get allInCategory => 'सभी';

  @override
  String get outOfStock => 'स्टॉक में नहीं';

  @override
  String get noProducts => 'यहाँ अभी कोई प्रोडक्ट नहीं है';

  @override
  String get searchPrompt => 'खोजने के लिए कम से कम 2 अक्षर लिखें';

  @override
  String get loadMoreFailed => 'और लोड नहीं हुआ. दोबारा कोशिश के लिए टैप करें.';

  @override
  String get chooseVariant => 'विकल्प चुनें';

  @override
  String get productDetails => 'प्रोडक्ट विवरण';

  @override
  String get orderingSoon => 'ऑर्डर जल्द शुरू होंगे';

  @override
  String get shopInfo => 'दुकान की जानकारी';

  @override
  String get adminProducts => 'प्रोडक्ट';

  @override
  String get adminProductsSubtitle => 'प्रोडक्ट, कीमत, फ़ोटो और स्टॉक जोड़ें';

  @override
  String get adminCategories => 'श्रेणियाँ';

  @override
  String get adminCategoriesSubtitle => 'ग्राहक कैसे देखें, यह व्यवस्थित करें';

  @override
  String get addProduct => 'प्रोडक्ट जोड़ें';

  @override
  String get editProduct => 'प्रोडक्ट बदलें';

  @override
  String get addCategory => 'श्रेणी जोड़ें';

  @override
  String get editCategory => 'श्रेणी बदलें';

  @override
  String get statusAll => 'सभी';

  @override
  String get statusVisible => 'दिख रहे';

  @override
  String get statusHidden => 'छिपे हुए';

  @override
  String get nameEnglish => 'नाम (अंग्रेज़ी)';

  @override
  String get nameGujarati => 'गुजराती में नाम';

  @override
  String get nameHindi => 'हिंदी में नाम';

  @override
  String get descriptionLabel => 'विवरण';

  @override
  String get categoryLabel => 'श्रेणी';

  @override
  String get noCategory => 'कोई श्रेणी नहीं';

  @override
  String get parentCategory => 'किस श्रेणी के अंदर';

  @override
  String get topLevel => 'मुख्य श्रेणी';

  @override
  String get photos => 'फ़ोटो';

  @override
  String get addPhoto => 'फ़ोटो जोड़ें';

  @override
  String get takePhoto => 'कैमरा';

  @override
  String get pickFromGallery => 'गैलरी';

  @override
  String get uploadingPhoto => 'फ़ोटो अपलोड हो रही है…';

  @override
  String get pricesTitle => 'कीमत';

  @override
  String get unitsTitle => 'साइज़ और कीमत';

  @override
  String get optionsTitle => 'विकल्प और कीमत';

  @override
  String get unitLabel => 'यूनिट, जैसे 500 ग्राम';

  @override
  String get priceLabel => 'कीमत ₹';

  @override
  String get mrpLabel => 'MRP ₹';

  @override
  String get stockLabel => 'स्टॉक (वैकल्पिक)';

  @override
  String get inStockLabel => 'स्टॉक में है';

  @override
  String get addVariant => 'एक और जोड़ें';

  @override
  String get remove => 'हटाएँ';

  @override
  String get visibleToCustomers => 'ग्राहकों को दिखे';

  @override
  String get tagsLabel => 'खोज शब्द, कॉमा से अलग';

  @override
  String get moreDetails => 'और विवरण';

  @override
  String get delete => 'हटाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get deleteProductConfirm =>
      'यह प्रोडक्ट हटाएँ? ग्राहक इसे नहीं देख पाएँगे.';

  @override
  String get deleteCategoryConfirm => 'यह श्रेणी हटाएँ?';

  @override
  String get requiredField => 'ज़रूरी';

  @override
  String get invalidPrice => 'सही रकम लिखें';

  @override
  String get mrpBelowPrice => 'MRP कीमत से कम नहीं हो सकती';

  @override
  String get emptyCategories => 'अभी कोई श्रेणी नहीं';

  @override
  String get axisSize => 'साइज़';

  @override
  String get axisColor => 'रंग';

  @override
  String get axisMaterial => 'मटीरियल';

  @override
  String get axisFlavour => 'स्वाद';

  @override
  String get axisStorage => 'स्टोरेज';

  @override
  String get errorInvalidVariants => 'साइज़ और कीमत जाँचें.';

  @override
  String get errorInvalidDetails => 'प्रोडक्ट विवरण जाँचें.';

  @override
  String get errorCategoryNotEmpty =>
      'पहले इसके प्रोडक्ट और उप-श्रेणियाँ हटाएँ या खिसकाएँ.';

  @override
  String get errorCategoryParent =>
      'श्रेणी केवल मुख्य श्रेणी के अंदर हो सकती है.';

  @override
  String get errorPhotoTooLarge => 'यह फ़ोटो बहुत बड़ी है.';

  @override
  String get errorPhotoInvalid => 'यह फ़ाइल सही फ़ोटो नहीं है.';

  @override
  String get errorNotFound => 'यह आइटम अब उपलब्ध नहीं है.';

  @override
  String get errorInvalidInput => 'आपने जो लिखा है उसे जाँचें.';

  @override
  String percentOff(int percent) {
    return '$percent% छूट';
  }

  @override
  String variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count विकल्प',
      one: '1 विकल्प',
    );
    return '$_temp0';
  }
}
