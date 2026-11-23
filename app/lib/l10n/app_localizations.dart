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
  /// **'Delivery partner'**
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
  /// **'Orders, products and sales will appear here.'**
  String get adminComingSoon;

  /// No description provided for @riderTitle.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get riderTitle;

  /// No description provided for @riderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Deliveries assigned to you will appear here.'**
  String get riderComingSoon;

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
