import 'package:flutter_test/flutter_test.dart';
import 'package:qc_app/core/utils/money.dart';
import 'package:qc_app/features/catalog/domain/catalog_models.dart';

void main() {
  test('parseRupees reads what shop owners type', () {
    expect(parseRupees('120'), 12000);
    expect(parseRupees('120.5'), 12050);
    expect(parseRupees('120.05'), 12005);
    expect(parseRupees(' 1,200.50 '), 120050);
    expect(parseRupees('0'), 0);
    for (final bad in ['', 'abc', '1.234', '-5', '12.3.4', '99999999']) {
      expect(parseRupees(bad), isNull, reason: bad);
    }
  });

  test('paiseToInput round-trips', () {
    for (final paise in [0, 5, 12000, 12050, 120005]) {
      expect(parseRupees(paiseToInput(paise)), paise);
    }
    expect(paiseToInput(12000), '120');
  });

  test('discount is floored and absent without a higher MRP', () {
    Variant v(int price, int? mrp) => Variant(id: 'v', label: '', pricePaise: price, mrpPaise: mrp, inStock: true);
    expect(v(12000, 14000).discountPercent, 14);
    expect(v(100, 100).discountPercent, isNull);
    expect(v(100, null).discountPercent, isNull);
    expect(v(9950, 10000).discountPercent, isNull); // 0.5% rounds down to nothing
  });
}
