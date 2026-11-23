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
  String get adminComingSoon => 'ઓર્ડર અને વેચાણ અહીં દેખાશે.';

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
}
