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

  @override
  String get paymentOnline => 'ऑनलाइन भुगतान (UPI, कार्ड, नेटबैंकिंग)';

  @override
  String get paymentOnlineShort => 'ऑनलाइन';

  @override
  String payOnline(String amount) {
    return '$amount ऑनलाइन चुकाएँ';
  }

  @override
  String get onlinePaymentNotDone =>
      'भुगतान पूरा नहीं हुआ। आप फिर से कोशिश कर सकते हैं।';

  @override
  String get errorPaymentVerify =>
      'इस भुगतान की पुष्टि नहीं हो सकी। अगर पैसे कटे हैं तो जल्द पुष्टि हो जाएगी।';

  @override
  String get errorOnlineUnavailable =>
      'ऑनलाइन भुगतान अभी उपलब्ध नहीं है। UPI या नकद आज़माएँ।';

  @override
  String otpSubtitleWhatsApp(String phone) {
    return '$phone पर WhatsApp पर भेजा गया';
  }

  @override
  String get adminSettings => 'दुकान सेटिंग्स';

  @override
  String get adminSettingsSubtitle => 'डिलीवरी, भुगतान, समय, दुकान बंद करना';

  @override
  String get settingsSave => 'सेटिंग्स सेव करें';

  @override
  String get settingsSaved => 'सेटिंग्स सेव हो गईं। ग्राहक अब इन्हें देखेंगे।';

  @override
  String get settingsFixFields => 'कृपया चिह्नित खाने ठीक करें';

  @override
  String get settingsAcceptingOrders => 'ऑर्डर ले रहे हैं';

  @override
  String get settingsOpenHint => 'ग्राहक अभी ऑर्डर दे सकते हैं';

  @override
  String get settingsPausedHint =>
      'ग्राहक सामान देख सकते हैं, पर ऑर्डर नहीं दे सकते';

  @override
  String get settingsPausedMessage => 'ग्राहकों के लिए संदेश (वैकल्पिक)';

  @override
  String get settingsPausedMessageHint =>
      'जैसे: दिवाली के लिए बंद, 3 नवंबर को फिर खुलेगा';

  @override
  String get settingsTooLong => 'बहुत लंबा है';

  @override
  String get settingsPausedNotice =>
      'आपकी दुकान ऑर्डर नहीं ले रही है। फिर से खोलने के लिए टैप करें।';

  @override
  String get settingsDeliverySection => 'डिलीवरी और पिकअप';

  @override
  String get settingsHomeDelivery => 'होम डिलीवरी';

  @override
  String get settingsDeliveryFee => 'डिलीवरी शुल्क';

  @override
  String get settingsMinOrder => 'डिलीवरी के लिए न्यूनतम ऑर्डर';

  @override
  String get settingsFreeAbove => 'इससे ऊपर मुफ़्त डिलीवरी';

  @override
  String get settingsFreeAboveHint => 'हमेशा शुल्क लेना हो तो खाली छोड़ें';

  @override
  String get settingsRadius => 'दुकान से डिलीवरी दूरी';

  @override
  String get settingsEta => 'सामान्य डिलीवरी समय';

  @override
  String get settingsMinutes => 'मिनट';

  @override
  String get settingsPincodes => 'डिलीवरी पिनकोड (वैकल्पिक)';

  @override
  String get settingsPincodesHint =>
      'कॉमा से अलग करें। खाली = दूरी के अंदर कोई भी पिनकोड';

  @override
  String get settingsPickup => 'ग्राहक दुकान से ले जा सकते हैं';

  @override
  String get settingsPickupHint =>
      'पिकअप पर कोई डिलीवरी शुल्क या न्यूनतम ऑर्डर नहीं';

  @override
  String get settingsSlotsSection => 'डिलीवरी टाइम स्लॉट';

  @override
  String get settingsSlots => 'ग्राहक समय चुनें';

  @override
  String get settingsSlotsHint => 'हर दिन वही स्लॉट';

  @override
  String get settingsSlotAdd => 'टाइम स्लॉट जोड़ें';

  @override
  String get settingsSlotRemove => 'स्लॉट हटाएं';

  @override
  String get settingsSlotStart => 'स्लॉट शुरू';

  @override
  String get settingsSlotEnd => 'स्लॉट खत्म';

  @override
  String get settingsSlotOrder =>
      'खत्म होने का समय शुरू होने के समय के बाद होना चाहिए';

  @override
  String get settingsSlotCapacity => 'एक स्लॉट में ऑर्डर';

  @override
  String get settingsPaymentsSection => 'भुगतान';

  @override
  String get settingsCod => 'कैश ऑन डिलीवरी';

  @override
  String get settingsUpi => 'आपके खाते में UPI';

  @override
  String get settingsUpiHint =>
      'ग्राहक किसी भी UPI ऐप से भुगतान करें; पैसे आने पर आप पुष्टि करें';

  @override
  String get settingsUpiId => 'आपकी UPI ID';

  @override
  String get settingsUpiName => 'भुगतान के समय दिखने वाला नाम';

  @override
  String get settingsOnlineOn => 'ऑनलाइन भुगतान (Razorpay) चालू है';

  @override
  String get settingsOnlineHint => 'बदलने के लिए सपोर्ट से संपर्क करें';

  @override
  String get settingsReturnsSection => 'रिटर्न';

  @override
  String get settingsReturns => 'रिटर्न अनुरोध स्वीकार करें';

  @override
  String get settingsReturnDays => 'ग्राहक इतने समय में पूछ सकते हैं';

  @override
  String get settingsDays => 'दिन';

  @override
  String get settingsExchange => 'बदली भी दें';

  @override
  String get settingsExtrasSection => 'ऑर्डर विकल्प';

  @override
  String get settingsOrderNotes => 'ग्राहक ऑर्डर में नोट लिख सकें';

  @override
  String get settingsListUpload => 'लिखी हुई सूची की फ़ोटो से ऑर्डर';

  @override
  String get settingsListUploadHint =>
      'स्वीकार करते समय आप बिल की राशि तय करें';

  @override
  String get settingsPrescription => 'प्रिस्क्रिप्शन फ़ोटो अपलोड';

  @override
  String get settingsContactSection => 'दुकान संपर्क';

  @override
  String get settingsShopPhone => 'दुकान का फ़ोन';

  @override
  String get settingsShopWhatsapp => 'WhatsApp नंबर (वैकल्पिक)';

  @override
  String get settingsShopAddress => 'दुकान का पता';

  @override
  String get settingsPlatformNote =>
      'दुकान का नाम, लोगो, रंग और ऐप आपके ऐप प्रदाता संभालते हैं। बदलने के लिए सपोर्ट से संपर्क करें।';

  @override
  String get settingsInvalidAmount => '20 या 20.50 जैसी राशि लिखें';

  @override
  String get settingsInvalidPincodes => 'हर पिनकोड में 6 अंक होते हैं';

  @override
  String get settingsInvalidUpi => 'shopname@okaxis जैसी UPI ID लिखें';

  @override
  String get settingsRequired => 'ज़रूरी';

  @override
  String get settingsNeedDeliveryOrPickup =>
      'होम डिलीवरी या पिकअप चालू करें, वरना ग्राहक ऑर्डर नहीं दे पाएंगे';

  @override
  String get settingsNeedPayment => 'कम से कम एक भुगतान तरीका चालू करें';

  @override
  String get settingsNeedSlot =>
      'कम से कम एक टाइम स्लॉट जोड़ें, या स्लॉट बंद करें';

  @override
  String get shopPausedTitle => 'दुकान अभी ऑर्डर नहीं ले रही है';

  @override
  String get shopPausedBody =>
      'आप सामान देख सकते हैं। कृपया बाद में फिर देखें।';

  @override
  String settingsNumberRange(int min, int max) {
    return '$min से $max के बीच की संख्या लिखें';
  }

  @override
  String get importTitle => 'Excel से जोड़ें';

  @override
  String get importHowTitle => 'बहुत सारा सामान एक साथ जोड़ें';

  @override
  String get importStep1 =>
      'टेम्पलेट लें और Excel या Google Sheets में खोलें (फ़ोन या कंप्यूटर पर)।';

  @override
  String get importStep2 =>
      'हर साइज़ के लिए एक लाइन भरें: कैटेगरी, नाम, साइज़ (जैसे 1 kg), कीमत, MRP, स्टॉक। गुजराती/हिंदी नाम वैकल्पिक हैं।';

  @override
  String get importStep3 =>
      'Excel (.xlsx) या CSV में सेव करें और यहां चुनें। कुछ भी सेव करने से पहले हर लाइन जांची जाती है।';

  @override
  String get importRules =>
      'दुकान में पहले से मौजूद सामान (वही नाम) दोबारा नहीं जुड़ता, अपडेट होता है: नई कीमत, स्टॉक और साइज़। खाली स्टॉक = नए सामान के लिए गिनती नहीं, पुराने के लिए बदलाव नहीं।';

  @override
  String get importGetTemplate => 'टेम्पलेट लें';

  @override
  String get importTemplateShareText =>
      'सामान की सूची का टेम्पलेट। भरकर दुकान के ऐप में इम्पोर्ट करें।';

  @override
  String get importPickFile => 'Excel या CSV फ़ाइल चुनें';

  @override
  String get importPickAnother => 'दूसरी फ़ाइल चुनें';

  @override
  String importFile(String name) {
    return 'फ़ाइल: $name';
  }

  @override
  String get importWrongFile =>
      'Excel (.xlsx) या CSV फ़ाइल चुनें। पुरानी .xls फ़ाइल: Excel में खोलकर .xlsx में सेव करें।';

  @override
  String get importUnreadable =>
      'यह फ़ाइल पढ़ी नहीं जा सकी। फिर से .xlsx या CSV में सेव करके कोशिश करें।';

  @override
  String importColumnsMissing(String columns) {
    return 'पहली लाइन में ये कॉलम नहीं हैं: $columns। टेम्पलेट इस्तेमाल करें।';
  }

  @override
  String get importEmpty => 'फ़ाइल में कोई सामान नहीं है।';

  @override
  String get importTooLarge =>
      'एक फ़ाइल में ज़्यादा से ज़्यादा 2000 लाइन। छोटी फ़ाइलों में बांटें।';

  @override
  String get importFixRows => 'कुछ लाइनें ठीक करनी हैं। नीचे सूची देखें।';

  @override
  String importReady(int rows) {
    return '$rows लाइनें इम्पोर्ट के लिए तैयार';
  }

  @override
  String get importNotReady => 'पहले ये लाइनें ठीक करें';

  @override
  String importNewProducts(int products, int sizes) {
    return 'नया सामान: $products ($sizes साइज़)';
  }

  @override
  String importUpdatedProducts(int products, int sizes) {
    return 'अपडेट होने वाला सामान: $products ($sizes साइज़)';
  }

  @override
  String importNewCategories(String names) {
    return 'नई कैटेगरी: $names';
  }

  @override
  String importIgnoredColumns(String names) {
    return 'इम्पोर्ट नहीं होंगे (अनजान कॉलम): $names';
  }

  @override
  String get importPhotosNote =>
      'फ़ाइल में फ़ोटो नहीं हैं: बाद में हर सामान में जोड़ें।';

  @override
  String importConfirm(int count) {
    return '$count सामान इम्पोर्ट करें';
  }

  @override
  String importDone(int added, int updated) {
    return 'हो गया: $added जोड़े, $updated अपडेट';
  }

  @override
  String importErrorsTitle(int count) {
    return '$count समस्याएं';
  }

  @override
  String get importErrorsHint =>
      'फ़ाइल में ठीक करें, सेव करें और फिर चुनें। अभी कुछ सेव नहीं हुआ है।';

  @override
  String importRowLabel(int row) {
    return 'लाइन $row';
  }

  @override
  String importRowColumnLabel(int row, String column) {
    return 'लाइन $row · कॉलम $column';
  }

  @override
  String importMoreErrors(int count) {
    return '…और $count और';
  }

  @override
  String get importErrNameRequired => 'सामान का नाम खाली है';

  @override
  String get importErrNameTooLong =>
      'नाम बहुत लंबा है (ज़्यादा से ज़्यादा 120 अक्षर)';

  @override
  String get importErrPrice => 'कीमत 120 या 120.50 जैसी संख्या होनी चाहिए';

  @override
  String get importErrMrp => 'MRP 150 जैसी संख्या होनी चाहिए';

  @override
  String get importErrMrpBelow => 'MRP कीमत से कम है';

  @override
  String get importErrStock => 'स्टॉक पूरी संख्या होनी चाहिए (0 या ज़्यादा)';

  @override
  String get importErrSize => 'साइज़ खाली है (जैसे 1 kg, 500 g, 1 पैक)';

  @override
  String get importErrOption => 'विकल्प लिखें (जैसे साइज़, रंग)';

  @override
  String get importErrDuplicateRow => 'वही सामान और साइज़ दो बार है';

  @override
  String get importErrDuplicateProduct => 'यह सामान एक से ज़्यादा बार है';

  @override
  String get importErrTooManyVariants =>
      'एक सामान के बहुत सारे साइज़ (ज़्यादा से ज़्यादा 50)';

  @override
  String get importErrField => 'यह मान यहां मान्य नहीं है';

  @override
  String get importErrFieldRequired => 'ज़रूरी जानकारी नहीं है';

  @override
  String get importErrOther => 'इस लाइन में समस्या है';

  @override
  String get quickAddShort => 'जल्दी जोड़ें';

  @override
  String get quickAddTitle => 'जल्दी जोड़ें';

  @override
  String get quickAddSaveNext => 'सेव करें और अगला';

  @override
  String get quickAddHint =>
      'एक के बाद एक सामान जोड़ें। कैटेगरी वही रहती है। बाकी जानकारी बाद में सामान की सूची से जोड़ें।';

  @override
  String quickAddSaved(String name) {
    return '$name जोड़ा';
  }

  @override
  String quickAddCount(int count) {
    return 'अभी जोड़े: $count';
  }

  @override
  String get quickAddStockHint => 'खाली = गिनती नहीं';

  @override
  String get setupTitle => 'अपनी दुकान तैयार करें';

  @override
  String get setupAllDone => 'आपकी दुकान तैयार है! 🎉';

  @override
  String get setupHide => 'छिपाएं';

  @override
  String setupProgress(int done, int total) {
    return '$total में से $done हो गया';
  }

  @override
  String get setupGotIt => 'ठीक है';

  @override
  String get setupCategories => 'कैटेगरी जोड़ें';

  @override
  String get setupCategoriesHint =>
      'जैसे चावल-अनाज, तेल, नमकीन: ग्राहक इनसे ढूंढते हैं';

  @override
  String get setupProducts => 'अपना सामान जोड़ें';

  @override
  String get setupProductsHint =>
      'एक-एक करके जल्दी जोड़ें, या Excel सूची इम्पोर्ट करें';

  @override
  String get setupPayments => 'अपनी UPI ID डालें';

  @override
  String get setupPaymentsHint => 'ग्राहक सीधे आपके खाते में भुगतान करें';

  @override
  String get setupSettings => 'डिलीवरी और समय जांचें';

  @override
  String get setupSettingsHint =>
      'डिलीवरी शुल्क, न्यूनतम ऑर्डर, इलाका, टाइम स्लॉट। एक बार सेव करें';

  @override
  String get setupRider => 'डिलीवरी वाला जोड़ें';

  @override
  String get setupRiderHint =>
      'उनका मोबाइल नंबर जोड़ें: वे लॉगिन करके डिलीवरी देखें';

  @override
  String get setupTestOrder => 'एक टेस्ट ऑर्डर दें';

  @override
  String get setupTestOrderHint =>
      'ग्राहकों को बताने से पहले एक बार पूरा ऑर्डर आज़माएं';

  @override
  String get setupTestOrderHow =>
      'लॉग आउट करें, दूसरे मोबाइल नंबर से (जैसे घर के किसी सदस्य का) लॉगिन करें, कुछ ऑर्डर करें और कैश चुनें। फिर मालिक के रूप में दोबारा लॉगिन करें, ऑर्डर खोलें और स्वीकार करें। ठीक चले तो रद्द करें या डिलीवर करें।';

  @override
  String get supportTitle => 'मदद चाहिए?';

  @override
  String get supportSubtitle => 'WhatsApp पर सपोर्ट से बात करें';

  @override
  String supportMessage(String shop) {
    return 'नमस्ते, मुझे $shop ऐप में मदद चाहिए।';
  }

  @override
  String supportNoWhatsapp(String number) {
    return 'WhatsApp नहीं है। सपोर्ट को $number पर मैसेज करें।';
  }

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get termsOfUse => 'उपयोग की शर्तें';

  @override
  String get legalAgree => 'आगे बढ़कर आप इनसे सहमत हैं:';

  @override
  String get deleteAccount => 'मेरा अकाउंट डिलीट करें';

  @override
  String get deleteAccountTitle => 'अपना अकाउंट डिलीट करें?';

  @override
  String get deleteAccountBody =>
      'आपका फ़ोन नंबर, नाम और सेव किए गए पते हटा दिए जाएंगे और आप लॉग आउट हो जाएंगे। पुराने ऑर्डर दुकान के हिसाब के लिए दुकान के पास रहेंगे। यह वापस नहीं हो सकता।';

  @override
  String get deleteAccountConfirm => 'डिलीट करें';

  @override
  String get deleteAccountDone => 'आपका अकाउंट डिलीट हो गया';

  @override
  String get errorAccountOpenOrders =>
      'आपका एक ऑर्डर अभी रास्ते में है। उसके डिलीवर या रद्द होने के बाद आप अकाउंट डिलीट कर सकते हैं।';

  @override
  String get errorAccountDeleteTeam =>
      'टीम के अकाउंट दुकान के मालिक हटाते हैं, और मालिक का अकाउंट सपोर्ट से बंद होता है।';
}
