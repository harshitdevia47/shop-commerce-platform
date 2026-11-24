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
  String get roleStaff => 'स्टाफ';

  @override
  String get roleRider => 'राइडर';

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

  @override
  String get addToCart => 'जोड़ें';

  @override
  String get cartTitle => 'कार्ट';

  @override
  String get viewCart => 'कार्ट देखें';

  @override
  String get cartEmpty => 'आपका कार्ट खाली है';

  @override
  String get startShopping => 'प्रोडक्ट देखें';

  @override
  String get billDetails => 'बिल विवरण';

  @override
  String get itemTotal => 'आइटम कुल';

  @override
  String get deliveryFeeLabel => 'डिलीवरी शुल्क';

  @override
  String get free => 'मुफ़्त';

  @override
  String get toPay => 'भुगतान करें';

  @override
  String get lineUnavailable => 'अब उपलब्ध नहीं';

  @override
  String get proceed => 'आगे बढ़ें';

  @override
  String get loginToOrder => 'ऑर्डर करने के लिए लॉगिन करें';

  @override
  String get deliveryOption => 'डिलीवरी';

  @override
  String get pickupOption => 'दुकान से लें';

  @override
  String get checkoutTitle => 'चेकआउट';

  @override
  String get deliverTo => 'कहाँ पहुँचाएँ';

  @override
  String get pickupFrom => 'यहाँ से लें';

  @override
  String get addAddress => 'पता जोड़ें';

  @override
  String get noAddresses => 'आगे बढ़ने के लिए डिलीवरी पता जोड़ें';

  @override
  String get addressLine1 => 'मकान / फ्लैट, गली';

  @override
  String get addressLine2 => 'इलाका (वैकल्पिक)';

  @override
  String get landmarkLabel => 'लैंडमार्क (वैकल्पिक)';

  @override
  String get cityLabel => 'शहर';

  @override
  String get pincodeLabel => 'पिनकोड';

  @override
  String get invalidPincode => '6 अंकों का पिनकोड लिखें';

  @override
  String get addressHome => 'घर';

  @override
  String get addressWork => 'ऑफ़िस';

  @override
  String get addressOther => 'अन्य';

  @override
  String get paymentMethodTitle => 'भुगतान';

  @override
  String get noteLabel => 'दुकान के लिए नोट (वैकल्पिक)';

  @override
  String get ordersTitle => 'मेरे ऑर्डर';

  @override
  String get noOrders => 'अभी कोई ऑर्डर नहीं';

  @override
  String get orderPlacedTitle => 'ऑर्डर हो गया!';

  @override
  String get statusPlaced => 'ऑर्डर हुआ';

  @override
  String get statusConfirmed => 'स्वीकार हुआ';

  @override
  String get statusPacked => 'पैक हुआ';

  @override
  String get statusOutForDelivery => 'डिलीवरी के लिए निकला';

  @override
  String get statusReadyForPickup => 'लेने के लिए तैयार';

  @override
  String get statusDelivered => 'पहुँच गया';

  @override
  String get statusPickedUp => 'ले लिया';

  @override
  String get statusCancelled => 'रद्द हुआ';

  @override
  String get statusRejected => 'दुकान ने मना किया';

  @override
  String get cancelOrder => 'ऑर्डर रद्द करें';

  @override
  String get cancelOrderConfirm => 'यह ऑर्डर रद्द करें?';

  @override
  String get keepOrder => 'ऑर्डर रखें';

  @override
  String get utrPrompt =>
      'भुगतान किया? दुकान पुष्टि कर सके, इसके लिए UPI ऐप से 12 अंकों का UTR लिखें.';

  @override
  String get utrLabel => 'UTR नंबर';

  @override
  String get submit => 'भेजें';

  @override
  String get utrInvalid => 'UTR 12 अंकों का होता है';

  @override
  String get paymentPending => 'भुगतान बाकी';

  @override
  String get paymentSubmitted => 'भुगतान की जाँच हो रही है';

  @override
  String get paymentPaid => 'भुगतान हो गया';

  @override
  String get paymentVoid => 'चार्ज नहीं हुआ';

  @override
  String get callShop => 'दुकान को कॉल करें';

  @override
  String get noUpiApp => 'इस फ़ोन में कोई UPI ऐप नहीं मिला';

  @override
  String get adminOrders => 'ऑर्डर';

  @override
  String get adminOrdersSubtitle => 'नए, चालू और पूरे हुए ऑर्डर';

  @override
  String get tabNew => 'नए';

  @override
  String get tabActive => 'चालू';

  @override
  String get tabDone => 'पूरे';

  @override
  String get noOrdersHere => 'यहाँ कोई ऑर्डर नहीं';

  @override
  String get callCustomer => 'ग्राहक को कॉल करें';

  @override
  String get markPaid => 'भुगतान हुआ मानें';

  @override
  String get rejectOrder => 'मना करें';

  @override
  String get rejectReason => 'कारण (ग्राहक को दिखेगा)';

  @override
  String get actionConfirm => 'ऑर्डर स्वीकार करें';

  @override
  String get actionPack => 'पैक हुआ';

  @override
  String get actionOutForDelivery => 'डिलीवरी के लिए भेजें';

  @override
  String get actionReadyForPickup => 'लेने के लिए तैयार';

  @override
  String get actionDelivered => 'पहुँचा दिया';

  @override
  String get actionPickedUp => 'ग्राहक ले गए';

  @override
  String get customerNote => 'ग्राहक का नोट';

  @override
  String get errorCartChanged => 'कुछ आइटम बदल गए हैं. कार्ट फिर से देखें.';

  @override
  String get errorOutOfStock => 'कुछ आइटम अभी खत्म हो गए.';

  @override
  String get errorBelowMinimum => 'आपका ऑर्डर न्यूनतम राशि से कम है.';

  @override
  String get errorOutsideArea => 'दुकान इस पते पर डिलीवरी नहीं करती.';

  @override
  String get errorAddressRequired => 'डिलीवरी पता चुनें.';

  @override
  String get errorOptionUnavailable => 'यह विकल्प इस दुकान में उपलब्ध नहीं है.';

  @override
  String get errorNotCancellable =>
      'यह ऑर्डर अब रद्द नहीं हो सकता. दुकान को कॉल करें.';

  @override
  String get errorOrderChanged =>
      'किसी और ने यह ऑर्डर बदला है. फिर से लोड किया.';

  @override
  String get errorPaymentClosed => 'यह भुगतान अब बदला नहीं जा सकता.';

  @override
  String get errorAddressLimit => 'बहुत सारे पते हैं. पहले एक हटाएँ.';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '1 आइटम',
    );
    return '$_temp0';
  }

  @override
  String youSave(String amount) {
    return 'आप $amount बचा रहे हैं';
  }

  @override
  String freeDeliveryGap(String amount) {
    return 'मुफ़्त डिलीवरी के लिए $amount और जोड़ें';
  }

  @override
  String minOrderGap(String amount, String minimum) {
    return 'ऑर्डर के लिए $amount और जोड़ें (न्यूनतम $minimum)';
  }

  @override
  String lineOnlyLeft(int count) {
    return 'केवल $count बचे';
  }

  @override
  String setQtyTo(int count) {
    return '$count करें';
  }

  @override
  String placeOrder(String amount) {
    return 'ऑर्डर करें · $amount';
  }

  @override
  String orderNumber(int number) {
    return 'ऑर्डर #$number';
  }

  @override
  String payWithUpi(String amount) {
    return 'UPI से $amount चुकाएँ';
  }

  @override
  String payOnDelivery(String amount) {
    return 'डिलीवरी पर $amount नकद दें';
  }

  @override
  String utrShown(String utr) {
    return 'UTR $utr';
  }

  @override
  String rejectedBecause(String reason) {
    return 'कारण: $reason';
  }

  @override
  String get notificationChannelOrders => 'ऑर्डर अपडेट';

  @override
  String get deliveryPartner => 'आपके डिलीवरी पार्टनर';

  @override
  String get deliveryOtpLabel => 'डिलीवरी कोड';

  @override
  String get deliveryOtpHint => 'ऑर्डर आने पर यह कोड राइडर को बताएँ।';

  @override
  String deliveryRiderDistance(String km, int minutes) {
    return '$km किमी दूर · लगभग $minutes मिनट';
  }

  @override
  String get deliveryRiderOnTheWay => 'आपकी ओर आ रहे हैं';

  @override
  String get deliveryTrackOnMap => 'मैप पर देखें';

  @override
  String get callRider => 'राइडर को कॉल करें';

  @override
  String get deliverySection => 'डिलीवरी';

  @override
  String get assignRider => 'राइडर सौंपें';

  @override
  String get changeRider => 'राइडर बदलें';

  @override
  String get chooseRider => 'राइडर चुनें';

  @override
  String get noRiders => 'अभी कोई राइडर नहीं है। टीम में जोड़ें।';

  @override
  String riderActiveCount(int count) {
    return '$count चालू';
  }

  @override
  String get noRiderYet => 'अभी राइडर नहीं सौंपा गया';

  @override
  String get deliveryAssigned => 'राइडर सौंपा गया';

  @override
  String get deliveryPickedUp => 'रास्ते में';

  @override
  String get deliveryDelivered => 'पहुँचा दिया';

  @override
  String get deliveryCancelled => 'रद्द';

  @override
  String get adminTeam => 'टीम';

  @override
  String get adminTeamSubtitle => 'राइडर और स्टाफ';

  @override
  String get teamAdd => 'व्यक्ति जोड़ें';

  @override
  String get teamEmpty => 'अभी कोई राइडर या स्टाफ नहीं है।';

  @override
  String get teamAdded => 'जोड़ दिया। वे इसी नंबर से लॉगिन करेंगे।';

  @override
  String get teamRemove => 'हटाएँ';

  @override
  String teamRemoveConfirm(String name) {
    return '$name को टीम से हटाएँ? वे सामान्य ग्राहक बन जाएँगे।';
  }

  @override
  String get nameOptional => 'नाम (वैकल्पिक)';

  @override
  String get riderActive => 'चालू';

  @override
  String get riderDone => 'पूरी';

  @override
  String get riderNoActive => 'अभी कोई डिलीवरी नहीं है।';

  @override
  String get riderNoDone => 'अभी कुछ नहीं पहुँचाया।';

  @override
  String riderCollectCash(String amount) {
    return '$amount नकद लेना है';
  }

  @override
  String get riderPrepaid => 'ऑनलाइन भुगतान · कुछ नहीं लेना';

  @override
  String riderItems(int count) {
    return '$count आइटम';
  }

  @override
  String get riderPickUp => 'दुकान से उठा लिया';

  @override
  String get riderDeliver => 'पहुँचा दिया · कोड डालें';

  @override
  String get riderEnterOtp => 'ग्राहक से 4 अंकों का कोड माँगें';

  @override
  String get riderConfirm => 'पुष्टि करें';

  @override
  String get riderNavigate => 'रास्ता दिखाएँ';

  @override
  String riderNote(String note) {
    return 'नोट: $note';
  }

  @override
  String get riderSharingTitle => 'आपकी लोकेशन शेयर हो रही है';

  @override
  String get riderSharingText => 'ग्राहक देख सकते हैं कि आप आ रहे हैं।';

  @override
  String get riderNeedsPermission =>
      'ग्राहक आपको ट्रैक कर सकें, इसके लिए लोकेशन की अनुमति दें';

  @override
  String get riderGpsOff => 'ग्राहक आपको ट्रैक कर सकें, इसके लिए GPS चालू करें';

  @override
  String get riderCancelledReturn => 'रद्द · दुकान पर वापस करें';

  @override
  String get errorOrderNotPacked => 'दुकान ने अभी यह ऑर्डर पैक नहीं किया है।';

  @override
  String errorDeliveryOtp(int attempts) {
    return 'गलत कोड। $attempts प्रयास बाकी।';
  }

  @override
  String get errorDeliveryOtpLocked =>
      'बहुत गलत कोड। दुकान से पहुँचाया दर्ज करने को कहें।';

  @override
  String get errorDeliveryNotAssignable =>
      'ऑर्डर स्वीकार करने के बाद और दुकान से निकलने से पहले राइडर सौंपें।';

  @override
  String get errorDeliveryStarted => 'राइडर यह ऑर्डर उठा चुका है।';

  @override
  String get errorDeliveryClosed => 'यह डिलीवरी अब चालू नहीं है।';

  @override
  String get errorOwnerLocked => 'मालिक की भूमिका नहीं बदली जा सकती।';

  @override
  String get listOrderTitle => 'लिस्ट की फोटो से ऑर्डर';

  @override
  String get listOrderHint =>
      'दुकान आपकी लिस्ट पढ़कर पैक करेगी और भुगतान से पहले राशि बताएगी।';

  @override
  String get listPhotoLabel => 'आपकी लिस्ट की फोटो';

  @override
  String get prescriptionLabel => 'डॉक्टर का पर्चा';

  @override
  String get deliveryTimeTitle => 'डिलीवरी का समय';

  @override
  String get sendListOrder => 'ऑर्डर भेजें';

  @override
  String get today => 'आज';

  @override
  String get tomorrow => 'कल';

  @override
  String get noSlots =>
      'डिलीवरी का कोई समय नहीं बचा। दुकान से लें या बाद में ऑर्डर करें।';

  @override
  String get slotFull => 'भर गया';

  @override
  String deliverySlotLine(String day, String time) {
    return 'डिलीवरी: $day, $time';
  }

  @override
  String get yourPhotos => 'आपकी फोटो';

  @override
  String get customerPhotos => 'ग्राहक की फोटो';

  @override
  String get awaitingPricing =>
      'दुकान आपकी लिस्ट देख रही है। राशि यहाँ दिखेगी।';

  @override
  String get listOrderBadge => 'लिस्ट ऑर्डर';

  @override
  String get listOrderCta => 'अपनी लिस्ट की फोटो भेजें';

  @override
  String get listOrderCtaSub => 'कागज़ पर लिखें; दुकान पैक करके राशि बताएगी।';

  @override
  String get requestReturn => 'वापसी या बदलें';

  @override
  String get returnTypeReturn => 'वापसी';

  @override
  String get returnTypeExchange => 'बदलें';

  @override
  String get returnReasonLabel => 'क्या गड़बड़ हुई?';

  @override
  String get returnItemsTitle => 'सामान';

  @override
  String get returnPhotosLabel => 'फोटो (वैकल्पिक)';

  @override
  String get sendRequest => 'अनुरोध भेजें';

  @override
  String get returnSent => 'अनुरोध भेजा। दुकान जल्दी जवाब देगी।';

  @override
  String get returnRequested => 'दुकान के जवाब का इंतज़ार';

  @override
  String get returnApproved => 'स्वीकार';

  @override
  String get returnRejected => 'अस्वीकार';

  @override
  String get returnCompleted => 'पूरा';

  @override
  String returnShopNote(String note) {
    return 'दुकान: $note';
  }

  @override
  String get adminReturns => 'वापसी';

  @override
  String get adminReturnsSubtitle => 'वापसी और बदलने के अनुरोध';

  @override
  String get approve => 'स्वीकार करें';

  @override
  String get decline => 'अस्वीकार करें';

  @override
  String get markCompleted => 'पूरा हुआ';

  @override
  String get returnNoteLabel => 'ग्राहक के लिए संदेश';

  @override
  String get noReturns => 'कोई अनुरोध नहीं।';

  @override
  String get returnsOpen => 'खुले';

  @override
  String get returnsAll => 'सभी';

  @override
  String get setAmountTitle => 'इस लिस्ट की राशि';

  @override
  String get amountLabel => 'राशि ₹ में (डिलीवरी सहित)';

  @override
  String get errorSlot => 'वह डिलीवरी समय अब उपलब्ध नहीं है। दूसरा चुनें।';

  @override
  String get errorListEmpty => 'अपनी लिस्ट की फोटो जोड़ें।';

  @override
  String get errorPriceRequired => 'इस लिस्ट की राशि लिखें।';

  @override
  String get errorReturnWindow => 'इस ऑर्डर को वापस करने का समय खत्म हो गया।';

  @override
  String get errorReturnExists =>
      'इस ऑर्डर के लिए अनुरोध पहले ही भेजा जा चुका है।';

  @override
  String get errorReturnItems => 'वापस करने का सामान चुनें।';

  @override
  String get errorReturnNotAllowed => 'डिलीवरी के बाद ही वापसी हो सकती है।';

  @override
  String get errorReasonRequired => 'कृपया छोटा कारण लिखें।';

  @override
  String get adminSales => 'बिक्री';

  @override
  String get adminSalesSubtitle =>
      'बिक्री, सबसे ज़्यादा बिकने वाले सामान और ग्राहक';

  @override
  String get periodYesterday => 'बीता कल';

  @override
  String get period7 => '7 दिन';

  @override
  String get period30 => '30 दिन';

  @override
  String get periodMonth => 'इस महीने';

  @override
  String get statSales => 'बिक्री';

  @override
  String get statOrders => 'ऑर्डर';

  @override
  String get statAverage => 'औसत ऑर्डर';

  @override
  String get statCancelled => 'रद्द';

  @override
  String get dailySalesTitle => 'दिन के हिसाब से बिक्री';

  @override
  String get dayByDay => 'रोज़ का';

  @override
  String get tapBarHint => 'उस दिन को देखने के लिए बार पर टैप करें।';

  @override
  String get paymentsTitle => 'ग्राहकों ने कैसे भुगतान किया';

  @override
  String markedPaidTotal(String amount) {
    return 'भुगतान दर्ज: $amount';
  }

  @override
  String get fulfillmentTitle => 'डिलीवरी और पिकअप';

  @override
  String get customersTitle => 'ग्राहक';

  @override
  String newCustomers(int count) {
    return '$count नए';
  }

  @override
  String returningCustomers(int count) {
    return '$count दोबारा आए';
  }

  @override
  String get topProductsTitle => 'सबसे ज़्यादा बिके';

  @override
  String get noTopProducts => 'इस अवधि में अभी कोई बिक्री नहीं।';

  @override
  String ordersCount(int count) {
    return '$count ऑर्डर';
  }

  @override
  String soldQty(int count) {
    return '$count बिके';
  }

  @override
  String get salesNote =>
      'बिक्री = इस अवधि के ऑर्डर जो रद्द या अस्वीकार नहीं हुए।';
}
