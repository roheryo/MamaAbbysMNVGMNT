import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_applicationtest/services/feature_builder.dart';

void main() {
  test('empty history uses lastKnown for means and zeros', () {
    final date = DateTime(2025, 1, 1);
    final lastKnown = 50.0;
    final rolling7 = <double>[];
    final rolling30 = <double>[];

    final f = buildFeatureRow(date, lastKnown, rolling7, rolling30);
    expect(f['sales_lag1'], equals(lastKnown));
    expect(f['sales_ma7'], equals(lastKnown));
    expect(f['sales_ma30'], equals(lastKnown));
    expect(f['sales_volatility_7'], equals(0.0));
  });

  test('single-element history computes mean correctly', () {
    final date = DateTime(2025, 6, 15);
    final lastKnown = 120.0;
    final rolling7 = [120.0];
    final rolling30 = [100.0];

    final f = buildFeatureRow(date, lastKnown, rolling7, rolling30);
    expect(f['sales_ma7'], closeTo(120.0, 1e-9));
    expect(f['sales_ma30'], closeTo(100.0, 1e-9));
    expect(f['sales_detrended'], closeTo(lastKnown - 100.0, 1e-9));
  });

  test('month and quarter boundary flags', () {
    final date = DateTime(2025, 4, 1); // April 1 -> month start and quarter start
    final f = buildFeatureRow(date, 10.0, [1,2,3], [1,2,3,4]);
    expect(f['is_month_start'], equals(1.0));
    expect(f['is_quarter_start'], equals(1.0));
  });

  test('ratios handle zero means without throwing', () {
    final date = DateTime(2025, 7, 10);
    final lastKnown = 0.0;
    final rolling7 = [0.0, 0.0, 0.0];
    final rolling30 = [0.0, 0.0, 0.0];

    final f = buildFeatureRow(date, lastKnown, rolling7, rolling30);
    expect(f['sales_to_ma7_ratio'], equals(0.0));
    expect(f['ma7_to_ma30_ratio'], equals(0.0));
  });
}
