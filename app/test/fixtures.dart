import 'package:material_ui/material_ui.dart';
import 'package:qc_app/core/config/client_config.dart';

const testClient = ClientConfig(
  shopKey: 'sharma_kirana',
  appName: 'Sharma Kirana',
  logoAsset: 'assets/missing-in-tests.png',
  primaryColor: Color(0xFF1B5E20),
  secondaryColor: Color(0xFFFFB300),
  defaultLocale: Locale('en'),
  supportedLocales: [Locale('en'), Locale('gu'), Locale('hi')],
);

/// Shape returned by GET /api/v1/shop/config (captured from the tenant service).
Map<String, dynamic> shopConfigJson({bool deliveryEnabled = true, bool upi = true}) => {
  'id': '01a206e8-75c7-71d8-b22b-d3223bce1039',
  'slug': 'sharma_kirana',
  'shop': {
    'name': 'Sharma Kirana',
    'nameI18n': {'gu': 'શર્મા કરિયાણા', 'hi': 'शर्मा किराना'},
    'businessType': 'grocery',
    'currency': 'INR',
    'timezone': 'Asia/Kolkata',
    'contact': {
      'phone': '+919876543210',
      'whatsapp': '+919876543210',
      'address': 'Station Road, Bhavnagar, Gujarat 364001',
      'lat': 21.7645,
      'lng': 72.1519,
    },
  },
  'delivery': {
    'enabled': deliveryEnabled,
    'radiusKm': 5,
    'pincodes': ['364001'],
    'minOrderPaise': 10000,
    'feePaise': 2000,
    'freeAbovePaise': 50000,
    'etaMinutes': 45,
  },
  'payments': {
    'cod': true,
    'upi': {'enabled': upi, 'vpa': 'sharmakirana@okaxis', 'payeeName': 'Sharma Kirana'},
    'razorpay': {'enabled': false},
  },
  'features': {
    'deliverySlots': true,
    'storePickup': true,
    'returns': false,
    'prescriptionUpload': false,
    'orderNotes': true,
    'handwrittenListUpload': true,
    'someFutureFlag': true,
  },
  'catalog': {'variantStyle': 'units', 'variantAxes': <String>[], 'customFields': <Map<String, dynamic>>[]},
};
