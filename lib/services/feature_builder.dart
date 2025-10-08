import 'dart:math';
// Avoid intl DateFormat for week/day-of-year to keep unit tests deterministic

Map<String, double> buildFeatureRow(
  DateTime date,
  double lastKnownSales,
  List<double> rolling7,
  List<double> rolling30,
) {
  final month = date.month;
  final day = date.day;
  final quarter = ((date.month - 1) ~/ 3) + 1;
  final weekday = date.weekday - 1; // 0..6 Monday..Sunday
  int _dayOfYear(DateTime d) => d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  // ISO week number (1..53). This computes a simple week-of-year where week starts Monday.
  int _weekOfYear(DateTime d) {
    final jan1 = DateTime(d.year, 1, 1);
    final days = d.difference(jan1).inDays;
    return (days / 7).floor() + 1;
  }

  final isoWeek = _weekOfYear(date);
  final dayOfYear = _dayOfYear(date);
  final isWeekend = weekday >= 5 ? 1 : 0;
  final isMonthStart = day == 1 ? 1 : 0;
  final nextDay = date.add(const Duration(days: 1));
  final isMonthEnd = nextDay.month != date.month ? 1 : 0;
  final isQuarterStart = ([1, 4, 7, 10].contains(month) && day == 1) ? 1 : 0;
  final isQuarterEnd = ([3, 6, 9, 12].contains(month) && (day == 30 || day == 31)) ? 1 : 0;

  double mean7 = rolling7.isEmpty ? lastKnownSales : rolling7.reduce((a, b) => a + b) / rolling7.length;
  double mean14 = rolling30.length >= 14 ? rolling30.sublist(rolling30.length - 14).reduce((a, b) => a + b) / 14.0 : mean7;
  double mean21 = rolling30.length >= 21 ? rolling30.sublist(rolling30.length - 21).reduce((a, b) => a + b) / 21.0 : mean7;
  double mean30 = rolling30.isEmpty ? lastKnownSales : rolling30.reduce((a, b) => a + b) / rolling30.length;

  double std7 = 0.0;
  if (rolling7.length > 1) {
    final m = mean7;
    std7 = sqrt(rolling7.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (rolling7.length - 1));
  }
  double std30 = 0.0;
  if (rolling30.length > 1) {
    final m = mean30;
    std30 = sqrt(rolling30.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (rolling30.length - 1));
  }

  final Map<String, double> f = {
    'year': date.year.toDouble(),
    'month': month.toDouble(),
    'day': day.toDouble(),
    'quarter': quarter.toDouble(),
    'weekday': weekday.toDouble(),
    'week_of_year': isoWeek.toDouble(),
    'day_of_year': dayOfYear.toDouble(),
    'is_weekend': isWeekend.toDouble(),
    'is_month_start': isMonthStart.toDouble(),
    'is_month_end': isMonthEnd.toDouble(),
    'is_quarter_start': isQuarterStart.toDouble(),
    'is_quarter_end': isQuarterEnd.toDouble(),
    'day_of_week_encoded': weekday.toDouble(),
    'month_sin': sin(2 * pi * month / 12),
    'month_cos': cos(2 * pi * month / 12),
    'day_sin': sin(2 * pi * day / 31),
    'day_cos': cos(2 * pi * day / 31),
    'weekday_sin': sin(2 * pi * weekday / 7),
    'weekday_cos': cos(2 * pi * weekday / 7),
    'quarter_sin': sin(2 * pi * quarter / 4),
    'quarter_cos': cos(2 * pi * quarter / 4),
    'week_sin': sin(2 * pi * isoWeek / 52),
    'week_cos': cos(2 * pi * isoWeek / 52),
    'sales_lag1': lastKnownSales,
    'sales_ma7': mean7,
    'sales_ma14': mean14,
    'sales_ma21': mean21,
    'sales_ma30': mean30,
    'sales_std7': std7,
    'sales_std30': std30,
    'month_squared': month * month.toDouble(),
    'weekday_squared': weekday * weekday.toDouble(),
    'day_squared': day * day.toDouble(),
    'sales_to_ma7_ratio': mean7 != 0 ? lastKnownSales / mean7 : 0.0,
    'sales_to_ma30_ratio': mean30 != 0 ? lastKnownSales / mean30 : 0.0,
    'ma7_to_ma30_ratio': mean30 != 0 ? mean7 / mean30 : 0.0,
    'sales_volatility_7': mean7 != 0 ? std7 / mean7 : 0.0,
    'sales_volatility_30': mean30 != 0 ? std30 / mean30 : 0.0,
    'sales_detrended': lastKnownSales - mean30,
  };
  return f;
}
