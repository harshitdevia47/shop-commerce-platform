import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// Name of this language, shown in the language picker
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errorNetwork;

  /// No description provided for @errorShopInactive.
  ///
  /// In en, this message translates to:
  /// **'This shop is not taking orders right now.'**
  String get errorShopInactive;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {shopName}'**
  String welcome(String shopName);

  /// No description provided for @deliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryTitle;

  /// No description provided for @deliveryEta.
  ///
  /// In en, this message translates to:
  /// **'Delivery in about {minutes} min'**
  String deliveryEta(int minutes);

  /// No description provided for @deliveryMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum order {amount}'**
  String deliveryMinOrder(String amount);

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee {amount}'**
  String deliveryFee(String amount);

  /// No description provided for @deliveryFreeAbove.
  ///
  /// In en, this message translates to:
  /// **'Free delivery above {amount}'**
  String deliveryFreeAbove(String amount);

  /// No description provided for @deliveryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Delivery is not available. Pick up from the store.'**
  String get deliveryUnavailable;

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment options'**
  String get paymentTitle;

  /// No description provided for @paymentCod.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get paymentCod;

  /// No description provided for @paymentUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get paymentUpi;

  /// No description provided for @featuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Available services'**
  String get featuresTitle;

  /// No description provided for @featureDeliverySlots.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery time slot'**
  String get featureDeliverySlots;

  /// No description provided for @featureStorePickup.
  ///
  /// In en, this message translates to:
  /// **'Store pickup'**
  String get featureStorePickup;

  /// No description provided for @featureReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns and exchange'**
  String get featureReturns;

  /// No description provided for @featurePrescriptionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload prescription'**
  String get featurePrescriptionUpload;

  /// No description provided for @featureOrderNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes to your order'**
  String get featureOrderNotes;

  /// No description provided for @featureHandwrittenListUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of your shopping list'**
  String get featureHandwrittenListUpload;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to continue'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will send a 6-digit code to your mobile number.'**
  String get loginSubtitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendOtp;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent to {phone}'**
  String otpSubtitle(String phone);

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resend;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @devOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Dev code: {code}'**
  String devOtpHint(String code);

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// No description provided for @roleRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get roleRider;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop dashboard'**
  String get adminTitle;

  /// No description provided for @adminWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String adminWelcome(String name);

  /// No description provided for @adminComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Orders and sales will appear here.'**
  String get adminComingSoon;

  /// No description provided for @riderTitle.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get riderTitle;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number.'**
  String get errorPhoneInvalid;

  /// No description provided for @errorOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. {attempts} attempts left.'**
  String errorOtpInvalid(int attempts);

  /// No description provided for @errorOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Request a new one.'**
  String get errorOtpExpired;

  /// No description provided for @errorOtpTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Request a new code.'**
  String get errorOtpTooManyAttempts;

  /// No description provided for @errorOtpTooSoon.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting another code.'**
  String get errorOtpTooSoon;

  /// No description provided for @errorOtpTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many codes requested. Try again later.'**
  String get errorOtpTooManyRequests;

  /// No description provided for @errorUserBlocked.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked. Please contact the shop.'**
  String get errorUserBlocked;

  /// No description provided for @errorSmsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the code. Please try again.'**
  String get errorSmsFailed;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get sessionExpired;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for products'**
  String get searchHint;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop by category'**
  String get categoriesTitle;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All products'**
  String get allProducts;

  /// No description provided for @allInCategory.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allInCategory;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @noProducts.
  ///
  /// In en, this message translates to:
  /// **'No products here yet'**
  String get noProducts;

  /// No description provided for @searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 letters to search'**
  String get searchPrompt;

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Tap to retry.'**
  String get loadMoreFailed;

  /// No description provided for @chooseVariant.
  ///
  /// In en, this message translates to:
  /// **'Choose an option'**
  String get chooseVariant;

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product details'**
  String get productDetails;

  /// No description provided for @orderingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ordering opens soon'**
  String get orderingSoon;

  /// No description provided for @shopInfo.
  ///
  /// In en, this message translates to:
  /// **'Shop info'**
  String get shopInfo;

  /// No description provided for @adminProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get adminProducts;

  /// No description provided for @adminProductsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add products, prices, photos and stock'**
  String get adminProductsSubtitle;

  /// No description provided for @adminCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get adminCategories;

  /// No description provided for @adminCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organise how customers browse'**
  String get adminCategoriesSubtitle;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get statusVisible;

  /// No description provided for @statusHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get statusHidden;

  /// No description provided for @nameEnglish.
  ///
  /// In en, this message translates to:
  /// **'Name (English)'**
  String get nameEnglish;

  /// No description provided for @nameGujarati.
  ///
  /// In en, this message translates to:
  /// **'Name in Gujarati'**
  String get nameGujarati;

  /// No description provided for @nameHindi.
  ///
  /// In en, this message translates to:
  /// **'Name in Hindi'**
  String get nameHindi;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Inside category'**
  String get parentCategory;

  /// No description provided for @topLevel.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get topLevel;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get takePhoto;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get pickFromGallery;

  /// No description provided for @uploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get uploadingPhoto;

  /// No description provided for @pricesTitle.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get pricesTitle;

  /// No description provided for @unitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sizes and prices'**
  String get unitsTitle;

  /// No description provided for @optionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options and prices'**
  String get optionsTitle;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit, e.g. 500 g'**
  String get unitLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price ₹'**
  String get priceLabel;

  /// No description provided for @mrpLabel.
  ///
  /// In en, this message translates to:
  /// **'MRP ₹'**
  String get mrpLabel;

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock (optional)'**
  String get stockLabel;

  /// No description provided for @inStockLabel.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStockLabel;

  /// No description provided for @addVariant.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get addVariant;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @visibleToCustomers.
  ///
  /// In en, this message translates to:
  /// **'Visible to customers'**
  String get visibleToCustomers;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Search words, comma separated'**
  String get tagsLabel;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetails;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteProductConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this product? Customers will no longer see it.'**
  String get deleteProductConfirm;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get deleteCategoryConfirm;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get invalidPrice;

  /// No description provided for @mrpBelowPrice.
  ///
  /// In en, this message translates to:
  /// **'MRP cannot be less than price'**
  String get mrpBelowPrice;

  /// No description provided for @emptyCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get emptyCategories;

  /// No description provided for @axisSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get axisSize;

  /// No description provided for @axisColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get axisColor;

  /// No description provided for @axisMaterial.
  ///
  /// In en, this message translates to:
  /// **'Material'**
  String get axisMaterial;

  /// No description provided for @axisFlavour.
  ///
  /// In en, this message translates to:
  /// **'Flavour'**
  String get axisFlavour;

  /// No description provided for @axisStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get axisStorage;

  /// No description provided for @errorInvalidVariants.
  ///
  /// In en, this message translates to:
  /// **'Check the sizes and prices.'**
  String get errorInvalidVariants;

  /// No description provided for @errorInvalidDetails.
  ///
  /// In en, this message translates to:
  /// **'Check the product details.'**
  String get errorInvalidDetails;

  /// No description provided for @errorCategoryNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Move or delete its products and sub-categories first.'**
  String get errorCategoryNotEmpty;

  /// No description provided for @errorCategoryParent.
  ///
  /// In en, this message translates to:
  /// **'A category can only be inside a top-level category.'**
  String get errorCategoryParent;

  /// No description provided for @errorPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large.'**
  String get errorPhotoTooLarge;

  /// No description provided for @errorPhotoInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a supported photo.'**
  String get errorPhotoInvalid;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get errorNotFound;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Please check what you entered.'**
  String get errorInvalidInput;

  /// No description provided for @percentOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String percentOff(int percent);

  /// No description provided for @variantCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 option} other{{count} options}}'**
  String variantCount(int count);

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get addToCart;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cartTitle;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Browse products'**
  String get startShopping;

  /// No description provided for @billDetails.
  ///
  /// In en, this message translates to:
  /// **'Bill details'**
  String get billDetails;

  /// No description provided for @itemTotal.
  ///
  /// In en, this message translates to:
  /// **'Item total'**
  String get itemTotal;

  /// No description provided for @deliveryFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get deliveryFeeLabel;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get free;

  /// No description provided for @toPay.
  ///
  /// In en, this message translates to:
  /// **'To pay'**
  String get toPay;

  /// No description provided for @lineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get lineUnavailable;

  /// No description provided for @proceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get proceed;

  /// No description provided for @loginToOrder.
  ///
  /// In en, this message translates to:
  /// **'Log in to place your order'**
  String get loginToOrder;

  /// No description provided for @deliveryOption.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryOption;

  /// No description provided for @pickupOption.
  ///
  /// In en, this message translates to:
  /// **'Store pickup'**
  String get pickupOption;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// No description provided for @pickupFrom.
  ///
  /// In en, this message translates to:
  /// **'Pick up from'**
  String get pickupFrom;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// No description provided for @noAddresses.
  ///
  /// In en, this message translates to:
  /// **'Add a delivery address to continue'**
  String get noAddresses;

  /// No description provided for @addressLine1.
  ///
  /// In en, this message translates to:
  /// **'House / flat, street'**
  String get addressLine1;

  /// No description provided for @addressLine2.
  ///
  /// In en, this message translates to:
  /// **'Area (optional)'**
  String get addressLine2;

  /// No description provided for @landmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get landmarkLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @pincodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincodeLabel;

  /// No description provided for @invalidPincode.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit pincode'**
  String get invalidPincode;

  /// No description provided for @addressHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get addressHome;

  /// No description provided for @addressWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get addressWork;

  /// No description provided for @addressOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addressOther;

  /// No description provided for @paymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentMethodTitle;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for the shop (optional)'**
  String get noteLabel;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get ordersTitle;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrders;

  /// No description provided for @orderPlacedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderPlacedTitle;

  /// No description provided for @statusPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get statusPlaced;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusPacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get statusPacked;

  /// No description provided for @statusOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get statusOutForDelivery;

  /// No description provided for @statusReadyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get statusReadyForPickup;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get statusPickedUp;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected by shop'**
  String get statusRejected;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @cancelOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this order?'**
  String get cancelOrderConfirm;

  /// No description provided for @keepOrder.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get keepOrder;

  /// No description provided for @utrPrompt.
  ///
  /// In en, this message translates to:
  /// **'Paid? Enter the 12-digit UTR from your UPI app so the shop can confirm.'**
  String get utrPrompt;

  /// No description provided for @utrLabel.
  ///
  /// In en, this message translates to:
  /// **'UTR number'**
  String get utrLabel;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @utrInvalid.
  ///
  /// In en, this message translates to:
  /// **'UTR is 12 digits'**
  String get utrInvalid;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get paymentPending;

  /// No description provided for @paymentSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Payment being verified'**
  String get paymentSubmitted;

  /// No description provided for @paymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paymentPaid;

  /// No description provided for @paymentVoid.
  ///
  /// In en, this message translates to:
  /// **'Not charged'**
  String get paymentVoid;

  /// No description provided for @callShop.
  ///
  /// In en, this message translates to:
  /// **'Call shop'**
  String get callShop;

  /// No description provided for @noUpiApp.
  ///
  /// In en, this message translates to:
  /// **'No UPI app found on this phone'**
  String get noUpiApp;

  /// No description provided for @adminOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get adminOrders;

  /// No description provided for @adminOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New, in progress and completed orders'**
  String get adminOrdersSubtitle;

  /// No description provided for @tabNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get tabNew;

  /// No description provided for @tabActive.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get tabActive;

  /// No description provided for @tabDone.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tabDone;

  /// No description provided for @noOrdersHere.
  ///
  /// In en, this message translates to:
  /// **'No orders here'**
  String get noOrdersHere;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get callCustomer;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get markPaid;

  /// No description provided for @rejectOrder.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectOrder;

  /// No description provided for @rejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (shown to the customer)'**
  String get rejectReason;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get actionConfirm;

  /// No description provided for @actionPack.
  ///
  /// In en, this message translates to:
  /// **'Mark packed'**
  String get actionPack;

  /// No description provided for @actionOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Send for delivery'**
  String get actionOutForDelivery;

  /// No description provided for @actionReadyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get actionReadyForPickup;

  /// No description provided for @actionDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get actionDelivered;

  /// No description provided for @actionPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Customer picked up'**
  String get actionPickedUp;

  /// No description provided for @customerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer note'**
  String get customerNote;

  /// No description provided for @errorCartChanged.
  ///
  /// In en, this message translates to:
  /// **'Some items changed. Please review your cart.'**
  String get errorCartChanged;

  /// No description provided for @errorOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Some items just ran out.'**
  String get errorOutOfStock;

  /// No description provided for @errorBelowMinimum.
  ///
  /// In en, this message translates to:
  /// **'Your order is below the minimum amount.'**
  String get errorBelowMinimum;

  /// No description provided for @errorOutsideArea.
  ///
  /// In en, this message translates to:
  /// **'The shop does not deliver to this address.'**
  String get errorOutsideArea;

  /// No description provided for @errorAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery address.'**
  String get errorAddressRequired;

  /// No description provided for @errorOptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This option is not available at this shop.'**
  String get errorOptionUnavailable;

  /// No description provided for @errorNotCancellable.
  ///
  /// In en, this message translates to:
  /// **'This order can no longer be cancelled. Please call the shop.'**
  String get errorNotCancellable;

  /// No description provided for @errorOrderChanged.
  ///
  /// In en, this message translates to:
  /// **'Someone else updated this order. Refreshed.'**
  String get errorOrderChanged;

  /// No description provided for @errorPaymentClosed.
  ///
  /// In en, this message translates to:
  /// **'This payment can no longer be changed.'**
  String get errorPaymentClosed;

  /// No description provided for @errorAddressLimit.
  ///
  /// In en, this message translates to:
  /// **'You have too many addresses. Delete one first.'**
  String get errorAddressLimit;

  /// No description provided for @cartItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String cartItems(int count);

  /// No description provided for @youSave.
  ///
  /// In en, this message translates to:
  /// **'You save {amount}'**
  String youSave(String amount);

  /// No description provided for @freeDeliveryGap.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more for free delivery'**
  String freeDeliveryGap(String amount);

  /// No description provided for @minOrderGap.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} more to order (minimum {minimum})'**
  String minOrderGap(String amount, String minimum);

  /// No description provided for @lineOnlyLeft.
  ///
  /// In en, this message translates to:
  /// **'Only {count} left'**
  String lineOnlyLeft(int count);

  /// No description provided for @setQtyTo.
  ///
  /// In en, this message translates to:
  /// **'Change to {count}'**
  String setQtyTo(int count);

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place order · {amount}'**
  String placeOrder(String amount);

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String orderNumber(int number);

  /// No description provided for @payWithUpi.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} with UPI'**
  String payWithUpi(String amount);

  /// No description provided for @payOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} in cash on delivery'**
  String payOnDelivery(String amount);

  /// No description provided for @utrShown.
  ///
  /// In en, this message translates to:
  /// **'UTR {utr}'**
  String utrShown(String utr);

  /// No description provided for @rejectedBecause.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String rejectedBecause(String reason);

  /// Android notification channel name (Settings > Apps > Notifications)
  ///
  /// In en, this message translates to:
  /// **'Order updates'**
  String get notificationChannelOrders;

  /// No description provided for @deliveryPartner.
  ///
  /// In en, this message translates to:
  /// **'Your delivery partner'**
  String get deliveryPartner;

  /// No description provided for @deliveryOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery code'**
  String get deliveryOtpLabel;

  /// No description provided for @deliveryOtpHint.
  ///
  /// In en, this message translates to:
  /// **'Tell this code to the rider when your order arrives.'**
  String get deliveryOtpHint;

  /// No description provided for @deliveryRiderDistance.
  ///
  /// In en, this message translates to:
  /// **'{km} km away · about {minutes} min'**
  String deliveryRiderDistance(String km, int minutes);

  /// No description provided for @deliveryRiderOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way to you'**
  String get deliveryRiderOnTheWay;

  /// No description provided for @deliveryTrackOnMap.
  ///
  /// In en, this message translates to:
  /// **'Track on map'**
  String get deliveryTrackOnMap;

  /// No description provided for @callRider.
  ///
  /// In en, this message translates to:
  /// **'Call rider'**
  String get callRider;

  /// No description provided for @deliverySection.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliverySection;

  /// No description provided for @assignRider.
  ///
  /// In en, this message translates to:
  /// **'Assign rider'**
  String get assignRider;

  /// No description provided for @changeRider.
  ///
  /// In en, this message translates to:
  /// **'Change rider'**
  String get changeRider;

  /// No description provided for @chooseRider.
  ///
  /// In en, this message translates to:
  /// **'Choose a rider'**
  String get chooseRider;

  /// No description provided for @noRiders.
  ///
  /// In en, this message translates to:
  /// **'No riders yet. Add them in Team.'**
  String get noRiders;

  /// No description provided for @riderActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String riderActiveCount(int count);

  /// No description provided for @noRiderYet.
  ///
  /// In en, this message translates to:
  /// **'No rider assigned yet'**
  String get noRiderYet;

  /// No description provided for @deliveryAssigned.
  ///
  /// In en, this message translates to:
  /// **'Rider assigned'**
  String get deliveryAssigned;

  /// No description provided for @deliveryPickedUp.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get deliveryPickedUp;

  /// No description provided for @deliveryDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryDelivered;

  /// No description provided for @deliveryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get deliveryCancelled;

  /// No description provided for @adminTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get adminTeam;

  /// No description provided for @adminTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Riders and staff'**
  String get adminTeamSubtitle;

  /// No description provided for @teamAdd.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get teamAdd;

  /// No description provided for @teamEmpty.
  ///
  /// In en, this message translates to:
  /// **'No riders or staff yet.'**
  String get teamEmpty;

  /// No description provided for @teamAdded.
  ///
  /// In en, this message translates to:
  /// **'Added. They log in with this number.'**
  String get teamAdded;

  /// No description provided for @teamRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get teamRemove;

  /// No description provided for @teamRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the team? They become a normal customer.'**
  String teamRemoveConfirm(String name);

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @riderActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get riderActive;

  /// No description provided for @riderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get riderDone;

  /// No description provided for @riderNoActive.
  ///
  /// In en, this message translates to:
  /// **'No deliveries right now.'**
  String get riderNoActive;

  /// No description provided for @riderNoDone.
  ///
  /// In en, this message translates to:
  /// **'Nothing delivered yet.'**
  String get riderNoDone;

  /// No description provided for @riderCollectCash.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} in cash'**
  String riderCollectCash(String amount);

  /// No description provided for @riderPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Paid online · nothing to collect'**
  String get riderPrepaid;

  /// No description provided for @riderItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String riderItems(int count);

  /// No description provided for @riderPickUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up from shop'**
  String get riderPickUp;

  /// No description provided for @riderDeliver.
  ///
  /// In en, this message translates to:
  /// **'Delivered · enter code'**
  String get riderDeliver;

  /// No description provided for @riderEnterOtp.
  ///
  /// In en, this message translates to:
  /// **'Ask the customer for the 4-digit code'**
  String get riderEnterOtp;

  /// No description provided for @riderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get riderConfirm;

  /// No description provided for @riderNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get riderNavigate;

  /// No description provided for @riderNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String riderNote(String note);

  /// No description provided for @riderSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing your location'**
  String get riderSharingTitle;

  /// No description provided for @riderSharingText.
  ///
  /// In en, this message translates to:
  /// **'The customer can see you are on the way.'**
  String get riderSharingText;

  /// No description provided for @riderNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow location so the customer can track you'**
  String get riderNeedsPermission;

  /// No description provided for @riderGpsOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on GPS so the customer can track you'**
  String get riderGpsOff;

  /// No description provided for @riderCancelledReturn.
  ///
  /// In en, this message translates to:
  /// **'Cancelled · return it to the shop'**
  String get riderCancelledReturn;

  /// No description provided for @errorOrderNotPacked.
  ///
  /// In en, this message translates to:
  /// **'The shop has not packed this order yet.'**
  String get errorOrderNotPacked;

  /// No description provided for @errorDeliveryOtp.
  ///
  /// In en, this message translates to:
  /// **'Wrong code. {attempts} attempts left.'**
  String errorDeliveryOtp(int attempts);

  /// No description provided for @errorDeliveryOtpLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong codes. Ask the shop to mark it delivered.'**
  String get errorDeliveryOtpLocked;

  /// No description provided for @errorDeliveryNotAssignable.
  ///
  /// In en, this message translates to:
  /// **'Assign a rider after accepting the order and before it leaves the shop.'**
  String get errorDeliveryNotAssignable;

  /// No description provided for @errorDeliveryStarted.
  ///
  /// In en, this message translates to:
  /// **'The rider has already picked this order up.'**
  String get errorDeliveryStarted;

  /// No description provided for @errorDeliveryClosed.
  ///
  /// In en, this message translates to:
  /// **'This delivery is no longer active.'**
  String get errorDeliveryClosed;

  /// No description provided for @errorOwnerLocked.
  ///
  /// In en, this message translates to:
  /// **'The owner\'s role can\'t be changed.'**
  String get errorOwnerLocked;

  /// No description provided for @listOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Order with a list photo'**
  String get listOrderTitle;

  /// No description provided for @listOrderHint.
  ///
  /// In en, this message translates to:
  /// **'The shop reads your list, packs it and tells you the amount before you pay.'**
  String get listOrderHint;

  /// No description provided for @listPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo of your list'**
  String get listPhotoLabel;

  /// No description provided for @prescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s prescription'**
  String get prescriptionLabel;

  /// No description provided for @deliveryTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get deliveryTimeTitle;

  /// No description provided for @sendListOrder.
  ///
  /// In en, this message translates to:
  /// **'Send order'**
  String get sendListOrder;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @noSlots.
  ///
  /// In en, this message translates to:
  /// **'No delivery times left. Try store pickup or order later.'**
  String get noSlots;

  /// No description provided for @slotFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get slotFull;

  /// No description provided for @deliverySlotLine.
  ///
  /// In en, this message translates to:
  /// **'Delivery: {day}, {time}'**
  String deliverySlotLine(String day, String time);

  /// No description provided for @yourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Your photos'**
  String get yourPhotos;

  /// No description provided for @customerPhotos.
  ///
  /// In en, this message translates to:
  /// **'Customer photos'**
  String get customerPhotos;

  /// No description provided for @awaitingPricing.
  ///
  /// In en, this message translates to:
  /// **'The shop is checking your list. The amount will appear here.'**
  String get awaitingPricing;

  /// No description provided for @listOrderBadge.
  ///
  /// In en, this message translates to:
  /// **'List order'**
  String get listOrderBadge;

  /// No description provided for @listOrderCta.
  ///
  /// In en, this message translates to:
  /// **'Send a photo of your list'**
  String get listOrderCta;

  /// No description provided for @listOrderCtaSub.
  ///
  /// In en, this message translates to:
  /// **'Write it on paper; the shop packs it and tells you the amount.'**
  String get listOrderCtaSub;

  /// No description provided for @requestReturn.
  ///
  /// In en, this message translates to:
  /// **'Return or exchange'**
  String get requestReturn;

  /// No description provided for @returnTypeReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnTypeReturn;

  /// No description provided for @returnTypeExchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get returnTypeExchange;

  /// No description provided for @returnReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get returnReasonLabel;

  /// No description provided for @returnItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get returnItemsTitle;

  /// No description provided for @returnPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos (optional)'**
  String get returnPhotosLabel;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get sendRequest;

  /// No description provided for @returnSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent. The shop will reply soon.'**
  String get returnSent;

  /// No description provided for @returnRequested.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the shop'**
  String get returnRequested;

  /// No description provided for @returnApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get returnApproved;

  /// No description provided for @returnRejected.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get returnRejected;

  /// No description provided for @returnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get returnCompleted;

  /// No description provided for @returnShopNote.
  ///
  /// In en, this message translates to:
  /// **'Shop: {note}'**
  String returnShopNote(String note);

  /// No description provided for @adminReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get adminReturns;

  /// No description provided for @adminReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Return and exchange requests'**
  String get adminReturnsSubtitle;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @markCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark completed'**
  String get markCompleted;

  /// No description provided for @returnNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Message for the customer'**
  String get returnNoteLabel;

  /// No description provided for @noReturns.
  ///
  /// In en, this message translates to:
  /// **'No requests.'**
  String get noReturns;

  /// No description provided for @returnsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get returnsOpen;

  /// No description provided for @returnsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get returnsAll;

  /// No description provided for @setAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Amount for this list'**
  String get setAmountTitle;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount in ₹ (with delivery)'**
  String get amountLabel;

  /// No description provided for @errorSlot.
  ///
  /// In en, this message translates to:
  /// **'That delivery time is no longer available. Pick another.'**
  String get errorSlot;

  /// No description provided for @errorListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of your list.'**
  String get errorListEmpty;

  /// No description provided for @errorPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount for this list.'**
  String get errorPriceRequired;

  /// No description provided for @errorReturnWindow.
  ///
  /// In en, this message translates to:
  /// **'The time to return this order is over.'**
  String get errorReturnWindow;

  /// No description provided for @errorReturnExists.
  ///
  /// In en, this message translates to:
  /// **'A request for this order was already sent.'**
  String get errorReturnExists;

  /// No description provided for @errorReturnItems.
  ///
  /// In en, this message translates to:
  /// **'Choose the items to return.'**
  String get errorReturnItems;

  /// No description provided for @errorReturnNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Returns are possible after delivery.'**
  String get errorReturnNotAllowed;

  /// No description provided for @errorReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please write a short reason.'**
  String get errorReasonRequired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
