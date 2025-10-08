"""Convert the Keras HDF5 checkpoint (export/best_model.h5) to dynamic-range and float16 TFLite artifacts.
Non-destructive: writes to export/model_quant_dynamic.tflite and export/model_float16.tflite.
"""
import os
import tensorflow as tf

EXPORT_DIR = 'export'
h5 = os.path.join(EXPORT_DIR, 'best_model.h5')
if not os.path.exists(h5):
    raise SystemExit('best_model.h5 not found in export/; run tools/run_train_export.py first')

print('Loading Keras model from', h5)
kmodel = tf.keras.models.load_model(h5, compile=False)

# Dynamic-range quantization
try:
    print('Converting to dynamic-range quant TFLite...')
    c = tf.lite.TFLiteConverter.from_keras_model(kmodel)
    c.optimizations = [tf.lite.Optimize.DEFAULT]
    tfl = c.convert()
    outp = os.path.join(EXPORT_DIR, 'model_quant_dynamic.tflite')
    with open(outp, 'wb') as f:
        f.write(tfl)
    print('Wrote', outp)
except Exception as e:
    print('Dynamic-range conversion failed:', e)

# Float16 quantization
try:
    print('Converting to float16 TFLite...')
    c = tf.lite.TFLiteConverter.from_keras_model(kmodel)
    c.optimizations = [tf.lite.Optimize.DEFAULT]
    c.target_spec.supported_types = [tf.float16]
    tfl = c.convert()
    outp = os.path.join(EXPORT_DIR, 'model_float16.tflite')
    with open(outp, 'wb') as f:
        f.write(tfl)
    print('Wrote', outp)
except Exception as e:
    print('Float16 conversion failed:', e)

print('Done')
