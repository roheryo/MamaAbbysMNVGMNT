"""
Headless runner to train a compact TF model from the project's SQLite DB and export SavedModel + TFLite.
Usage: python tools/run_train_export.py
This script reads the SQLite DB at the path hard-coded below (from your project), builds features similar to predict_ml_sales.py,
trains a Conv1D model on sequences, and writes artifacts to export/.
"""

import os
import sqlite3
import numpy as np
import pandas as pd
import json
from datetime import datetime

os.environ['PYTHONHASHSEED'] = '42'
import random
random.seed(42)
np.random.seed(42)

# TensorFlow import
import tensorflow as tf
from sklearn.preprocessing import StandardScaler
import joblib

DB_PATH = r"C:\Users\admin\Downloads\Mama_Abbys\MamaAbbysMNVGMNT\.dart_tool\sqflite_common_ffi\databases\app.db"
TABLE_NAME = 'store_sales'
EXPORT_DIR = 'export'

os.makedirs(EXPORT_DIR, exist_ok=True)

# 1) Load data from SQLite
print('Opening DB:', DB_PATH)
with sqlite3.connect(DB_PATH) as conn:
    query = f"SELECT id, sale_date, day_of_week, month, holiday_flag, sales FROM {TABLE_NAME} ORDER BY sale_date"
    df = pd.read_sql_query(query, conn, parse_dates=['sale_date'])

print('Loaded rows:', len(df))
if df.empty:
    raise SystemExit('No data found in DB')

# 2) Basic preprocessing (adapted)
df['sale_date'] = pd.to_datetime(df['sale_date'])
if 'month' not in df.columns:
    df['month'] = df['sale_date'].dt.month
if 'holiday_flag' not in df.columns:
    df['holiday_flag'] = 0
if 'day_of_week' not in df.columns:
    df['day_of_week'] = df['sale_date'].dt.day_name()

# sort
df = df.sort_values('sale_date').reset_index(drop=True)

# feature engineering (same as notebook)
df_proc = df.copy()
df_proc['year'] = df_proc['sale_date'].dt.year
df_proc['day'] = df_proc['sale_date'].dt.day
df_proc['quarter'] = df_proc['sale_date'].dt.quarter
df_proc['weekday'] = df_proc['sale_date'].dt.weekday
df_proc['week_of_year'] = df_proc['sale_date'].dt.isocalendar().week
df_proc['day_of_year'] = df_proc['sale_date'].dt.dayofyear

df_proc['is_weekend'] = (df_proc['weekday'] >= 5).astype(int)
df_proc['is_month_start'] = df_proc['sale_date'].dt.is_month_start.astype(int)
df_proc['is_month_end'] = df_proc['sale_date'].dt.is_month_end.astype(int)
df_proc['is_quarter_start'] = df_proc['sale_date'].dt.is_quarter_start.astype(int)
df_proc['is_quarter_end'] = df_proc['sale_date'].dt.is_quarter_end.astype(int)

# day_of_week encoded
mapping = {'Monday':0,'Tuesday':1,'Wednesday':2,'Thursday':3,'Friday':4,'Saturday':5,'Sunday':6}
if df_proc['day_of_week'].dtype == object:
    df_proc['day_of_week_encoded'] = df_proc['day_of_week'].map(mapping).fillna(df_proc['weekday']).astype(int)
else:
    df_proc['day_of_week_encoded'] = pd.to_numeric(df_proc['day_of_week'], errors='coerce').fillna(df_proc['weekday']).astype(int)

# cyclical
import numpy as np
for col, period in [('month',12), ('day',31), ('weekday',7), ('quarter',4), ('week_of_year',52)]:
    if col in df_proc.columns:
        df_proc[f'{col}_sin'] = np.sin(2*np.pi*df_proc[col]/period)
        df_proc[f'{col}_cos'] = np.cos(2*np.pi*df_proc[col]/period)

# lags
for lag in [1,2,3,7,14,21,30]:
    df_proc[f'sales_lag{lag}'] = df_proc['sales'].shift(lag)

