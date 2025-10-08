import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_applicationtest/services/feature_builder.dart';

void main() {
  test('buildFeatureRowForTest returns expected keys and numeric values', () {
  final date = DateTime(2025, 10, 7);
    // provide some synthetic history
    final lastKnown = 100.0;
    final rolling7 = [90.0, 95.0, 100.0, 105.0, 110.0, 100.0, 98.0];
    final rolling30 = List<double>.generate(30, (i) => 80.0 + i.toDouble());

  final features = buildFeatureRow(date, lastKnown, rolling7, rolling30);

    // Basic checks
    expect(features, isNotEmpty);
    expect(features.containsKey('sales_lag1'), isTrue);
    expect(features['sales_lag1'], equals(lastKnown));
    expect(features['sales_ma7'], isA<double>());
    expect(features['sales_ma30'], isA<double>());
    expect(features['is_weekend'], anyOf(equals(0.0), equals(1.0)));
  });
}
