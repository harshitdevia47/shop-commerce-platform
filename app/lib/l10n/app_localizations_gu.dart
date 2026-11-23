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
  String get roleRider => 'રાઇડર';

  @override
  String get roleCustomer => 'ગ્રાહક';

  @override
  String get adminTitle => 'દુકાન ડેશબોર્ડ';

  @override
  String adminWelcome(String name) {
    return 'નમસ્તે, $name';
  }

  @override
  String get adminComingSoon => 'ઓર્ડર અને વેચાણ અહીં દેખાશે.';

  @override
  String get riderTitle => 'ડિલિવરી';

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

  @override
  String get searchHint => 'ઉત્પાદનો શોધો';

  @override
  String get categoriesTitle => 'શ્રેણી પ્રમાણે ખરીદો';

  @override
  String get allProducts => 'બધા ઉત્પાદનો';

  @override
  String get allInCategory => 'બધું';

  @override
  String get outOfStock => 'સ્ટોકમાં નથી';

  @override
  String get noProducts => 'અહીં હજી કોઈ ઉત્પાદન નથી';

  @override
  String get searchPrompt => 'શોધવા માટે ઓછામાં ઓછા 2 અક્ષર લખો';

  @override
  String get loadMoreFailed => 'વધુ લોડ ન થયું. ફરી પ્રયાસ કરવા ટેપ કરો.';

  @override
  String get chooseVariant => 'વિકલ્પ પસંદ કરો';

  @override
  String get productDetails => 'ઉત્પાદનની વિગતો';

  @override
  String get orderingSoon => 'ઓર્ડર ટૂંક સમયમાં શરૂ થશે';

  @override
  String get shopInfo => 'દુકાનની માહિતી';

  @override
  String get adminProducts => 'ઉત્પાદનો';

  @override
  String get adminProductsSubtitle => 'ઉત્પાદનો, કિંમત, ફોટા અને સ્ટોક ઉમેરો';

  @override
  String get adminCategories => 'શ્રેણીઓ';

  @override
  String get adminCategoriesSubtitle => 'ગ્રાહકો કેવી રીતે જુએ તે ગોઠવો';

  @override
  String get addProduct => 'ઉત્પાદન ઉમેરો';

  @override
  String get editProduct => 'ઉત્પાદન બદલો';

  @override
  String get addCategory => 'શ્રેણી ઉમેરો';

  @override
  String get editCategory => 'શ્રેણી બદલો';

  @override
  String get statusAll => 'બધા';

  @override
  String get statusVisible => 'દેખાય છે';

  @override
  String get statusHidden => 'છુપાયેલા';

  @override
  String get nameEnglish => 'નામ (અંગ્રેજી)';

  @override
  String get nameGujarati => 'ગુજરાતીમાં નામ';

  @override
  String get nameHindi => 'હિન્દીમાં નામ';

  @override
  String get descriptionLabel => 'વર્ણન';

  @override
  String get categoryLabel => 'શ્રેણી';

  @override
  String get noCategory => 'કોઈ શ્રેણી નહીં';

  @override
  String get parentCategory => 'કઈ શ્રેણીની અંદર';

  @override
  String get topLevel => 'મુખ્ય શ્રેણી';

  @override
  String get photos => 'ફોટા';

  @override
  String get addPhoto => 'ફોટો ઉમેરો';

  @override
  String get takePhoto => 'કેમેરા';

  @override
  String get pickFromGallery => 'ગેલેરી';

  @override
  String get uploadingPhoto => 'ફોટો અપલોડ થાય છે…';

  @override
  String get pricesTitle => 'કિંમત';

  @override
  String get unitsTitle => 'માપ અને કિંમત';

  @override
  String get optionsTitle => 'વિકલ્પો અને કિંમત';

  @override
  String get unitLabel => 'એકમ, દા.ત. 500 ગ્રામ';

  @override
  String get priceLabel => 'કિંમત ₹';

  @override
  String get mrpLabel => 'MRP ₹';

  @override
  String get stockLabel => 'સ્ટોક (વૈકલ્પિક)';

  @override
  String get inStockLabel => 'સ્ટોકમાં છે';

  @override
  String get addVariant => 'બીજું ઉમેરો';

  @override
  String get remove => 'દૂર કરો';

  @override
  String get visibleToCustomers => 'ગ્રાહકોને દેખાય';

  @override
  String get tagsLabel => 'શોધ શબ્દો, અલ્પવિરામથી અલગ';

  @override
  String get moreDetails => 'વધુ વિગતો';

  @override
  String get delete => 'કાઢી નાખો';

  @override
  String get cancel => 'રદ કરો';

  @override
  String get deleteProductConfirm =>
      'આ ઉત્પાદન કાઢી નાખવું છે? ગ્રાહકો તેને જોઈ શકશે નહીં.';

  @override
  String get deleteCategoryConfirm => 'આ શ્રેણી કાઢી નાખવી છે?';

  @override
  String get requiredField => 'જરૂરી';

  @override
  String get invalidPrice => 'સાચી રકમ લખો';

  @override
  String get mrpBelowPrice => 'MRP કિંમતથી ઓછી ન હોઈ શકે';

  @override
  String get emptyCategories => 'હજી કોઈ શ્રેણી નથી';

  @override
  String get axisSize => 'સાઇઝ';

  @override
  String get axisColor => 'રંગ';

  @override
  String get axisMaterial => 'મટીરિયલ';

  @override
  String get axisFlavour => 'સ્વાદ';

  @override
  String get axisStorage => 'સ્ટોરેજ';

  @override
  String get errorInvalidVariants => 'માપ અને કિંમત તપાસો.';

  @override
  String get errorInvalidDetails => 'ઉત્પાદનની વિગતો તપાસો.';

  @override
  String get errorCategoryNotEmpty =>
      'પહેલાં તેના ઉત્પાદનો અને પેટા-શ્રેણીઓ ખસેડો અથવા કાઢો.';

  @override
  String get errorCategoryParent =>
      'શ્રેણી ફક્ત મુખ્ય શ્રેણીની અંદર જ હોઈ શકે.';

  @override
  String get errorPhotoTooLarge => 'આ ફોટો ખૂબ મોટો છે.';

  @override
  String get errorPhotoInvalid => 'આ ફાઇલ માન્ય ફોટો નથી.';

  @override
  String get errorNotFound => 'આ વસ્તુ હવે ઉપલબ્ધ નથી.';

  @override
  String get errorInvalidInput => 'તમે લખેલું તપાસો.';

  @override
  String percentOff(int percent) {
    return '$percent% છૂટ';
  }

  @override
  String variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count વિકલ્પો',
      one: '1 વિકલ્પ',
    );
    return '$_temp0';
  }

  @override
  String get addToCart => 'ઉમેરો';

  @override
  String get cartTitle => 'કાર્ટ';

  @override
  String get viewCart => 'કાર્ટ જુઓ';

  @override
  String get cartEmpty => 'તમારું કાર્ટ ખાલી છે';

  @override
  String get startShopping => 'ઉત્પાદનો જુઓ';

  @override
  String get billDetails => 'બિલ વિગતો';

  @override
  String get itemTotal => 'વસ્તુઓની કુલ રકમ';

  @override
  String get deliveryFeeLabel => 'ડિલિવરી ચાર્જ';

  @override
  String get free => 'મફત';

  @override
  String get toPay => 'ચૂકવવાના';

  @override
  String get lineUnavailable => 'હવે ઉપલબ્ધ નથી';

  @override
  String get proceed => 'આગળ વધો';

  @override
  String get loginToOrder => 'ઓર્ડર કરવા લૉગિન કરો';

  @override
  String get deliveryOption => 'ડિલિવરી';

  @override
  String get pickupOption => 'દુકાનેથી લઈ જાઓ';

  @override
  String get checkoutTitle => 'ચેકઆઉટ';

  @override
  String get deliverTo => 'ક્યાં પહોંચાડવું';

  @override
  String get pickupFrom => 'અહીંથી લઈ જાઓ';

  @override
  String get addAddress => 'સરનામું ઉમેરો';

  @override
  String get noAddresses => 'આગળ વધવા માટે ડિલિવરી સરનામું ઉમેરો';

  @override
  String get addressLine1 => 'ઘર / ફ્લેટ, શેરી';

  @override
  String get addressLine2 => 'વિસ્તાર (વૈકલ્પિક)';

  @override
  String get landmarkLabel => 'નજીકનું સ્થળ (વૈકલ્પિક)';

  @override
  String get cityLabel => 'શહેર';

  @override
  String get pincodeLabel => 'પિનકોડ';

  @override
  String get invalidPincode => '6 અંકનો પિનકોડ લખો';

  @override
  String get addressHome => 'ઘર';

  @override
  String get addressWork => 'ઓફિસ';

  @override
  String get addressOther => 'અન્ય';

  @override
  String get paymentMethodTitle => 'ચુકવણી';

  @override
  String get noteLabel => 'દુકાન માટે નોંધ (વૈકલ્પિક)';

  @override
  String get ordersTitle => 'મારા ઓર્ડર';

  @override
  String get noOrders => 'હજી કોઈ ઓર્ડર નથી';

  @override
  String get orderPlacedTitle => 'ઓર્ડર થઈ ગયો!';

  @override
  String get statusPlaced => 'ઓર્ડર થયો';

  @override
  String get statusConfirmed => 'સ્વીકાર્યો';

  @override
  String get statusPacked => 'પેક થયો';

  @override
  String get statusOutForDelivery => 'ડિલિવરી માટે નીકળ્યો';

  @override
  String get statusReadyForPickup => 'લઈ જવા તૈયાર';

  @override
  String get statusDelivered => 'પહોંચી ગયો';

  @override
  String get statusPickedUp => 'લઈ ગયા';

  @override
  String get statusCancelled => 'રદ થયો';

  @override
  String get statusRejected => 'દુકાને નકાર્યો';

  @override
  String get cancelOrder => 'ઓર્ડર રદ કરો';

  @override
  String get cancelOrderConfirm => 'આ ઓર્ડર રદ કરવો છે?';

  @override
  String get keepOrder => 'ઓર્ડર રાખો';

  @override
  String get utrPrompt =>
      'ચૂકવ્યા? દુકાન ખાતરી કરી શકે તે માટે UPI એપમાંથી 12 અંકનો UTR લખો.';

  @override
  String get utrLabel => 'UTR નંબર';

  @override
  String get submit => 'મોકલો';

  @override
  String get utrInvalid => 'UTR 12 અંકનો હોય છે';

  @override
  String get paymentPending => 'ચુકવણી બાકી';

  @override
  String get paymentSubmitted => 'ચુકવણી ચકાસાઈ રહી છે';

  @override
  String get paymentPaid => 'ચૂકવાઈ ગયું';

  @override
  String get paymentVoid => 'ચાર્જ નથી થયો';

  @override
  String get callShop => 'દુકાનને ફોન કરો';

  @override
  String get noUpiApp => 'આ ફોનમાં કોઈ UPI એપ નથી';

  @override
  String get adminOrders => 'ઓર્ડર';

  @override
  String get adminOrdersSubtitle => 'નવા, ચાલુ અને પૂરા થયેલા ઓર્ડર';

  @override
  String get tabNew => 'નવા';

  @override
  String get tabActive => 'ચાલુ';

  @override
  String get tabDone => 'પૂરા';

  @override
  String get noOrdersHere => 'અહીં કોઈ ઓર્ડર નથી';

  @override
  String get callCustomer => 'ગ્રાહકને ફોન કરો';

  @override
  String get markPaid => 'ચૂકવાયું ગણો';

  @override
  String get rejectOrder => 'નકારો';

  @override
  String get rejectReason => 'કારણ (ગ્રાહકને દેખાશે)';

  @override
  String get actionConfirm => 'ઓર્ડર સ્વીકારો';

  @override
  String get actionPack => 'પેક થયો';

  @override
  String get actionOutForDelivery => 'ડિલિવરી માટે મોકલો';

  @override
  String get actionReadyForPickup => 'લઈ જવા તૈયાર';

  @override
  String get actionDelivered => 'પહોંચાડ્યો';

  @override
  String get actionPickedUp => 'ગ્રાહક લઈ ગયા';

  @override
  String get customerNote => 'ગ્રાહકની નોંધ';

  @override
  String get errorCartChanged => 'કેટલીક વસ્તુઓ બદલાઈ છે. કાર્ટ ફરી જુઓ.';

  @override
  String get errorOutOfStock => 'કેટલીક વસ્તુઓ હમણાં જ ખતમ થઈ.';

  @override
  String get errorBelowMinimum => 'તમારો ઓર્ડર ઓછામાં ઓછી રકમથી ઓછો છે.';

  @override
  String get errorOutsideArea => 'દુકાન આ સરનામે ડિલિવરી કરતી નથી.';

  @override
  String get errorAddressRequired => 'ડિલિવરી સરનામું પસંદ કરો.';

  @override
  String get errorOptionUnavailable => 'આ વિકલ્પ આ દુકાનમાં ઉપલબ્ધ નથી.';

  @override
  String get errorNotCancellable =>
      'આ ઓર્ડર હવે રદ થઈ શકે નહીં. દુકાનને ફોન કરો.';

  @override
  String get errorOrderChanged => 'આ ઓર્ડર બીજાએ બદલ્યો છે. ફરી લોડ કર્યો.';

  @override
  String get errorPaymentClosed => 'આ ચુકવણી હવે બદલી શકાય નહીં.';

  @override
  String get errorAddressLimit => 'ઘણા સરનામા છે. પહેલાં એક કાઢો.';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count વસ્તુઓ',
      one: '1 વસ્તુ',
    );
    return '$_temp0';
  }

  @override
  String youSave(String amount) {
    return 'તમે $amount બચાવો છો';
  }

  @override
  String freeDeliveryGap(String amount) {
    return 'મફત ડિલિવરી માટે $amount ની વધુ ખરીદી કરો';
  }

  @override
  String minOrderGap(String amount, String minimum) {
    return 'ઓર્ડર માટે $amount ની વધુ ખરીદી કરો (ઓછામાં ઓછું $minimum)';
  }

  @override
  String lineOnlyLeft(int count) {
    return 'ફક્ત $count બાકી';
  }

  @override
  String setQtyTo(int count) {
    return '$count કરો';
  }

  @override
  String placeOrder(String amount) {
    return 'ઓર્ડર કરો · $amount';
  }

  @override
  String orderNumber(int number) {
    return 'ઓર્ડર #$number';
  }

  @override
  String payWithUpi(String amount) {
    return 'UPI થી $amount ચૂકવો';
  }

  @override
  String payOnDelivery(String amount) {
    return 'ડિલિવરી વખતે $amount રોકડા ચૂકવો';
  }

  @override
  String utrShown(String utr) {
    return 'UTR $utr';
  }

  @override
  String rejectedBecause(String reason) {
    return 'કારણ: $reason';
  }

  @override
  String get notificationChannelOrders => 'ઓર્ડર અપડેટ';

  @override
  String get deliveryPartner => 'તમારા ડિલિવરી પાર્ટનર';

  @override
  String get deliveryOtpLabel => 'ડિલિવરી કોડ';

  @override
  String get deliveryOtpHint => 'ઓર્ડર આવે ત્યારે આ કોડ રાઇડરને કહો.';

  @override
  String deliveryRiderDistance(String km, int minutes) {
    return '$km કિમી દૂર · આશરે $minutes મિનિટ';
  }

  @override
  String get deliveryRiderOnTheWay => 'તમારી તરફ આવી રહ્યા છે';

  @override
  String get deliveryTrackOnMap => 'નકશા પર જુઓ';

  @override
  String get callRider => 'રાઇડરને કૉલ કરો';

  @override
  String get deliverySection => 'ડિલિવરી';

  @override
  String get assignRider => 'રાઇડર સોંપો';

  @override
  String get changeRider => 'રાઇડર બદલો';

  @override
  String get chooseRider => 'રાઇડર પસંદ કરો';

  @override
  String get noRiders => 'હજી કોઈ રાઇડર નથી. ટીમમાં ઉમેરો.';

  @override
  String riderActiveCount(int count) {
    return '$count ચાલુ';
  }

  @override
  String get noRiderYet => 'હજી રાઇડર સોંપાયો નથી';

  @override
  String get deliveryAssigned => 'રાઇડર સોંપાયો';

  @override
  String get deliveryPickedUp => 'રસ્તામાં';

  @override
  String get deliveryDelivered => 'પહોંચાડ્યો';

  @override
  String get deliveryCancelled => 'રદ';

  @override
  String get adminTeam => 'ટીમ';

  @override
  String get adminTeamSubtitle => 'રાઇડર અને સ્ટાફ';

  @override
  String get teamAdd => 'વ્યક્તિ ઉમેરો';

  @override
  String get teamEmpty => 'હજી કોઈ રાઇડર કે સ્ટાફ નથી.';

  @override
  String get teamAdded => 'ઉમેર્યા. તેઓ આ નંબરથી લૉગિન કરશે.';

  @override
  String get teamRemove => 'દૂર કરો';

  @override
  String teamRemoveConfirm(String name) {
    return '$name ને ટીમમાંથી દૂર કરવા છે? તેઓ સામાન્ય ગ્રાહક બની જશે.';
  }

  @override
  String get nameOptional => 'નામ (વૈકલ્પિક)';

  @override
  String get riderActive => 'ચાલુ';

  @override
  String get riderDone => 'પૂરી';

  @override
  String get riderNoActive => 'હમણાં કોઈ ડિલિવરી નથી.';

  @override
  String get riderNoDone => 'હજી કંઈ પહોંચાડ્યું નથી.';

  @override
  String riderCollectCash(String amount) {
    return '$amount રોકડા લેવા';
  }

  @override
  String get riderPrepaid => 'ઓનલાઇન ચૂકવેલ · કંઈ લેવાનું નથી';

  @override
  String riderItems(int count) {
    return '$count વસ્તુઓ';
  }

  @override
  String get riderPickUp => 'દુકાનેથી લીધો';

  @override
  String get riderDeliver => 'પહોંચાડ્યો · કોડ નાખો';

  @override
  String get riderEnterOtp => 'ગ્રાહક પાસેથી 4 અંકનો કોડ માગો';

  @override
  String get riderConfirm => 'ખાતરી કરો';

  @override
  String get riderNavigate => 'રસ્તો બતાવો';

  @override
  String riderNote(String note) {
    return 'નોંધ: $note';
  }

  @override
  String get riderSharingTitle => 'તમારું લોકેશન શેર થાય છે';

  @override
  String get riderSharingText => 'ગ્રાહક જોઈ શકે છે કે તમે આવી રહ્યા છો.';

  @override
  String get riderNeedsPermission =>
      'ગ્રાહક તમને ટ્રૅક કરી શકે તે માટે લોકેશનની મંજૂરી આપો';

  @override
  String get riderGpsOff => 'ગ્રાહક તમને ટ્રૅક કરી શકે તે માટે GPS ચાલુ કરો';

  @override
  String get riderCancelledReturn => 'રદ · દુકાને પાછો આપો';

  @override
  String get errorOrderNotPacked => 'દુકાને હજી આ ઓર્ડર પેક કર્યો નથી.';

  @override
  String errorDeliveryOtp(int attempts) {
    return 'ખોટો કોડ. $attempts પ્રયાસ બાકી.';
  }

  @override
  String get errorDeliveryOtpLocked =>
      'ઘણા ખોટા કોડ. દુકાનને પહોંચાડ્યાનું નોંધવા કહો.';

  @override
  String get errorDeliveryNotAssignable =>
      'ઓર્ડર સ્વીકાર્યા પછી અને દુકાનમાંથી નીકળે તે પહેલાં રાઇડર સોંપો.';

  @override
  String get errorDeliveryStarted => 'રાઇડરે આ ઓર્ડર લઈ લીધો છે.';

  @override
  String get errorDeliveryClosed => 'આ ડિલિવરી હવે ચાલુ નથી.';

  @override
  String get errorOwnerLocked => 'માલિકની ભૂમિકા બદલી શકાતી નથી.';
}
