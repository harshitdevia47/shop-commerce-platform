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
  String get adminComingSoon => 'Orders, products and sales will appear here.';

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
}
