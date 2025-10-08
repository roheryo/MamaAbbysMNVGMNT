"""
Export store_sales forecasting model to TensorFlow SavedModel and TFLite.

Usage:
  python export_model_to_tflite.py --db-path ".dart_tool/sqflite_common_ffi/databases/app.db" --out-dir assets/models

This script reads the `store_sales` table from the provided SQLite DB, constructs features
compatible with the Flutter `ForecastService` feature builder, trains a small Keras model
to predict next-day sales (target is next day's sales), and exports a SavedModel and
TFLite file together with a JSON file listing the feature order.

Note: For reproducible and performant results you may want to tune model architecture,
scaling, and training hyperparameters.
"""
import argparse
import sqlite3
import pandas as pd
import numpy as np
import json
import os
from datetime import datetime

try:
    import tensorflow as tf
except Exception as e:
    raise RuntimeError("TensorFlow is required to run this script. Install with: pip install tensorflow")


def build_feature_row(date: pd.Timestamp, last_known: float, rolling7: list, rolling30: list):
    month = date.month
    day = date.day
    quarter = ((date.month - 1) // 3) + 1
    weekday = date.weekday()  # Monday=0
    iso_week = int(date.isocalendar().week)
    day_of_year = int(date.dayofyear)
    is_weekend = 1 if weekday >= 5 else 0
    is_month_start = 1 if date.is_month_start else 0
    next_day = date + pd.Timedelta(days=1)
    is_month_end = 1 if next_day.month != date.month else 0
    is_quarter_start = 1 if (month in [1,4,7,10] and day == 1) else 0
    is_quarter_end = 1 if (month in [3,6,9,12] and (day in [30,31])) else 0

    mean7 = np.mean(rolling7) if len(rolling7) > 0 else last_known
    mean30 = np.mean(rolling30) if len(rolling30) > 0 else last_known
    mean14 = np.mean(rolling30[-14:]) if len(rolling30) >= 14 else mean7
    mean21 = np.mean(rolling30[-21:]) if len(rolling30) >= 21 else mean7

    std7 = float(np.std(rolling7, ddof=1)) if len(rolling7) > 1 else 0.0
    std30 = float(np.std(rolling30, ddof=1)) if len(rolling30) > 1 else 0.0

    feat = {
        'year': float(date.year),
        'month': float(month),
        'day': float(day),
        'quarter': float(quarter),
        'weekday': float(weekday),
        'week_of_year': float(iso_week),
        'day_of_year': float(day_of_year),
        'is_weekend': float(is_weekend),
        'is_month_start': float(is_month_start),
        'is_month_end': float(is_month_end),
        'is_quarter_start': float(is_quarter_start),
        'is_quarter_end': float(is_quarter_end),
        'day_of_week_encoded': float(weekday),
        'month_sin': float(np.sin(2 * np.pi * month / 12)),
        'month_cos': float(np.cos(2 * np.pi * month / 12)),
        'day_sin': float(np.sin(2 * np.pi * day / 31)),
        'day_cos': float(np.cos(2 * np.pi * day / 31)),
        'weekday_sin': float(np.sin(2 * np.pi * weekday / 7)),
        'weekday_cos': float(np.cos(2 * np.pi * weekday / 7)),
        'quarter_sin': float(np.sin(2 * np.pi * quarter / 4)),
        'quarter_cos': float(np.cos(2 * np.pi * quarter / 4)),
        'week_sin': float(np.sin(2 * np.pi * iso_week / 52)),
        'week_cos': float(np.cos(2 * np.pi * iso_week / 52)),
        'sales_lag1': float(last_known),
        'sales_ma7': float(mean7),
        'sales_ma14': float(mean14),
        'sales_ma21': float(mean21),
        'sales_ma30': float(mean30),
        'sales_std7': float(std7),
        'sales_std30': float(std30),
        'month_squared': float(month * month),
        'weekday_squared': float(weekday * weekday),
        'day_squared': float(day * day),
        'sales_to_ma7_ratio': float(last_known / (mean7 + 1e-8)),
        'sales_to_ma30_ratio': float(last_known / (mean30 + 1e-8)),
        'ma7_to_ma30_ratio': float(mean7 / (mean30 + 1e-8)),
        'sales_volatility_7': float(std7 / (mean7 + 1e-8)),
        'sales_volatility_30': float(std30 / (mean30 + 1e-8)),
        'sales_detrended': float(last_known - mean30),
    }
    return feat


def main(db_path: str, out_dir: str, epochs: int = 50):
    if not os.path.exists(db_path):
        raise FileNotFoundError(f"Database not found: {db_path}")

    conn = sqlite3.connect(db_path)
    df = pd.read_sql_query('SELECT * FROM store_sales', conn)
    conn.close()

    # Expect at least sale_date and sales
    if 'sale_date' not in df.columns or 'sales' not in df.columns:
        raise ValueError("store_sales table must contain 'sale_date' and 'sales' columns")

    df['sale_date'] = pd.to_datetime(df['sale_date'])
    df = df.sort_values('sale_date').reset_index(drop=True)

    dates = list(df['sale_date'])
    sales = list(df['sales'].astype(float))

    # Build dataset: for each date t, build features for t and target is sales at t+1
    X = []
    y = []

    for i in range(len(dates) - 1):
        date = pd.Timestamp(dates[i])
        last_known = float(sales[i])
        rolling7 = sales[max(0, i - 6):i + 1]
        rolling30 = sales[max(0, i - 29):i + 1]
        feat = build_feature_row(date, last_known, rolling7, rolling30)
        X.append([feat[k] for k in sorted(feat.keys(), key=lambda s: FEATURE_ORDER.index(s))])
        y.append(float(sales[i + 1]))

    X = np.array(X, dtype=np.float32)
    y = np.array(y, dtype=np.float32).reshape(-1, 1)

    input_dim = X.shape[1]
    print(f"Training dataset shape: X={X.shape}, y={y.shape}")

    # Simple Keras model
    tf.keras.backend.clear_session()
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_dim,)),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(1)
    ])
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001), loss='mse')

    es = tf.keras.callbacks.EarlyStopping(monitor='loss', patience=5, restore_best_weights=True)
    model.fit(X, y, epochs=epochs, batch_size=32, callbacks=[es], verbose=2)

    # Evaluate on training data (small sanity check)
    preds = model.predict(X)
    rmse = float(np.sqrt(np.mean((preds.reshape(-1) - y.reshape(-1)) ** 2)))
    print(f"Training RMSE: {rmse:.4f}")

    os.makedirs(out_dir, exist_ok=True)

    # Save SavedModel
    saved_model_dir = os.path.join(out_dir, 'sales_forecast_saved')
    model.save(saved_model_dir, include_optimizer=False)
    print(f"SavedModel exported to: {saved_model_dir}")

    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    try:
        tflite_model = converter.convert()
    except Exception:
        # Fallback to non-optimized conversion
        converter.optimizations = []
        tflite_model = converter.convert()

    tflite_path = os.path.join(out_dir, 'sales_forecast.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f"TFLite model written to: {tflite_path}")

    # Save feature order file
    features_path = os.path.join(out_dir, 'sales_forecast_features.json')
    with open(features_path, 'w', encoding='utf-8') as fh:
        json.dump(FEATURE_ORDER, fh, indent=2)
    print(f"Feature order written to: {features_path}")


FEATURE_ORDER = [
    'year','month','day','quarter','weekday','week_of_year','day_of_year','is_weekend','is_month_start','is_month_end','is_quarter_start','is_quarter_end','day_of_week_encoded','month_sin','month_cos','day_sin','day_cos','weekday_sin','weekday_cos','quarter_sin','quarter_cos','week_sin','week_cos','sales_lag1','sales_ma7','sales_ma14','sales_ma21','sales_ma30','sales_std7','sales_std30','month_squared','weekday_squared','day_squared','sales_to_ma7_ratio','sales_to_ma30_ratio','ma7_to_ma30_ratio','sales_volatility_7','sales_volatility_30','sales_detrended'
]


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--db-path', type=str, default=os.path.join('.dart_tool','sqflite_common_ffi','databases','app.db'), help='Path to app.db')
    parser.add_argument('--out-dir', type=str, default=os.path.join('assets','models'), help='Output directory for models')
    parser.add_argument('--epochs', type=int, default=50)
    args = parser.parse_args()

    main(args.db_path, args.out_dir, epochs=args.epochs)
