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

  @override
  String get listOrderTitle => 'Order with a list photo';

  @override
  String get listOrderHint =>
      'The shop reads your list, packs it and tells you the amount before you pay.';

  @override
  String get listPhotoLabel => 'Photo of your list';

  @override
  String get prescriptionLabel => 'Doctor\'s prescription';

  @override
  String get deliveryTimeTitle => 'Delivery time';

  @override
  String get sendListOrder => 'Send order';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get noSlots =>
      'No delivery times left. Try store pickup or order later.';

  @override
  String get slotFull => 'Full';

  @override
  String deliverySlotLine(String day, String time) {
    return 'Delivery: $day, $time';
  }

  @override
  String get yourPhotos => 'Your photos';

  @override
  String get customerPhotos => 'Customer photos';

  @override
  String get awaitingPricing =>
      'The shop is checking your list. The amount will appear here.';

  @override
  String get listOrderBadge => 'List order';

  @override
  String get listOrderCta => 'Send a photo of your list';

  @override
  String get listOrderCtaSub =>
      'Write it on paper; the shop packs it and tells you the amount.';

  @override
  String get requestReturn => 'Return or exchange';

  @override
  String get returnTypeReturn => 'Return';

  @override
  String get returnTypeExchange => 'Exchange';

  @override
  String get returnReasonLabel => 'What went wrong?';

  @override
  String get returnItemsTitle => 'Items';

  @override
  String get returnPhotosLabel => 'Photos (optional)';

  @override
  String get sendRequest => 'Send request';

  @override
  String get returnSent => 'Request sent. The shop will reply soon.';

  @override
  String get returnRequested => 'Waiting for the shop';

  @override
  String get returnApproved => 'Approved';

  @override
  String get returnRejected => 'Declined';

  @override
  String get returnCompleted => 'Completed';

  @override
  String returnShopNote(String note) {
    return 'Shop: $note';
  }

  @override
  String get adminReturns => 'Returns';

  @override
  String get adminReturnsSubtitle => 'Return and exchange requests';

  @override
  String get approve => 'Approve';

  @override
  String get decline => 'Decline';

  @override
  String get markCompleted => 'Mark completed';

  @override
  String get returnNoteLabel => 'Message for the customer';

  @override
  String get noReturns => 'No requests.';

  @override
  String get returnsOpen => 'Open';

  @override
  String get returnsAll => 'All';

  @override
  String get setAmountTitle => 'Amount for this list';

  @override
  String get amountLabel => 'Amount in ₹ (with delivery)';

  @override
  String get errorSlot =>
      'That delivery time is no longer available. Pick another.';

  @override
  String get errorListEmpty => 'Add a photo of your list.';

  @override
  String get errorPriceRequired => 'Enter the amount for this list.';

  @override
  String get errorReturnWindow => 'The time to return this order is over.';

  @override
  String get errorReturnExists => 'A request for this order was already sent.';

  @override
  String get errorReturnItems => 'Choose the items to return.';

  @override
  String get errorReturnNotAllowed => 'Returns are possible after delivery.';

  @override
  String get errorReasonRequired => 'Please write a short reason.';

  @override
  String get adminSales => 'Sales';

  @override
  String get adminSalesSubtitle => 'Sales, best sellers and customers';

  @override
  String get periodYesterday => 'Yesterday';

  @override
  String get period7 => '7 days';

  @override
  String get period30 => '30 days';

  @override
  String get periodMonth => 'This month';

  @override
  String get statSales => 'Sales';

  @override
  String get statOrders => 'Orders';

  @override
  String get statAverage => 'Average order';

  @override
  String get statCancelled => 'Cancelled';

  @override
  String get dailySalesTitle => 'Sales by day';

  @override
  String get dayByDay => 'Day by day';

  @override
  String get tapBarHint => 'Tap a bar to see that day.';

  @override
  String get paymentsTitle => 'How customers paid';

  @override
  String markedPaidTotal(String amount) {
    return 'Marked paid: $amount';
  }

  @override
  String get fulfillmentTitle => 'Delivery and pickup';

  @override
  String get customersTitle => 'Customers';

  @override
  String newCustomers(int count) {
    return '$count new';
  }

  @override
  String returningCustomers(int count) {
    return '$count returning';
  }

  @override
  String get topProductsTitle => 'Best sellers';

  @override
  String get noTopProducts => 'No item sales in this period yet.';

  @override
  String ordersCount(int count) {
    return '$count orders';
  }

  @override
  String soldQty(int count) {
    return '$count sold';
  }

  @override
  String get salesNote =>
      'Sales = orders placed in the period that were not cancelled or rejected.';

  @override
  String get paymentOnline => 'Pay online (UPI, card, netbanking)';

  @override
  String get paymentOnlineShort => 'Online';

  @override
  String payOnline(String amount) {
    return 'Pay $amount online';
  }

  @override
  String get onlinePaymentNotDone =>
      'Payment was not completed. You can try again.';

  @override
  String get errorPaymentVerify =>
      'We could not confirm this payment. If money was taken, it will be confirmed shortly.';

  @override
  String get errorOnlineUnavailable =>
      'Online payment is not available right now. Try UPI or cash.';

  @override
  String otpSubtitleWhatsApp(String phone) {
    return 'Sent on WhatsApp to $phone';
  }

  @override
  String get adminSettings => 'Shop settings';

  @override
  String get adminSettingsSubtitle =>
      'Delivery, payments, timings, closing the shop';

  @override
  String get settingsSave => 'Save settings';

  @override
  String get settingsSaved => 'Settings saved. Customers see them now.';

  @override
  String get settingsFixFields => 'Please fix the highlighted fields';

  @override
  String get settingsAcceptingOrders => 'Taking orders';

  @override
  String get settingsOpenHint => 'Customers can place orders now';

  @override
  String get settingsPausedHint => 'Customers can browse but cannot order';

  @override
  String get settingsPausedMessage => 'Message for customers (optional)';

  @override
  String get settingsPausedMessageHint =>
      'e.g. Closed for Diwali, open again on 3 Nov';

  @override
  String get settingsTooLong => 'Too long';

  @override
  String get settingsPausedNotice =>
      'Your shop is not taking orders. Tap to open it again.';

  @override
  String get settingsDeliverySection => 'Delivery and pickup';

  @override
  String get settingsHomeDelivery => 'Home delivery';

  @override
  String get settingsDeliveryFee => 'Delivery fee';

  @override
  String get settingsMinOrder => 'Minimum order for delivery';

  @override
  String get settingsFreeAbove => 'Free delivery above';

  @override
  String get settingsFreeAboveHint => 'Leave empty to always charge the fee';

  @override
  String get settingsRadius => 'Delivery distance from shop';

  @override
  String get settingsEta => 'Usual delivery time';

  @override
  String get settingsMinutes => 'min';

  @override
  String get settingsPincodes => 'Delivery pincodes (optional)';

  @override
  String get settingsPincodesHint =>
      'Comma separated. Empty = any pincode within distance';

  @override
  String get settingsPickup => 'Customers can pick up at the shop';

  @override
  String get settingsPickupHint => 'No delivery fee or minimum for pickup';

  @override
  String get settingsSlotsSection => 'Delivery time slots';

  @override
  String get settingsSlots => 'Let customers choose a time';

  @override
  String get settingsSlotsHint => 'Same slots every day';

  @override
  String get settingsSlotAdd => 'Add time slot';

  @override
  String get settingsSlotRemove => 'Remove slot';

  @override
  String get settingsSlotStart => 'Slot starts at';

  @override
  String get settingsSlotEnd => 'Slot ends at';

  @override
  String get settingsSlotOrder => 'The end time must be after the start time';

  @override
  String get settingsSlotCapacity => 'Orders per slot';

  @override
  String get settingsPaymentsSection => 'Payments';

  @override
  String get settingsCod => 'Cash on delivery';

  @override
  String get settingsUpi => 'UPI to your account';

  @override
  String get settingsUpiHint =>
      'Customers pay from any UPI app; you confirm when the money arrives';

  @override
  String get settingsUpiId => 'Your UPI ID';

  @override
  String get settingsUpiName => 'Name shown when paying';

  @override
  String get settingsOnlineOn => 'Online payments (Razorpay) are on';

  @override
  String get settingsOnlineHint => 'Contact support to change them';

  @override
  String get settingsReturnsSection => 'Returns';

  @override
  String get settingsReturns => 'Accept return requests';

  @override
  String get settingsReturnDays => 'Customers can ask within';

  @override
  String get settingsDays => 'days';

  @override
  String get settingsExchange => 'Offer exchanges too';

  @override
  String get settingsExtrasSection => 'Order options';

  @override
  String get settingsOrderNotes => 'Customers can add a note to the order';

  @override
  String get settingsListUpload => 'Order by photo of a written list';

  @override
  String get settingsListUploadHint =>
      'You set the bill amount when you accept';

  @override
  String get settingsPrescription => 'Prescription photo upload';

  @override
  String get settingsContactSection => 'Shop contact';

  @override
  String get settingsShopPhone => 'Shop phone';

  @override
  String get settingsShopWhatsapp => 'WhatsApp number (optional)';

  @override
  String get settingsShopAddress => 'Shop address';

  @override
  String get settingsPlatformNote =>
      'Shop name, logo, colours and the app itself are managed by your app provider. Contact support to change them.';

  @override
  String get settingsInvalidAmount => 'Enter an amount like 20 or 20.50';

  @override
  String get settingsInvalidPincodes => 'Each pincode has 6 digits';

  @override
  String get settingsInvalidUpi => 'Enter a UPI ID like shopname@okaxis';

  @override
  String get settingsRequired => 'Required';

  @override
  String get settingsNeedDeliveryOrPickup =>
      'Turn on home delivery or pickup, otherwise customers cannot order';

  @override
  String get settingsNeedPayment => 'Turn on at least one way to pay';

  @override
  String get settingsNeedSlot =>
      'Add at least one time slot, or turn slots off';

  @override
  String get shopPausedTitle => 'The shop is not taking orders right now';

  @override
  String get shopPausedBody =>
      'You can still look at products. Please check again later.';

  @override
  String settingsNumberRange(int min, int max) {
    return 'Enter a number from $min to $max';
  }

  @override
  String get importTitle => 'Import from Excel';

  @override
  String get importHowTitle => 'Add many products at once';

  @override
  String get importStep1 =>
      'Get the template and open it in Excel or Google Sheets (on the phone or a computer).';

  @override
  String get importStep2 =>
      'Fill one row per size: category, name, size (like 1 kg), price, MRP, stock. Gujarati/Hindi names are optional.';

  @override
  String get importStep3 =>
      'Save it as Excel (.xlsx) or CSV and choose it here. We check every row before anything is saved.';

  @override
  String get importRules =>
      'Products already in your shop (same name) are updated, not added twice: new prices, stock and sizes. Empty stock = not counted (for new items) or unchanged (for existing ones).';

  @override
  String get importGetTemplate => 'Get the template';

  @override
  String get importTemplateShareText =>
      'Product list template. Fill it in and import it in the shop app.';

  @override
  String get importPickFile => 'Choose Excel or CSV file';

  @override
  String get importPickAnother => 'Choose another file';

  @override
  String importFile(String name) {
    return 'File: $name';
  }

  @override
  String get importWrongFile =>
      'Choose an Excel (.xlsx) or CSV file. Old .xls files: open in Excel and save as .xlsx.';

  @override
  String get importUnreadable =>
      'This file could not be read. Save it again as .xlsx or CSV and try once more.';

  @override
  String importColumnsMissing(String columns) {
    return 'These columns are missing in the first row: $columns. Use the template.';
  }

  @override
  String get importEmpty => 'The file has no products.';

  @override
  String get importTooLarge =>
      'At most 2000 rows per file. Split it into smaller files.';

  @override
  String get importFixRows => 'Some rows need fixing. See the list below.';

  @override
  String importReady(int rows) {
    return 'Ready to import $rows rows';
  }

  @override
  String get importNotReady => 'Fix these rows first';

  @override
  String importNewProducts(int products, int sizes) {
    return 'New products: $products ($sizes sizes)';
  }

  @override
  String importUpdatedProducts(int products, int sizes) {
    return 'Updated products: $products ($sizes sizes)';
  }

  @override
  String importNewCategories(String names) {
    return 'New categories: $names';
  }

  @override
  String importIgnoredColumns(String names) {
    return 'Not imported (unknown columns): $names';
  }

  @override
  String get importPhotosNote =>
      'Photos are not in the file: add them later from each product.';

  @override
  String importConfirm(int count) {
    return 'Import $count products';
  }

  @override
  String importDone(int added, int updated) {
    return 'Done: $added added, $updated updated';
  }

  @override
  String importErrorsTitle(int count) {
    return '$count problems';
  }

  @override
  String get importErrorsHint =>
      'Fix them in your file, save, and choose it again. Nothing has been saved yet.';

  @override
  String importRowLabel(int row) {
    return 'Row $row';
  }

  @override
  String importRowColumnLabel(int row, String column) {
    return 'Row $row · column $column';
  }

  @override
  String importMoreErrors(int count) {
    return '…and $count more';
  }

  @override
  String get importErrNameRequired => 'Product name is empty';

  @override
  String get importErrNameTooLong => 'Name is too long (max 120 letters)';

  @override
  String get importErrPrice => 'Price must be a number like 120 or 120.50';

  @override
  String get importErrMrp => 'MRP must be a number like 150';

  @override
  String get importErrMrpBelow => 'MRP is lower than the price';

  @override
  String get importErrStock => 'Stock must be a whole number (0 or more)';

  @override
  String get importErrSize => 'Size is empty (like 1 kg, 500 g, 1 pack)';

  @override
  String get importErrOption => 'Choose the option values (like size, colour)';

  @override
  String get importErrDuplicateRow => 'Same product and size appears twice';

  @override
  String get importErrDuplicateProduct => 'This product appears more than once';

  @override
  String get importErrTooManyVariants =>
      'Too many sizes for one product (max 50)';

  @override
  String get importErrField => 'This value is not allowed here';

  @override
  String get importErrFieldRequired => 'A required detail is missing';

  @override
  String get importErrOther => 'This row has a problem';

  @override
  String get quickAddShort => 'Quick add';

  @override
  String get quickAddTitle => 'Quick add';

  @override
  String get quickAddSaveNext => 'Save & add next';

  @override
  String get quickAddHint =>
      'Add products one after another. The category stays the same. Add other details later from the product list.';

  @override
  String quickAddSaved(String name) {
    return 'Added $name';
  }

  @override
  String quickAddCount(int count) {
    return 'Added now: $count';
  }

  @override
  String get quickAddStockHint => 'Empty = not counted';

  @override
  String get setupTitle => 'Get your shop ready';

  @override
  String get setupAllDone => 'Your shop is ready! 🎉';

  @override
  String get setupHide => 'Hide';

  @override
  String setupProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get setupGotIt => 'OK';

  @override
  String get setupCategories => 'Add categories';

  @override
  String get setupCategoriesHint =>
      'Like Rice & Grains, Oil, Snacks: customers browse by them';

  @override
  String get setupProducts => 'Add your products';

  @override
  String get setupProductsHint =>
      'Quick add one by one, or import an Excel list';

  @override
  String get setupPayments => 'Set your UPI ID';

  @override
  String get setupPaymentsHint => 'Customers pay straight to your account';

  @override
  String get setupSettings => 'Check delivery and timings';

  @override
  String get setupSettingsHint =>
      'Delivery fee, minimum order, area, time slots. Save once';

  @override
  String get setupRider => 'Add a delivery person';

  @override
  String get setupRiderHint =>
      'Add their mobile number: they log in and see deliveries';

  @override
  String get setupTestOrder => 'Place a test order';

  @override
  String get setupTestOrderHint =>
      'Try the whole order once before telling customers';

  @override
  String get setupTestOrderHow =>
      'Log out, log in with another mobile number (for example a family member\'s), order something and pay cash. Then log in again as the owner, open Orders and accept it. When it works, cancel it or deliver it.';

  @override
  String get supportTitle => 'Need help?';

  @override
  String get supportSubtitle => 'Chat with support on WhatsApp';

  @override
  String supportMessage(String shop) {
    return 'Hello, I need help with the $shop app.';
  }

  @override
  String supportNoWhatsapp(String number) {
    return 'WhatsApp is not installed. Message support at $number.';
  }

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get legalAgree => 'By continuing you agree to the';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your phone number, name and saved addresses will be removed and you will be logged out. Past orders stay with the shop for its accounts. This cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete';

  @override
  String get deleteAccountDone => 'Your account was deleted';

  @override
  String get errorAccountOpenOrders =>
      'You have an order on its way. You can delete your account after it is delivered or cancelled.';

  @override
  String get errorAccountDeleteTeam =>
      'Team accounts are removed by the shop owner, and the owner account through support.';

  @override
  String subscriptionDueTitle(String amount, String date) {
    return 'App subscription due: $amount since $date';
  }

  @override
  String subscriptionPayTo(String upi) {
    return 'Please pay by UPI to $upi.';
  }

  @override
  String get subscriptionPayNoUpi =>
      'Please pay to keep your app running. Message support if you need help.';

  @override
  String get subscriptionPausedTitle =>
      'Online orders are paused: subscription unpaid';

  @override
  String subscriptionPausedBody(String amount) {
    return 'Pay $amount to turn orders back on. Customers can still see your shop.';
  }

  @override
  String get subscriptionPayButton => 'Pay by UPI';

  @override
  String get shopSuspendedBody =>
      'This shop is not taking online orders right now. Please call the shop.';
}