# rolling stats
for w in [3,7,14,21,30]:
    df_proc[f'sales_ma{w}'] = df_proc['sales'].rolling(window=w).mean()
    df_proc[f'sales_std{w}'] = df_proc['sales'].rolling(window=w).std()

# ema
for span in [7,14,30]:
    df_proc[f'sales_ema{span}'] = df_proc['sales'].ewm(span=span).mean()

# diffs
df_proc['sales_diff1'] = df_proc['sales'].diff(1)
df_proc['sales_diff7'] = df_proc['sales'].diff(7)

# ratios
if 'sales_ma7' in df_proc.columns:
    df_proc['sales_to_ma7_ratio'] = df_proc['sales'] / (df_proc['sales_ma7'] + 1e-8)
if 'sales_ma30' in df_proc.columns:
    df_proc['sales_to_ma30_ratio'] = df_proc['sales'] / (df_proc['sales_ma30'] + 1e-8)

# detrended
if 'sales_ma30' in df_proc.columns:
    df_proc['sales_detrended'] = df_proc['sales'] - df_proc['sales_ma30']

# drop nans
df_proc = df_proc.dropna().reset_index(drop=True)
print('After feature engineering, rows:', len(df_proc))

# features list
exclude = ['id','sale_date','day_of_week','sales']
feature_cols = [c for c in df_proc.columns if c not in exclude]
print('Features:', feature_cols)

# Build sequences
window_size = 30
X = df_proc[feature_cols].values
y = df_proc['sales'].values

scaler = StandardScaler()
split_idx = int(len(X) * 0.8)
scaler.fit(X[:split_idx])
X_scaled = scaler.transform(X)
joblib.dump(scaler, os.path.join(EXPORT_DIR, 'scaler.joblib'))
np.savez(os.path.join(EXPORT_DIR, 'scaler_params.npz'), mean=scaler.mean_, scale=scaler.scale_)

def build_sequences(X, y, window):
    Xs, ys = [], []
    for i in range(window, len(X)):
        Xs.append(X[i-window:i])
        ys.append(y[i])
    return np.array(Xs), np.array(ys)

X_seq, y_seq = build_sequences(X_scaled, y, window_size)
print('Sequence shapes:', X_seq.shape, y_seq.shape)

train_n = int(0.8 * len(X_seq))
X_train, y_train = X_seq[:train_n], y_seq[:train_n]
X_val, y_val = X_seq[train_n:], y_seq[train_n:]

# Build model (Conv1D compact)
from tensorflow.keras import layers, models
input_shape = (window_size, X_seq.shape[2])
inputs = layers.Input(shape=input_shape)
x = layers.Conv1D(64, 3, activation='relu', padding='same')(inputs)
x = layers.Conv1D(32, 3, activation='relu', padding='same')(x)
x = layers.GlobalAveragePooling1D()(x)
x = layers.Dense(64, activation='relu')(x)
x = layers.Dropout(0.2)(x)
outputs = layers.Dense(1, activation='linear')(x)
model = models.Model(inputs, outputs)
model.compile(optimizer='adam', loss='mse', metrics=['mae'])
model.summary()

# Train briefly
ckpt = os.path.join(EXPORT_DIR, 'best_model.h5')
cb = [tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=6, restore_best_weights=True), tf.keras.callbacks.ModelCheckpoint(ckpt, save_best_only=True)]
model.fit(X_train, y_train, validation_data=(X_val,y_val), epochs=40, batch_size=32, callbacks=cb)

# Save (use tf.saved_model.save for SavedModel format)
saved_model_dir = os.path.join(EXPORT_DIR, 'saved_model')
# If a checkpoint exists, load it into the model (ModelCheckpoint saved best_model.h5)
ckpt = os.path.join(EXPORT_DIR, 'best_model.h5')
if os.path.exists(ckpt):
    try:
        model.load_weights(ckpt)
    except Exception:
        pass

