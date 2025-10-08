"""
Improved trainer and exporter that reuses preprocessing from `predict_ml_sales.py`.

It will:
 - Load and preprocess data using SalesMLAnalyzer from predict_ml_sales.py
 - Prepare feature matrix and target (next-day sales prediction style used by the app)
 - Run a small hyperparameter sweep over Keras architectures and learning rates
 - Pick the best model by RMSE on a held-out time-series test split
 - Export the SavedModel and a TFLite model (optionally quantized)
 - Export `sales_forecast_features.json` which lists the feature order

Usage:
  python train_export_improved.py --db-path ".dart_tool/sqflite_common_ffi/databases/app.db" --out-dir assets/models --epochs 100

Requirements:
  pip install tensorflow pandas numpy scikit-learn

"""
import argparse
import os
import json
import numpy as np
from datetime import datetime
import traceback

try:
    import tensorflow as tf
except Exception:
    raise RuntimeError("TensorFlow is required. Install with: pip install tensorflow")

from sklearn.metrics import mean_squared_error

# Import the analyzer from existing file to reuse preprocessing
from predict_ml_sales import SalesMLAnalyzer


def build_keras_model(input_dim, units=(128, 64), lr=0.001, dropout=0.0):
    tf.keras.backend.clear_session()
    inputs = tf.keras.layers.Input(shape=(input_dim,))
    x = inputs
    for u in units:
        x = tf.keras.layers.Dense(u, activation='relu')(x)
        if dropout and dropout > 0:
            x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation=None)(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs)
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=lr), loss='mse')
    return model


def main(db_path, out_dir, epochs):
    print("Loading and preprocessing data using predict_ml_sales.SalesMLAnalyzer...")
    analyzer = SalesMLAnalyzer(csv_file=None)
    # override DB path if necessary (SalesMLAnalyzer uses DB_PATH constant), but the class reads DB_PATH constant from predict_ml_sales.
    # If your environment requires a different DB path, adjust predict_ml_sales.DB_PATH or ensure the DB is at that location.
    df = analyzer.load_and_preprocess_data()

    # Prepare features similarly to analyzer.prepare_features
    exclude_cols = ['id', 'sale_date', 'day_of_week', 'sales']
    feature_cols = [col for col in df.columns if col not in exclude_cols]
    X = df[feature_cols].fillna(df[feature_cols].median()).values.astype(np.float32)
    y = df['sales'].values.astype(np.float32)

    split_point = int(len(X) * 0.8)
    X_train = X[:split_point]
    X_test = X[split_point:]
    y_train = y[:split_point]
    y_test = y[split_point:]

    # Scale using StandardScaler
    from sklearn.preprocessing import StandardScaler
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    input_dim = X_train_scaled.shape[1]
    print(f"Train shape: {X_train_scaled.shape}, Test shape: {X_test_scaled.shape}")

    # Hyperparameter candidates (small grid)
    candidates = [
        {'units': (128,64), 'lr': 1e-3, 'dropout': 0.0},
        {'units': (256,128,64), 'lr': 1e-3, 'dropout': 0.1},
        {'units': (64,32), 'lr': 1e-3, 'dropout': 0.0},
        {'units': (128,64), 'lr': 5e-4, 'dropout': 0.1},
    ]

    best_rmse = float('inf')
    best_model = None
    best_cfg = None

    for cfg in candidates:
        print(f"Training candidate: units={cfg['units']} lr={cfg['lr']} dropout={cfg['dropout']}")
        model = build_keras_model(input_dim, units=cfg['units'], lr=cfg['lr'], dropout=cfg['dropout'])
        es = tf.keras.callbacks.EarlyStopping(monitor='loss', patience=8, restore_best_weights=True)
        model.fit(X_train_scaled, y_train, epochs=epochs, batch_size=32, callbacks=[es], verbose=2)

        preds = model.predict(X_test_scaled).reshape(-1)
        # Some sklearn builds may not accept the `squared` keyword due to signature validation.
        # Compute RMSE explicitly instead of passing `squared=False` for compatibility.
        rmse = np.sqrt(mean_squared_error(y_test, preds))
        print(f"Candidate RMSE on holdout: {rmse:.4f}")
        if rmse < best_rmse:
            best_rmse = rmse
            best_model = model
            best_cfg = cfg

    print(f"Best RMSE: {best_rmse:.4f} with cfg: {best_cfg}")

    # Save scaler and feature order
    os.makedirs(out_dir, exist_ok=True)
    scaler_path = os.path.join(out_dir, 'scaler.npy')
    np.save(scaler_path, np.array([scaler.mean_, scaler.scale_], dtype=object), allow_pickle=True)

    features_path = os.path.join(out_dir, 'sales_forecast_features.json')
    with open(features_path, 'w', encoding='utf-8') as fh:
        json.dump(feature_cols, fh, indent=2)
    print(f"Features written to: {features_path}")

    # Save SavedModel directory (use tf.saved_model.save to ensure SavedModel format)
    saved_model_dir = os.path.join(out_dir, 'sales_forecast_saved')
    # Remove existing directory if present to avoid overwrite issues
    try:
        tf.saved_model.save(best_model, saved_model_dir)
        print(f"SavedModel written to: {saved_model_dir}")
    except Exception as e:
        # Fall back to Keras save with recommended guidance if tf.saved_model.save fails
        print(f"tf.saved_model.save failed: {e}. Trying Keras .save with .keras extension.")
        fallback_path = saved_model_dir + '.keras'
        best_model.save(fallback_path, include_optimizer=False)
        print(f"Keras model written to: {fallback_path}")

    # Convert to TFLite (with quantization if possible)
    # Convert to TFLite (with quantization if possible)
    try:
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        try:
            tflite_model = converter.convert()
        except Exception as e:
            print(f"Optimized conversion failed: {e}. Trying non-optimized conversion.")
            converter.optimizations = []
            tflite_model = converter.convert()

        tflite_path = os.path.join(out_dir, 'sales_forecast.tflite')
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        print(f"TFLite model written to: {tflite_path}")
    except Exception as e:
        print("TFLite conversion failed:")
        traceback.print_exc()
        print("SavedModel export succeeded; you can try converting the SavedModel to TFLite later on a machine with matching TF/TFLite toolchain or by using a different TF version.")

    print("Training and export complete.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--db-path', type=str, default=os.path.join('.dart_tool','sqflite_common_ffi','databases','app.db'))
    parser.add_argument('--out-dir', type=str, default=os.path.join('assets','models'))
    parser.add_argument('--epochs', type=int, default=100)
    args = parser.parse_args()
    main(args.db_path, args.out_dir, args.epochs)
