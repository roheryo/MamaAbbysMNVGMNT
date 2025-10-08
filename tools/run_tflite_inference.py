"""Run a quick sanity-check inference using the exported TFLite model.
This script mirrors the preprocessing used in tools/run_train_export.py, loads the scaler
parameters, builds one sequence from the end of the dataset, and runs inference with
both the TFLite interpreter and the original Keras HDF5 (if available) for comparison.
"""
import os
import sqlite3
import numpy as np
import pandas as pd
import json
from sklearn.preprocessing import StandardScaler
import joblib

EXPORT_DIR = 'export'
DB_PATH = r"C:\Users\admin\Downloads\Mama_Abbys\MamaAbbysMNVGMNT\.dart_tool\sqflite_common_ffi\databases\app.db"
TABLE_NAME = 'store_sales'

# Load data same as runner
with sqlite3.connect(DB_PATH) as conn:
    query = f"SELECT id, sale_date, day_of_week, month, holiday_flag, sales FROM {TABLE_NAME} ORDER BY sale_date"
    df = pd.read_sql_query(query, conn, parse_dates=['sale_date'])

if df.empty:
    raise SystemExit('No data found for inference test')

# Feature engineering (copy of runner minimal needed)
df['sale_date'] = pd.to_datetime(df['sale_date'])
if 'month' not in df.columns:
    df['month'] = df['sale_date'].dt.month
if 'holiday_flag' not in df.columns:
    df['holiday_flag'] = 0
if 'day_of_week' not in df.columns:
    df['day_of_week'] = df['sale_date'].dt.day_name()

# sort
df = df.sort_values('sale_date').reset_index(drop=True)

# --- replicate runner preprocessing to produce X_scaled, y, and last_seq ---
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

import numpy as _np
for col, period in [('month',12), ('day',31), ('weekday',7), ('quarter',4), ('week_of_year',52)]:
    if col in df_proc.columns:
        df_proc[f'{col}_sin'] = _np.sin(2*_np.pi*df_proc[col]/period)
        df_proc[f'{col}_cos'] = _np.cos(2*_np.pi*df_proc[col]/period)

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

if 'sales_ma30' in df_proc.columns:
    df_proc['sales_detrended'] = df_proc['sales'] - df_proc['sales_ma30']

# drop nans
df_proc = df_proc.dropna().reset_index(drop=True)

exclude = ['id','sale_date','day_of_week','sales']
feature_cols = [c for c in df_proc.columns if c not in exclude]

window_size = 30
X = df_proc[feature_cols].values
y = df_proc['sales'].values

# load scaler
scaler_path = os.path.join(EXPORT_DIR, 'scaler.joblib')
if not os.path.exists(scaler_path):
    raise SystemExit('Scaler not found in export/ — run tools/run_train_export.py first')
scaler = joblib.load(scaler_path)
X_scaled = scaler.transform(X)

# build last sequence
if len(X_scaled) < window_size + 1:
    raise SystemExit('Not enough rows after preprocessing to build a sequence')

last_seq = X_scaled[-window_size:]
last_seq = last_seq.reshape(1, window_size, X_scaled.shape[1]).astype(np.float32)
true_next = y[-1]

print('Feature count:', X_scaled.shape[1])
print('Last true value:', true_next)
# --- end preprocessing ---

# Compute same engineered columns
try:
    import tflite_runtime.interpreter as tflite_rt
    InterpreterRT = tflite_rt.Interpreter
    print('Using tflite_runtime interpreter')
except Exception:
    InterpreterRT = None

try:
    import tensorflow as tf
    InterpreterTF = tf.lite.Interpreter
    print('Using TensorFlow Lite Interpreter (via tf.lite.Interpreter)')
except Exception:
    InterpreterTF = None

# Evaluate all available artifacts
artifact_names = ['model.tflite', 'model_quant.tflite', 'model_quant_dynamic.tflite', 'model_float16.tflite']
found_any = False
for name in artifact_names:
    p = os.path.join(EXPORT_DIR, name)
    if not os.path.exists(p):
        continue
    found_any = True
    print('\n--- Running inference with', name, '---')
    # choose available interpreter
    interp_cls = InterpreterRT or InterpreterTF
    if interp_cls is None:
        print('No TFLite interpreter available to test', name)
        continue

    interpreter = interp_cls(model_path=p) if interp_cls is not None else None
    if interpreter is None:
        print('Failed to create interpreter for', p)
        continue
    interpreter.allocate_tensors()
    in_det = interpreter.get_input_details()
    out_det = interpreter.get_output_details()

    inp = last_seq.copy()
    # Quantize if required
    if in_det[0]['dtype'] in (np.int8, np.uint8):
        scale, zero_point = in_det[0].get('quantization', (0.0, 0))
        if scale == 0:
            print('Quantization scale is zero for', name)
        try:
            q_dtype = np.int8 if in_det[0]['dtype'] == np.int8 else np.uint8
            inp_q = (inp / scale + zero_point).astype(q_dtype)
            interpreter.set_tensor(in_det[0]['index'], inp_q)
        except Exception as e:
            print('Failed to quantize input for', name, ':', e)
            continue
    else:
        interpreter.set_tensor(in_det[0]['index'], inp)

    interpreter.invoke()
    opred = interpreter.get_tensor(out_det[0]['index']).squeeze()
    print(name, 'prediction:', float(opred))

if not found_any:
    print('No TFLite artifacts found; consider running tools/run_train_export.py to produce them')

# build last sequence
if len(X_scaled) < window_size + 1:
    raise SystemExit('Not enough rows after preprocessing to build a sequence')

last_seq = X_scaled[-window_size:]
last_seq = last_seq.reshape(1, window_size, X_scaled.shape[1]).astype(np.float32)
true_next = y[-1]

