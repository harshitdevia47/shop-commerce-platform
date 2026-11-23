import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/config/client_config.dart';
import 'package:qc_app/core/config/shop_settings.dart';
import 'package:qc_app/core/utils/money.dart';

import '../fixtures.dart';

void main() {
  group('ClientConfig.fromMap', () {
    final valid = {
      'SHOP_KEY': 'style_hub',
      'APP_NAME': 'Style Hub',
      'LOGO_ASSET': 'assets/clients/style_hub/logo.png',
      'COLOR_PRIMARY': '#6A1B9A',
      'COLOR_SECONDARY': '#F06292',
      'COLOR_SURFACE': '',
      'DEFAULT_LOCALE': 'hi',
      'SUPPORTED_LOCALES': 'en,hi,gu',
    };

    test('parses generated defines', () {
      final config = ClientConfig.fromMap(valid);
      expect(config.shopKey, 'style_hub');
      expect(config.primaryColor, const Color(0xFF6A1B9A));
      expect(config.surfaceColor, isNull);
      expect(config.defaultLocale, const Locale('hi'));
      expect(config.supportedLocales, const [Locale('en'), Locale('hi'), Locale('gu')]);
    });

    test('fails clearly when built without a client file', () {
      expect(() => ClientConfig.fromMap({...valid, 'SHOP_KEY': ''}), throwsA(isA<StateError>()));
    });

    test('rejects a default locale that is not supported', () {
      expect(
        () => ClientConfig.fromMap({...valid, 'SUPPORTED_LOCALES': 'en'}),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects bad colours', () {
      expect(() => parseHexColor('green'), throwsFormatException);
    });
  });

  group('ShopSettings.fromJson', () {
    test('parses the tenant service response', () {
      final settings = ShopSettings.fromJson(shopConfigJson());
      expect(settings.slug, 'sharma_kirana');
      expect(settings.shop.localizedName(const Locale('gu')), 'શર્મા કરિયાણા');
      expect(settings.shop.localizedName(const Locale('en')), 'Sharma Kirana');
      expect(settings.delivery.freeAbovePaise, 50000);
      expect(settings.payments.upiVpa, 'sharmakirana@okaxis');
      expect(settings.catalog.variantStyle, 'units');
    });

    test('maps known feature flags and ignores unknown ones', () {
      final settings = ShopSettings.fromJson(shopConfigJson());
      expect(settings.isEnabled(Feature.deliverySlots), isTrue);
      expect(settings.isEnabled(Feature.returns), isFalse);
      expect(settings.features.length, Feature.values.length);
    });
  });

  group('formatPaise', () {
    test('formats whole rupees without decimals', () => expect(formatPaise(50000), '₹500'));
    test('formats paise with two decimals', () => expect(formatPaise(123456), '₹1,234.56'));
    test('uses Indian grouping', () => expect(formatPaise(1000000000), '₹1,00,00,000'));
  });
}
