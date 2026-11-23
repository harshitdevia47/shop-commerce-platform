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
  String get roleRider => 'Rider';

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

  @override
  String get addToCart => 'ADD';

  @override
  String get cartTitle => 'Cart';

  @override
  String get viewCart => 'View cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get startShopping => 'Browse products';

  @override
  String get billDetails => 'Bill details';

  @override
  String get itemTotal => 'Item total';

  @override
  String get deliveryFeeLabel => 'Delivery fee';

  @override
  String get free => 'FREE';

  @override
  String get toPay => 'To pay';

  @override
  String get lineUnavailable => 'No longer available';

  @override
  String get proceed => 'Proceed';

  @override
  String get loginToOrder => 'Log in to place your order';

  @override
  String get deliveryOption => 'Delivery';

  @override
  String get pickupOption => 'Store pickup';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String get pickupFrom => 'Pick up from';

  @override
  String get addAddress => 'Add address';

  @override
  String get noAddresses => 'Add a delivery address to continue';

  @override
  String get addressLine1 => 'House / flat, street';

  @override
  String get addressLine2 => 'Area (optional)';

  @override
  String get landmarkLabel => 'Landmark (optional)';

  @override
  String get cityLabel => 'City';

  @override
  String get pincodeLabel => 'Pincode';

  @override
  String get invalidPincode => 'Enter a 6-digit pincode';

  @override
  String get addressHome => 'Home';

  @override
  String get addressWork => 'Work';

  @override
  String get addressOther => 'Other';

  @override
  String get paymentMethodTitle => 'Payment';

  @override
  String get noteLabel => 'Note for the shop (optional)';

  @override
  String get ordersTitle => 'My orders';

  @override
  String get noOrders => 'No orders yet';

  @override
  String get orderPlacedTitle => 'Order placed!';

  @override
  String get statusPlaced => 'Placed';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusPacked => 'Packed';

  @override
  String get statusOutForDelivery => 'Out for delivery';

  @override
  String get statusReadyForPickup => 'Ready for pickup';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusPickedUp => 'Picked up';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusRejected => 'Rejected by shop';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get cancelOrderConfirm => 'Cancel this order?';

  @override
  String get keepOrder => 'Keep order';

  @override
  String get utrPrompt =>
      'Paid? Enter the 12-digit UTR from your UPI app so the shop can confirm.';

  @override
  String get utrLabel => 'UTR number';

  @override
  String get submit => 'Submit';

  @override
  String get utrInvalid => 'UTR is 12 digits';

  @override
  String get paymentPending => 'Payment pending';

  @override
  String get paymentSubmitted => 'Payment being verified';

  @override
  String get paymentPaid => 'Paid';

  @override
  String get paymentVoid => 'Not charged';

  @override
  String get callShop => 'Call shop';

  @override
  String get noUpiApp => 'No UPI app found on this phone';

  @override
  String get adminOrders => 'Orders';

  @override
  String get adminOrdersSubtitle => 'New, in progress and completed orders';

  @override
  String get tabNew => 'New';

  @override
  String get tabActive => 'In progress';

  @override
  String get tabDone => 'Completed';

  @override
  String get noOrdersHere => 'No orders here';

  @override
  String get callCustomer => 'Call customer';

  @override
  String get markPaid => 'Mark as paid';

  @override
  String get rejectOrder => 'Reject';

  @override
  String get rejectReason => 'Reason (shown to the customer)';

  @override
  String get actionConfirm => 'Accept order';

  @override
  String get actionPack => 'Mark packed';

  @override
  String get actionOutForDelivery => 'Send for delivery';

  @override
  String get actionReadyForPickup => 'Ready for pickup';

  @override
  String get actionDelivered => 'Mark delivered';

  @override
  String get actionPickedUp => 'Customer picked up';

  @override
  String get customerNote => 'Customer note';

  @override
  String get errorCartChanged => 'Some items changed. Please review your cart.';

  @override
  String get errorOutOfStock => 'Some items just ran out.';

  @override
  String get errorBelowMinimum => 'Your order is below the minimum amount.';

  @override
  String get errorOutsideArea => 'The shop does not deliver to this address.';

  @override
  String get errorAddressRequired => 'Choose a delivery address.';

  @override
  String get errorOptionUnavailable =>
      'This option is not available at this shop.';

  @override
  String get errorNotCancellable =>
      'This order can no longer be cancelled. Please call the shop.';

  @override
  String get errorOrderChanged => 'Someone else updated this order. Refreshed.';

  @override
  String get errorPaymentClosed => 'This payment can no longer be changed.';

  @override
  String get errorAddressLimit =>
      'You have too many addresses. Delete one first.';

  @override
  String cartItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String youSave(String amount) {
    return 'You save $amount';
  }

  @override
  String freeDeliveryGap(String amount) {
    return 'Add $amount more for free delivery';
  }

  @override
  String minOrderGap(String amount, String minimum) {
    return 'Add $amount more to order (minimum $minimum)';
  }

  @override
  String lineOnlyLeft(int count) {
    return 'Only $count left';
  }

  @override
  String setQtyTo(int count) {
    return 'Change to $count';
  }

  @override
  String placeOrder(String amount) {
    return 'Place order · $amount';
  }

  @override
  String orderNumber(int number) {
    return 'Order #$number';
  }

  @override
  String payWithUpi(String amount) {
    return 'Pay $amount with UPI';
  }

  @override
  String payOnDelivery(String amount) {
    return 'Pay $amount in cash on delivery';
  }

  @override
  String utrShown(String utr) {
    return 'UTR $utr';
  }

  @override
  String rejectedBecause(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get notificationChannelOrders => 'Order updates';

  @override
  String get deliveryPartner => 'Your delivery partner';

  @override
  String get deliveryOtpLabel => 'Delivery code';

  @override
  String get deliveryOtpHint =>
      'Tell this code to the rider when your order arrives.';

  @override
  String deliveryRiderDistance(String km, int minutes) {
    return '$km km away · about $minutes min';
  }

  @override
  String get deliveryRiderOnTheWay => 'On the way to you';

  @override
  String get deliveryTrackOnMap => 'Track on map';

  @override
  String get callRider => 'Call rider';

  @override
  String get deliverySection => 'Delivery';

  @override
  String get assignRider => 'Assign rider';

  @override
  String get changeRider => 'Change rider';

  @override
  String get chooseRider => 'Choose a rider';

  @override
  String get noRiders => 'No riders yet. Add them in Team.';

  @override
  String riderActiveCount(int count) {
    return '$count active';
  }

  @override
  String get noRiderYet => 'No rider assigned yet';

  @override
  String get deliveryAssigned => 'Rider assigned';

  @override
  String get deliveryPickedUp => 'On the way';

  @override
  String get deliveryDelivered => 'Delivered';

  @override
  String get deliveryCancelled => 'Cancelled';

  @override
  String get adminTeam => 'Team';

  @override
  String get adminTeamSubtitle => 'Riders and staff';

  @override
  String get teamAdd => 'Add person';

  @override
  String get teamEmpty => 'No riders or staff yet.';

  @override
  String get teamAdded => 'Added. They log in with this number.';

  @override
  String get teamRemove => 'Remove';

  @override
  String teamRemoveConfirm(String name) {
    return 'Remove $name from the team? They become a normal customer.';
  }

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get riderActive => 'Active';

  @override
  String get riderDone => 'Done';

  @override
  String get riderNoActive => 'No deliveries right now.';

  @override
  String get riderNoDone => 'Nothing delivered yet.';

  @override
  String riderCollectCash(String amount) {
    return 'Collect $amount in cash';
  }

  @override
  String get riderPrepaid => 'Paid online · nothing to collect';

  @override
  String riderItems(int count) {
    return '$count items';
  }

  @override
  String get riderPickUp => 'Picked up from shop';

  @override
  String get riderDeliver => 'Delivered · enter code';

  @override
  String get riderEnterOtp => 'Ask the customer for the 4-digit code';

  @override
  String get riderConfirm => 'Confirm';

  @override
  String get riderNavigate => 'Navigate';

  @override
  String riderNote(String note) {
    return 'Note: $note';
  }

  @override
  String get riderSharingTitle => 'Sharing your location';

  @override
  String get riderSharingText => 'The customer can see you are on the way.';

  @override
  String get riderNeedsPermission =>
      'Allow location so the customer can track you';

  @override
  String get riderGpsOff => 'Turn on GPS so the customer can track you';

  @override
  String get riderCancelledReturn => 'Cancelled · return it to the shop';

  @override
  String get errorOrderNotPacked => 'The shop has not packed this order yet.';

  @override
  String errorDeliveryOtp(int attempts) {
    return 'Wrong code. $attempts attempts left.';
  }

  @override
  String get errorDeliveryOtpLocked =>
      'Too many wrong codes. Ask the shop to mark it delivered.';

  @override
  String get errorDeliveryNotAssignable =>
      'Assign a rider after accepting the order and before it leaves the shop.';

  @override
  String get errorDeliveryStarted =>
      'The rider has already picked this order up.';

  @override
  String get errorDeliveryClosed => 'This delivery is no longer active.';

  @override
  String get errorOwnerLocked => 'The owner\'s role can\'t be changed.';
}