print('Feature count:', X_scaled.shape[1])
print('Last true value:', true_next)

# Try TFLite inference
interp_error_msgs = []
Interpreter = None
try:
    import tflite_runtime.interpreter as tflite_rt
    Interpreter = tflite_rt.Interpreter
    print('Using tflite_runtime interpreter')
except Exception as e:
    interp_error_msgs.append(f'tflite_runtime import failed: {e}')
    try:
        import tensorflow as tf
        # try common access patterns
        try:
            Interpreter = tf.lite.Interpreter
            print('Using TensorFlow Lite Interpreter (via tf.lite.Interpreter)')
        except Exception as e2:
            interp_error_msgs.append(f'tf.lite.Interpreter failed: {e2}')
            try:
                from tensorflow.lite import Interpreter as TFInterpreter
                Interpreter = TFInterpreter
                print('Using TensorFlow Lite Interpreter (from tensorflow.lite)')
            except Exception as e3:
                interp_error_msgs.append(f'tensorflow.lite.Interpreter failed: {e3}')
    except Exception as e4:
        interp_error_msgs.append(f'import tensorflow failed: {e4}')

if Interpreter is None:
    print('\nInterpreter import errors:')
    for m in interp_error_msgs:
        print(' -', m)
    raise SystemExit('No TFLite interpreter available in this Python environment')

# pick the best tflite artifact
candidates = ['model_quant.tflite','model_quant_dynamic.tflite','model.tflite']
model_file = None
for c in candidates:
    p = os.path.join(EXPORT_DIR, c)
    if os.path.exists(p):
        model_file = p
        break
if model_file is None:
    # If there's no tflite file, but we have a Keras HDF5 checkpoint, convert it to
    # a float TFLite here for comparison (this forces a float model.tflite).
    h5 = os.path.join(EXPORT_DIR, 'best_model.h5')
    if os.path.exists(h5):
        try:
            print('No TFLite artifact found; converting best_model.h5 -> export/model.tflite (float)')
            import tensorflow as tf
            kmodel = tf.keras.models.load_model(h5, compile=False)
            converter = tf.lite.TFLiteConverter.from_keras_model(kmodel)
            # Force float converter (no optimizations)
            converter.optimizations = []
            tfl = converter.convert()
            outp = os.path.join(EXPORT_DIR, 'model.tflite')
            with open(outp, 'wb') as f:
                f.write(tfl)
            model_file = outp
            print('Wrote float TFLite to', outp)
        except Exception as e:
            raise SystemExit('Failed to create float TFLite from HDF5: ' + str(e))
    else:
        raise SystemExit('No TFLite model found in export/ and no best_model.h5 to convert')

print('Using TFLite model:', model_file)
interpreter = Interpreter(model_path=model_file)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# If model expects int8 input, we need to quantize the input using input scale/zero_point
inp = last_seq.copy()
if input_details[0]['dtype'] == np.int8:
    scale, zero_point = input_details[0]['quantization']
    if scale == 0:
        raise SystemExit('Quantization scale is zero — cannot quantize')
    inp_q = (inp / scale + zero_point).astype(np.int8)
    interpreter.set_tensor(input_details[0]['index'], inp_q)
else:
    interpreter.set_tensor(input_details[0]['index'], inp)

interpreter.invoke()
pred = interpreter.get_tensor(output_details[0]['index']).squeeze()
print('TFLite prediction:', float(pred))

# Try Keras model prediction if available
h5 = os.path.join(EXPORT_DIR, 'best_model.h5')
if os.path.exists(h5):
    try:
        import tensorflow as tf
        k = tf.keras.models.load_model(h5, compile=False)
        kpred = k.predict(last_seq).squeeze()
        print('Keras HDF5 prediction:', float(kpred))
    except Exception as e:
        print('Keras prediction failed:', e)

    # In-memory float TFLite conversion and inference (non-destructive)
    try:
        print('\nConverting Keras model to float TFLite in-memory for comparison...')
        converter = tf.lite.TFLiteConverter.from_keras_model(k)
        # no optimization -> keep float
        converter.optimizations = []
        tflite_model_bytes = converter.convert()

        # Load interpreter from bytes
        print('Loading float TFLite interpreter from memory...')
        try:
            # tf.lite.Interpreter supports model_content param
            float_interpreter = tf.lite.Interpreter(model_content=tflite_model_bytes)
        except Exception:
            # fallback to tensorflow.lite.Interpreter import
            from tensorflow.lite import Interpreter as TFInterpreter
            float_interpreter = TFInterpreter(model_content=tflite_model_bytes)

        float_interpreter.allocate_tensors()
        in_details = float_interpreter.get_input_details()
        out_details = float_interpreter.get_output_details()

        # Prepare input (float)
        finp = last_seq.astype(np.float32)
        if in_details[0]['dtype'] == np.float32:
            float_interpreter.set_tensor(in_details[0]['index'], finp)
        else:
            # if unexpectedly quantized, do best-effort quantization
            q_scale, q_zero = in_details[0].get('quantization', (0.0, 0))
            if q_scale and q_scale != 0:
                q_in = (finp / q_scale + q_zero).astype(in_details[0]['dtype'])
                float_interpreter.set_tensor(in_details[0]['index'], q_in)
            else:
                float_interpreter.set_tensor(in_details[0]['index'], finp)

        float_interpreter.invoke()
        fpred = float_interpreter.get_tensor(out_details[0]['index']).squeeze()
        print('Float-TFLite (in-memory) prediction:', float(fpred))
    except Exception as e:
        print('Float TFLite in-memory conversion/inference failed:', e)

print('Done')
