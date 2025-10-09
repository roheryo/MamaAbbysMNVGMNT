import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../database_helper.dart';

// Prefer TFLite runtime if available; fall back to ONNX runtime already in project.
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'feature_builder.dart';

class DailyForecast {
  final DateTime date;
  final double predictedSales;
  DailyForecast(this.date, this.predictedSales);
}

class ForecastService {
  static final ForecastService _instance = ForecastService._internal();
  factory ForecastService() => _instance;
  ForecastService._internal();

  OrtSession? _session;
  List<String>? _featureNames;
  tfl.Interpreter? _tflInterpreter;
  bool _useTflite = false;
  List<double>? _scalerMean;
  List<double>? _scalerScale;

  Future<void> _ensureModelLoaded() async {
    if (_session != null || _tflInterpreter != null) return;
    // Try to load TFLite model first
    try {
      final modelData = await rootBundle.load('assets/models/sales_forecast.tflite');
      final bytes = modelData.buffer.asUint8List();
      // fromBuffer is synchronous factory; do not `await` it
      _tflInterpreter = tfl.Interpreter.fromBuffer(bytes);
      _useTflite = true;
      // Debug log
      // ignore: avoid_print
      print('[ForecastService] Loaded TFLite model from assets/models/sales_forecast.tflite');

      // Validate the TFLite input tensor shape. The exported regressor expects
      // a 2D input ([1, featureCount]). If the model has a different rank
      // (for example Conv2D expecting 4D), treat TFLite as incompatible and
      // fall back to ONNX to avoid runtime errors like "input->dims->size != 4".
      try {
        // allocateTensors may be required for the runtime to finalize shapes
        // on some platforms
        try {
          _tflInterpreter!.allocateTensors();
        } catch (eAlloc) {
          // ignore: avoid_print
          print('[ForecastService] Warning: allocateTensors() failed: $eAlloc');
        }

        final inShape = _tflInterpreter!.getInputTensor(0).shape;
        // ignore: avoid_print
        print('[ForecastService] TFLite input tensor shape: $inShape');
        if (inShape.length != 2) {
          // ignore: avoid_print
          print('[ForecastService] TFLite input shape unexpected: $inShape. Disabling TFLite and falling back to ONNX.');
          try {
            _tflInterpreter!.close();
          } catch (_) {}
          _tflInterpreter = null;
          _useTflite = false;
          // Attempt to load ONNX as fallback
          try {
            final ort = OnnxRuntime();
            _session = await ort.createSessionFromAsset('assets/models/sales_forecast.onnx');
            // ignore: avoid_print
            print('[ForecastService] Loaded ONNX model from assets/models/sales_forecast.onnx (fallback)');
          } catch (e2) {
            // ignore: avoid_print
            print('[ForecastService] Fallback ONNX load failed: $e2');
          }
        }
      } catch (eShape) {
        // If we can't inspect shape, keep TFLite but log the condition.
        // ignore: avoid_print
        print('[ForecastService] Failed to inspect TFLite input shape: $eShape');
      }
    } catch (e) {
      // Debug log TFLite failure
      // ignore: avoid_print
      print('[ForecastService] TFLite load failed: $e');
      // TFLite not available; fall back to ONNX runtime
      try {
        final ort = OnnxRuntime();
        _session = await ort.createSessionFromAsset('assets/models/sales_forecast.onnx');
      _useTflite = false;
      // Debug log
      // ignore: avoid_print
      print('[ForecastService] Loaded ONNX model from assets/models/sales_forecast.onnx');
      } catch (e2) {
        // Debug log ONNX failure
        // ignore: avoid_print
        print('[ForecastService] ONNX load failed: $e2');
        // No model loaded
        _session = null;
        _tflInterpreter = null;
        rethrow;
      }
    }

    // Load feature names (exported alongside model) if available
    try {
      final featuresJson = await rootBundle.loadString('assets/models/sales_forecast_features.json');
      if (featuresJson.isNotEmpty) {
        final parsed = jsonDecode(featuresJson) as List<dynamic>;
        _featureNames = parsed.map((e) => e.toString()).toList();
      // Debug log
      // ignore: avoid_print
      print('[ForecastService] Feature names loaded (${_featureNames!.length}): ${_featureNames!.take(6).toList()}...');
      }
    } catch (_) {
      // Optional; proceed without explicit names
    }

    // Load scaler params if exported. New schema expected: { available: bool, type: string, params: {...} }
    try {
      final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
      if (scalerJson.isNotEmpty) {
        final parsed = jsonDecode(scalerJson) as Map<String, dynamic>;

        // Log the parsed content for debugging
        // ignore: avoid_print
        print('[ForecastService] scaler_params.json parsed: available=${parsed['available']}, type=${parsed['type']}');

        final pType = (parsed['type'] ?? 'none').toString();

        if ((parsed['available'] ?? false) == true) {
          final params = parsed['params'] as Map<String, dynamic>?;
          if (pType == 'standard' && params != null) {
            // standard: expects { mean: [...], scale: [...] }
            final meanList = (params['mean'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            final scaleList = (params['scale'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            _scalerMean = meanList;
            _scalerScale = scaleList;
            // ignore: avoid_print
            print('[ForecastService] Loaded Standard scaler params (len=${_scalerMean!.length})');
          } else if (pType == 'minmax' && params != null) {
            // minmax: { min: [...], max: [...] } -> convert to scale and mean for (x - mean)/scale
            final minList = (params['min'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            final maxList = (params['max'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            // derive mean and scale
            final derivedMean = List<double>.generate(minList.length, (i) => (minList[i] + maxList[i]) / 2.0);
            final derivedScale = List<double>.generate(minList.length, (i) => (maxList[i] - minList[i]) / 2.0);
            _scalerMean = derivedMean;
            _scalerScale = derivedScale.map((s) => s == 0.0 ? 1.0 : s).toList();
            // ignore: avoid_print
            print('[ForecastService] Loaded MinMax scaler params (derived mean/scale)');
          } else if (pType == 'robust' && params != null) {
            // robust: { center: [...], scale: [...] }
            final centerList = (params['center'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            final scaleList = (params['scale'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
            _scalerMean = centerList;
            _scalerScale = scaleList.map((s) => s == 0.0 ? 1.0 : s).toList();
            // ignore: avoid_print
            print('[ForecastService] Loaded Robust scaler params (len=${_scalerMean!.length})');
          } else {
            // unknown or none -> log details
            // ignore: avoid_print
            print('[ForecastService] scaler_params.json available but type="$pType" not recognized or params missing.');
          }
        } else {
          // explicit not available
          // ignore: avoid_print
          print('[ForecastService] scaler_params.json indicates no scaler available (available=false)');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ForecastService] Failed to load/parse scaler_params.json: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStoreSalesAsc() async {
    final rows = await DatabaseHelper().fetchStoreSales();
    final sorted = [...rows];
    sorted.sort((a, b) => (a['sale_date'] as String).compareTo(b['sale_date'] as String));
    return sorted;
  }

  // weekday helper removed (unused)

  Map<String, double> _buildFeatureRow(
    DateTime date,
    double lastKnownSales,
    List<double> rolling7,
    List<double> rolling30,
  ) {
    return buildFeatureRow(date, lastKnownSales, rolling7, rolling30);
  }
  // Note: tests should import `lib/services/feature_builder.dart` directly to
  // avoid importing heavy native packages during unit tests.

  Future<List<DailyForecast>> forecastNext30Days() async {
    try {
      await _ensureModelLoaded();
    } catch (e) {
      // If model loading failed, log and return empty list
      // ignore: avoid_print
      print('[ForecastService] Model load failed in forecastNext30Days: $e');
      return [];
    }

    final rowsAsc = await _fetchStoreSalesAsc();
    // If there are no rows or neither runtime loaded, return empty
    if (rowsAsc.isEmpty) return [];
    if (_session == null && _tflInterpreter == null) {
      // ignore: avoid_print
      print('[ForecastService] No model available (both _session and _tflInterpreter are null)');
      return [];
    }

    // Build historical sales array
    List<DateTime> dates = [];
    List<double> sales = [];
    for (final r in rowsAsc) {
      final d = DateTime.parse(r['sale_date'].toString());
      final s = (r['sales'] as num?)?.toDouble() ?? 0.0;
      dates.add(d);
      sales.add(s);
    }

    // Initialize rolling windows
    List<double> rolling7 = sales.length >= 7 ? sales.sublist(sales.length - 7) : [...sales];
    List<double> rolling30 = sales.length >= 30 ? sales.sublist(sales.length - 30) : [...sales];
    double lastKnown = sales.isNotEmpty ? sales.last : 0.0;
    DateTime lastDate = dates.isNotEmpty ? dates.last : DateTime.now();

    final List<DailyForecast> result = [];
    final List<String> featureOrder = _featureNames ?? _defaultFeatureOrder();

    // Debug: log which runtime will be used
    // ignore: avoid_print
    print("[ForecastService] Forecast runtime: ${_useTflite ? 'TFLITE' : 'ONNX'}; features: ${featureOrder.length}");

    // Helper: extract first numeric value from nested lists or dynamic outputs
    double extractFirstNum(dynamic v) {
      try {
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        if (v is List && v.isNotEmpty) return extractFirstNum(v.first);
        if (v is Iterable && v.isNotEmpty) return extractFirstNum(v.first);
        return double.tryParse(v.toString()) ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }

    bool loggedSessionNullOnce = false;

    // The Python training/export pipeline exports a scikit-learn regressor
    // that expects a single-row feature vector of shape [1, feature_count].
    // To match `predict_ml_sales.py` predictions exactly, call the model per-day
    // with a single feature row built by `buildFeatureRow`, then update the
    // rolling windows with the predicted value (autoregressive features),
    // identical to the Python predictor.

    for (int i = 0; i < 30; i++) {
      final nextDate = lastDate.add(const Duration(days: 1));
      final feat = _buildFeatureRow(nextDate, lastKnown, rolling7, rolling30);
      // Ensure all exported feature names are present. Compute missing rolling
      // and lag features from available rolling7/rolling30 and sales history so
      // the mobile feature vector matches the Python export.
      // Compute simple helpers
      double mean(List<double> arr) => arr.isEmpty ? 0.0 : arr.reduce((a, b) => a + b) / arr.length;
      double std(List<double> arr) {
        if (arr.length <= 1) return 0.0;
        final m = mean(arr);
        final s = arr.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (arr.length - 1);
        return sqrt(s);
      }
      double median(List<double> arr) {
        if (arr.isEmpty) return 0.0;
        final copy = [...arr]..sort();
        final n = copy.length;
        if (n % 2 == 1) return copy[n ~/ 2];
        return (copy[n ~/ 2 - 1] + copy[n ~/ 2]) / 2.0;
      }

      // fill in missing lag features
      feat['sales_lag1'] = feat['sales_lag1'] ?? lastKnown;
      feat['sales_lag2'] = feat['sales_lag2'] ?? (rolling7.length >= 2 ? rolling7[rolling7.length - 2] : lastKnown);
      feat['sales_lag3'] = feat['sales_lag3'] ?? (rolling7.length >= 3 ? rolling7[rolling7.length - 3] : lastKnown);
      feat['sales_lag7'] = feat['sales_lag7'] ?? (rolling7.isNotEmpty ? rolling7.first : lastKnown);
      feat['sales_lag14'] = feat['sales_lag14'] ?? (rolling30.length >= 14 ? rolling30[rolling30.length - 14] : lastKnown);
      feat['sales_lag21'] = feat['sales_lag21'] ?? (rolling30.length >= 21 ? rolling30[rolling30.length - 21] : lastKnown);
      feat['sales_lag30'] = feat['sales_lag30'] ?? (rolling30.isNotEmpty ? rolling30.first : lastKnown);

      // small windows
      final last3 = sales.length >= 3 ? sales.sublist(sales.length - 3) : sales;
      feat['sales_ma3'] = feat['sales_ma3'] ?? mean(last3);
      feat['sales_std3'] = feat['sales_std3'] ?? std(last3);
      feat['sales_min3'] = feat['sales_min3'] ?? (last3.isEmpty ? 0.0 : last3.reduce(min));
      feat['sales_max3'] = feat['sales_max3'] ?? (last3.isEmpty ? 0.0 : last3.reduce(max));
      feat['sales_median3'] = feat['sales_median3'] ?? median(last3);

      // 7-day stats (use rolling7)
      feat['sales_ma7'] = feat['sales_ma7'] ?? mean(rolling7);
      feat['sales_std7'] = feat['sales_std7'] ?? std(rolling7);
      feat['sales_min7'] = feat['sales_min7'] ?? (rolling7.isEmpty ? 0.0 : rolling7.reduce(min));
      feat['sales_max7'] = feat['sales_max7'] ?? (rolling7.isEmpty ? 0.0 : rolling7.reduce(max));
      feat['sales_median7'] = feat['sales_median7'] ?? median(rolling7);

      // 14/21/30 stats from rolling30
      final last14 = rolling30.length >= 14 ? rolling30.sublist(rolling30.length - 14) : rolling30;
      feat['sales_ma14'] = feat['sales_ma14'] ?? mean(last14);
      feat['sales_std14'] = feat['sales_std14'] ?? std(last14);
      feat['sales_min14'] = feat['sales_min14'] ?? (last14.isEmpty ? 0.0 : last14.reduce(min));
      feat['sales_max14'] = feat['sales_max14'] ?? (last14.isEmpty ? 0.0 : last14.reduce(max));
      feat['sales_median14'] = feat['sales_median14'] ?? median(last14);

      final last21 = rolling30.length >= 21 ? rolling30.sublist(rolling30.length - 21) : rolling30;
      feat['sales_ma21'] = feat['sales_ma21'] ?? mean(last21);
      feat['sales_std21'] = feat['sales_std21'] ?? std(last21);
      feat['sales_min21'] = feat['sales_min21'] ?? (last21.isEmpty ? 0.0 : last21.reduce(min));
      feat['sales_max21'] = feat['sales_max21'] ?? (last21.isEmpty ? 0.0 : last21.reduce(max));
      feat['sales_median21'] = feat['sales_median21'] ?? median(last21);

      feat['sales_ma30'] = feat['sales_ma30'] ?? mean(rolling30);
      feat['sales_std30'] = feat['sales_std30'] ?? std(rolling30);
      feat['sales_min30'] = feat['sales_min30'] ?? (rolling30.isEmpty ? 0.0 : rolling30.reduce(min));
      feat['sales_max30'] = feat['sales_max30'] ?? (rolling30.isEmpty ? 0.0 : rolling30.reduce(max));
      feat['sales_median30'] = feat['sales_median30'] ?? median(rolling30);

      // Simple EMA approximations (alpha-based) using recent windows
      double ema(List<double> arr, int span) {
        if (arr.isEmpty) return 0.0;
        final alpha = 2.0 / (span + 1.0);
        double e = arr.first;
        for (int k = 1; k < arr.length; k++) {
          e = alpha * arr[k] + (1 - alpha) * e;
        }
        return e;
      }
      feat['sales_ema7'] = feat['sales_ema7'] ?? ema(rolling7, 7);
      feat['sales_ema14'] = feat['sales_ema14'] ?? ema(rolling30.length >= 14 ? rolling30.sublist(rolling30.length - 14) : rolling30, 14);
      feat['sales_ema30'] = feat['sales_ema30'] ?? ema(rolling30, 30);

      // Ratios and volatility
  // Local copies to satisfy null-safety and avoid repeated map lookups
  final double vSalesLag1 = (feat['sales_lag1'] ?? lastKnown).toDouble();
  final double vSalesMa7 = (feat['sales_ma7'] ?? 0.0).toDouble();
  final double vSalesMa30 = (feat['sales_ma30'] ?? 0.0).toDouble();
  final double vSalesStd7 = (feat['sales_std7'] ?? 0.0).toDouble();
  final double vSalesStd30 = (feat['sales_std30'] ?? 0.0).toDouble();

  feat['sales_to_ma7_ratio'] = feat['sales_to_ma7_ratio'] ?? (vSalesMa7 != 0.0 ? (vSalesLag1 / vSalesMa7) : 0.0);
  feat['sales_to_ma30_ratio'] = feat['sales_to_ma30_ratio'] ?? (vSalesMa30 != 0.0 ? (vSalesLag1 / vSalesMa30) : 0.0);
  feat['ma7_to_ma30_ratio'] = feat['ma7_to_ma30_ratio'] ?? (vSalesMa30 != 0.0 ? (vSalesMa7 / vSalesMa30) : 0.0);
  feat['sales_volatility_7'] = feat['sales_volatility_7'] ?? (vSalesMa7 != 0.0 ? (vSalesStd7 / vSalesMa7) : 0.0);
  feat['sales_volatility_30'] = feat['sales_volatility_30'] ?? (vSalesMa30 != 0.0 ? (vSalesStd30 / vSalesMa30) : 0.0);

  feat['sales_detrended'] = feat['sales_detrended'] ?? (vSalesLag1 - vSalesMa30);

      final List<double> nextFeatVector = featureOrder.map((name) => feat[name] ?? 0.0).toList().cast<double>();

      double pred = 0.0;
      // Apply scaler if available (standard scaler: (x - mean) / scale)
      List<double> inputVector = List<double>.from(nextFeatVector);
      if (_scalerMean != null && _scalerScale != null && _scalerMean!.length == inputVector.length && _scalerScale!.length == inputVector.length) {
        for (int k = 0; k < inputVector.length; k++) {
          final m = _scalerMean![k];
          final s = _scalerScale![k];
          inputVector[k] = s != 0.0 ? ((inputVector[k] - m) / s) : (inputVector[k] - m);
        }
      }

      if (_useTflite && _tflInterpreter != null) {
        // TFLite model exported from Python expects [1,featureCount]
        final shapedInput = [inputVector]; // batch of 1 (scaled if params present)
        final shapedOutput = List.generate(1, (_) => List.filled(1, 0.0));
        try {
          _tflInterpreter!.run(shapedInput, shapedOutput);
          pred = shapedOutput.first.first;
        } catch (e) {
          // ignore: avoid_print
          print('[ForecastService] TFLite run failed (single-row mode): $e');
          // If failure stems from variable/READ_VARIABLE ops (common when model contains uninitialized variables),
          // fall back to ONNX runtime at runtime to continue producing forecasts.
          final msg = e.toString();
          if (msg.contains('READ_VARIABLE') || msg.contains('variable') || msg.contains('failed precondition')) {
            // Try to switch to ONNX runtime if possible
            try {
              if (_session == null) {
                final ort = OnnxRuntime();
                _session = await ort.createSessionFromAsset('assets/models/sales_forecast.onnx');
                // ignore: avoid_print
                print('[ForecastService] Loaded ONNX model from assets/models/sales_forecast.onnx (runtime fallback)');
              }
              _useTflite = false;
              // Perform ONNX prediction for this input now
              final int featureCount = inputVector.length;
              final input = await OrtValue.fromList(Float32List.fromList(inputVector), [1, featureCount]);
              final outputs = await _session!.run({'input': input});
              dynamic rawOut;
              if (outputs.containsKey('output')) {
                rawOut = await outputs['output']!.asList();
              } else if (outputs.containsKey('variable')) {
                rawOut = await outputs['variable']!.asList();
              } else {
                final first = outputs.values.first;
                rawOut = await first.asList();
              }
              pred = extractFirstNum(rawOut);
            } catch (e2) {
              // ignore: avoid_print
              print('[ForecastService] Fallback ONNX predict also failed: $e2');
              pred = 0.0;
            }
          } else {
            pred = 0.0;
          }
        }
      } else {
        if (_session == null) {
          if (!loggedSessionNullOnce) {
            // ignore: avoid_print
            print('[ForecastService] ONNX session is null, skipping prediction');
            loggedSessionNullOnce = true;
          }
          pred = 0.0;
        } else {
          final int featureCount = inputVector.length;
          final input = await OrtValue.fromList(Float32List.fromList(inputVector), [1, featureCount]);
          final outputs = await _session!.run({'input': input});

          dynamic rawOut;
          if (outputs.containsKey('output')) {
            rawOut = await outputs['output']!.asList();
          } else if (outputs.containsKey('variable')) {
            rawOut = await outputs['variable']!.asList();
          } else {
            final first = outputs.values.first;
            rawOut = await first.asList();
          }

          pred = extractFirstNum(rawOut);
        }
      }

      // Sanity-check and stabilize prediction
      if (pred.isNaN || pred.isInfinite || pred < 0.0) pred = 0.0;
      double recentMean = 0.0;
      if (rolling30.isNotEmpty) {
        recentMean = rolling30.reduce((a, b) => a + b) / rolling30.length;
      } else if (sales.isNotEmpty) recentMean = sales.reduce((a, b) => a + b) / sales.length;
      else recentMean = lastKnown > 0.0 ? lastKnown : 1.0;
      final double histMax = sales.isNotEmpty ? sales.reduce(max) : lastKnown;
      double upperLimit = max(histMax * 3.0, recentMean * 5.0);
      if (upperLimit.isNaN || upperLimit <= 0.0) upperLimit = max(1.0, lastKnown * 3.0);
      pred = pred.clamp(0.0, upperLimit);
      pred = (pred * 0.7) + (recentMean * 0.3);

      result.add(DailyForecast(nextDate, pred));

      // Update autoregressive state exactly like the Python predictor
      lastKnown = pred;
      rolling7.add(pred);
      if (rolling7.length > 7) rolling7.removeAt(0);
      rolling30.add(pred);
      if (rolling30.length > 30) rolling30.removeAt(0);
      lastDate = nextDate;
    }

    return result;
  }

  List<String> _defaultFeatureOrder() {
    return [
      'year','month','day','quarter','weekday','week_of_year','day_of_year','is_weekend','is_month_start','is_month_end','is_quarter_start','is_quarter_end','day_of_week_encoded','month_sin','month_cos','day_sin','day_cos','weekday_sin','weekday_cos','quarter_sin','quarter_cos','week_sin','week_cos','sales_lag1','sales_ma7','sales_ma14','sales_ma21','sales_ma30','sales_std7','sales_std30','month_squared','weekday_squared','day_squared','sales_to_ma7_ratio','sales_to_ma30_ratio','ma7_to_ma30_ratio','sales_volatility_7','sales_volatility_30','sales_detrended'
    ];
  }
}


