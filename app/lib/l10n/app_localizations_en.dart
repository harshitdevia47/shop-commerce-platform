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

  @override
  String get login => 'Log in';

  @override
  String get logout => 'Log out';

  @override
  String get account => 'Account';

  @override
  String get loginTitle => 'Log in to continue';

  @override
  String get loginSubtitle =>
      'We will send a 6-digit code to your mobile number.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get sendOtp => 'Send code';

  @override
  String get otpTitle => 'Enter verification code';

  @override
  String otpSubtitle(String phone) {
    return 'Sent to $phone';
  }

  @override
  String get verify => 'Verify';

  @override
  String resendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resend => 'Resend code';

  @override
  String get changeNumber => 'Change number';

  @override
  String devOtpHint(String code) {
    return 'Dev code: $code';
  }

  @override
  String get nameLabel => 'Your name';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleStaff => 'Staff';

  @override
  String get roleRider => 'Delivery partner';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get adminTitle => 'Shop dashboard';

  @override
  String adminWelcome(String name) {
    return 'Hello, $name';
  }

  @override
  String get adminComingSoon => 'Orders and sales will appear here.';

  @override
  String get riderTitle => 'Deliveries';

  @override
  String get riderComingSoon => 'Deliveries assigned to you will appear here.';

  @override
  String get errorPhoneInvalid => 'Enter a valid 10-digit mobile number.';

  @override
  String errorOtpInvalid(int attempts) {
    return 'Incorrect code. $attempts attempts left.';
  }

  @override
  String get errorOtpExpired => 'Code expired. Request a new one.';

  @override
  String get errorOtpTooManyAttempts =>
      'Too many wrong attempts. Request a new code.';

  @override
  String get errorOtpTooSoon =>
      'Please wait a moment before requesting another code.';

  @override
  String get errorOtpTooManyRequests =>
      'Too many codes requested. Try again later.';

  @override
  String get errorUserBlocked =>
      'This account is blocked. Please contact the shop.';

  @override
  String get errorSmsFailed => 'Could not send the code. Please try again.';

  @override
  String get sessionExpired => 'Your session expired. Please log in again.';

  @override
  String get searchHint => 'Search for products';

  @override
  String get categoriesTitle => 'Shop by category';

  @override
  String get allProducts => 'All products';

  @override
  String get allInCategory => 'All';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get noProducts => 'No products here yet';

  @override
  String get searchPrompt => 'Type at least 2 letters to search';

  @override
  String get loadMoreFailed => 'Couldn\'t load more. Tap to retry.';

  @override
  String get chooseVariant => 'Choose an option';

  @override
  String get productDetails => 'Product details';

  @override
  String get orderingSoon => 'Ordering opens soon';

  @override
  String get shopInfo => 'Shop info';

  @override
  String get adminProducts => 'Products';

  @override
  String get adminProductsSubtitle => 'Add products, prices, photos and stock';

  @override
  String get adminCategories => 'Categories';

  @override
  String get adminCategoriesSubtitle => 'Organise how customers browse';

  @override
  String get addProduct => 'Add product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get statusAll => 'All';

  @override
  String get statusVisible => 'Visible';

  @override
  String get statusHidden => 'Hidden';

  @override
  String get nameEnglish => 'Name (English)';

  @override
  String get nameGujarati => 'Name in Gujarati';

  @override
  String get nameHindi => 'Name in Hindi';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get categoryLabel => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get parentCategory => 'Inside category';

  @override
  String get topLevel => 'Top level';

  @override
  String get photos => 'Photos';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get takePhoto => 'Camera';

  @override
  String get pickFromGallery => 'Gallery';

  @override
  String get uploadingPhoto => 'Uploading photo…';

  @override
  String get pricesTitle => 'Price';

  @override
  String get unitsTitle => 'Sizes and prices';

  @override
  String get optionsTitle => 'Options and prices';

  @override
  String get unitLabel => 'Unit, e.g. 500 g';

  @override
  String get priceLabel => 'Price ₹';

  @override
  String get mrpLabel => 'MRP ₹';

  @override
  String get stockLabel => 'Stock (optional)';

  @override
  String get inStockLabel => 'In stock';

  @override
  String get addVariant => 'Add another';

  @override
  String get remove => 'Remove';

  @override
  String get visibleToCustomers => 'Visible to customers';

  @override
  String get tagsLabel => 'Search words, comma separated';

  @override
  String get moreDetails => 'More details';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteProductConfirm =>
      'Delete this product? Customers will no longer see it.';

  @override
  String get deleteCategoryConfirm => 'Delete this category?';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidPrice => 'Enter a valid amount';

  @override
  String get mrpBelowPrice => 'MRP cannot be less than price';

  @override
  String get emptyCategories => 'No categories yet';

  @override
  String get axisSize => 'Size';

  @override
  String get axisColor => 'Colour';

  @override
  String get axisMaterial => 'Material';

  @override
  String get axisFlavour => 'Flavour';

  @override
  String get axisStorage => 'Storage';

  @override
  String get errorInvalidVariants => 'Check the sizes and prices.';

  @override
  String get errorInvalidDetails => 'Check the product details.';

  @override
  String get errorCategoryNotEmpty =>
      'Move or delete its products and sub-categories first.';

  @override
  String get errorCategoryParent =>
      'A category can only be inside a top-level category.';

  @override
  String get errorPhotoTooLarge => 'This photo is too large.';

  @override
  String get errorPhotoInvalid => 'This file is not a supported photo.';

  @override
  String get errorNotFound => 'This item is no longer available.';

  @override
  String get errorInvalidInput => 'Please check what you entered.';

  @override
  String percentOff(int percent) {
    return '$percent% off';
  }

  @override
  String variantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$_temp0';
  }
}