# Export SavedModel using a tf.Module wrapper (avoids some Keras save issues)
class ModelWrapper(tf.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    @tf.function(input_signature=[tf.TensorSpec([None, None, X_seq.shape[2]], tf.float32)])
    def serve(self, x):
        return {'outputs': self.model(x)}

wrapped = ModelWrapper(model)
try:
    tf.saved_model.save(wrapped, saved_model_dir, signatures={'serving_default': wrapped.serve})
except Exception as e:
    print('tf.saved_model.save wrapper failed, attempting keras save fallback:', e)
    # fallback: save keras model in HDF5 (already saved) and exit
    pass
# Also save an HDF5 copy for convenience
model.save(os.path.join(EXPORT_DIR, 'model.h5'))
print('SavedModel & h5 exported')

# Save feature order
with open(os.path.join(EXPORT_DIR, 'feature_order.json'), 'w') as f:
    json.dump(feature_cols, f)

# Convert to TFLite float
if not os.path.exists(saved_model_dir):
    # Try converting from HDF5 to SavedModel using Keras API
    h5path = os.path.join(EXPORT_DIR, 'model.h5')
    if os.path.exists(h5path):
        try:
            print('Attempting to load HDF5 and save as SavedModel...')
            kmodel = tf.keras.models.load_model(h5path)
            tf.keras.models.save_model(kmodel, saved_model_dir, save_format='tf')
            print('Converted HDF5 -> SavedModel')
        except Exception as e:
            print('Failed to convert HDF5 -> SavedModel:', e)

if os.path.exists(saved_model_dir):
    try:
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        with open(os.path.join(EXPORT_DIR, 'model.tflite'), 'wb') as f:
            f.write(converter.convert())
        print('Wrote float TFLite')
    except Exception as e:
        print('TFLite conversion from SavedModel failed:', e)
        # Try converting directly from Keras model
        try:
            kmodel = tf.keras.models.load_model(os.path.join(EXPORT_DIR, 'model.h5'))
            converter2 = tf.lite.TFLiteConverter.from_keras_model(kmodel)
            with open(os.path.join(EXPORT_DIR, 'model.tflite'), 'wb') as f:
                f.write(converter2.convert())
            print('Wrote float TFLite from Keras model')
        except Exception as e2:
            print('Fallback TFLite conversion failed:', e2)
else:
    print('SavedModel not found; skipping TFLite float conversion')

# Representative for quant
def representative_gen():
    for i in range(min(500, X_train.shape[0])):
        yield [X_train[i:i+1].astype(np.float32)]


def try_convert_int8_from_saved_model_or_h5():
    """Try to produce an INT8 fully-quantized TFLite model from SavedModel or
    from a Keras HDF5 model. Return True if successful (and file written).
    """
    # Try SavedModel first
    try:
        if os.path.isdir(saved_model_dir) and os.path.exists(os.path.join(saved_model_dir, 'saved_model.pb')):
            print('Full int quant: attempting from SavedModel...')
            c = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
            c.optimizations = [tf.lite.Optimize.DEFAULT]
            c.representative_dataset = representative_gen
            c.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
            c.inference_input_type = tf.int8
            c.inference_output_type = tf.int8
            tfl = c.convert()
            with open(os.path.join(EXPORT_DIR, 'model_quant.tflite'), 'wb') as f:
                f.write(tfl)
            print('Wrote quantized TFLite (from SavedModel)')
            return True
    except Exception as e:
        print('Full int quant from SavedModel failed:', e)

    # Fallback: try from Keras HDF5
    h5_path = os.path.join(EXPORT_DIR, 'best_model.h5')
    if os.path.exists(h5_path):
        try:
            print('Full int quant: attempting from Keras HDF5 model...')
            keras_model = tf.keras.models.load_model(h5_path, compile=False)
            c = tf.lite.TFLiteConverter.from_keras_model(keras_model)
            c.optimizations = [tf.lite.Optimize.DEFAULT]
            c.representative_dataset = representative_gen
            c.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
            c.inference_input_type = tf.int8
            c.inference_output_type = tf.int8
            tfl = c.convert()
            with open(os.path.join(EXPORT_DIR, 'model_quant.tflite'), 'wb') as f:
                f.write(tfl)
            print('Wrote quantized TFLite (from HDF5)')
            return True
        except Exception as e:
            print('Full int quant from HDF5 failed:', e)
    else:
        print('HDF5 model not found at', h5_path)

    return False


# Attempt full-int quantization; if it fails, fall back to dynamic-range quant
try:
    ok = try_convert_int8_from_saved_model_or_h5()
    if not ok:
        print('Full int quant conversion not produced by any method; trying dynamic-range')
        # Try dynamic-range quantization from SavedModel or HDF5
        # Helper: try dynamic-range and float16 quant from SavedModel or HDF5
        def try_dynamic_and_float16():
            # dynamic-range first
            wrote_any = False
            try:
                if os.path.isdir(saved_model_dir) and os.path.exists(os.path.join(saved_model_dir, 'saved_model.pb')):
                    print('Attempting dynamic-range quant from SavedModel...')
                    c = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
                    c.optimizations = [tf.lite.Optimize.DEFAULT]
                    tfl = c.convert()
                    with open(os.path.join(EXPORT_DIR, 'model_quant_dynamic.tflite'), 'wb') as f:
                        f.write(tfl)
                    print('Wrote dynamic-range quant TFLite (from SavedModel)')
                    wrote_any = True
            except Exception as e:
                print('Dynamic-range quant from SavedModel failed:', e)

            # fallback to HDF5
            h5_path = os.path.join(EXPORT_DIR, 'best_model.h5')
            if not wrote_any and os.path.exists(h5_path):
                try:
                    print('Attempting dynamic-range quant from HDF5...')
                    keras_model = tf.keras.models.load_model(h5_path, compile=False)
                    c = tf.lite.TFLiteConverter.from_keras_model(keras_model)
                    c.optimizations = [tf.lite.Optimize.DEFAULT]
                    tfl = c.convert()
                    with open(os.path.join(EXPORT_DIR, 'model_quant_dynamic.tflite'), 'wb') as f:
                        f.write(tfl)
                    print('Wrote dynamic-range quant TFLite (from HDF5)')
                    wrote_any = True
                except Exception as e:
                    print('Dynamic-range quant from HDF5 failed:', e)

            # Try float16 quantization (smaller but float-preserving)
            try:
                if os.path.exists(h5_path):
                    print('Attempting float16 quantization from HDF5...')
                    keras_model = tf.keras.models.load_model(h5_path, compile=False)
                    c = tf.lite.TFLiteConverter.from_keras_model(keras_model)
                    c.optimizations = [tf.lite.Optimize.DEFAULT]
                    c.target_spec.supported_types = [tf.float16]
                    tfl = c.convert()
                    with open(os.path.join(EXPORT_DIR, 'model_float16.tflite'), 'wb') as f:
                        f.write(tfl)
                    print('Wrote float16 TFLite (from HDF5)')
                    wrote_any = True
            except Exception as e:
                print('Float16 quant from HDF5 failed:', e)

            return wrote_any

        try:
            any_written = try_dynamic_and_float16()
            if not any_written:
                print('No dynamic-range/float16 artifacts produced.')
        except Exception as e:
            print('Dynamic/float16 conversion top-level failure:', e)
except Exception as e:
    print('Top-level quantization process failed:', e)

# Package
import zipfile
meta = {'input_shape':[window_size, X_seq.shape[2]], 'feature_order':feature_cols}
with open(os.path.join(EXPORT_DIR, 'metadata.json'),'w') as f:
    json.dump(meta,f)

zip_path = os.path.join(EXPORT_DIR, 'artifacts.zip')
with zipfile.ZipFile(zip_path, 'w') as z:
    for fname in ['feature_order.json','scaler_params.npz','metadata.json','model.tflite','model_quant.tflite','model_quant_dynamic.tflite']:
        full = os.path.join(EXPORT_DIR, fname)
        if os.path.exists(full):
            z.write(full, arcname=fname)

print('Packaged artifacts at', zip_path)
print('Done')
