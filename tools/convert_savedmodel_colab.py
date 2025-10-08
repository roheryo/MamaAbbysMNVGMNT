"""
Colab-ready converter: Unzip an uploaded SavedModel zip, convert to TFLite with optional optimizations,
and copy the result to Google Drive.

Usage in Colab (copy/paste cell):
1. Upload the zip file (use the Files UI or `files.upload()`), or download from a URL.
2. Mount Google Drive if you want to save the tflite there.
3. Run the conversion code below (adapt paths as needed).

Example (Colab cell):

from google.colab import files
uploaded = files.upload()  # upload your saved_model.zip

# then run the conversion below, replacing 'saved_model.zip' with uploaded filename

"""

import os
import zipfile
import tensorflow as tf
import pathlib

# Parameters to change in the Colab environment
ZIP_PATH = 'sales_forecast_saved.zip'  # uploaded zip filename
EXTRACT_DIR = '/content/saved_model'
OUT_TFLITE = '/content/sales_forecast.tflite'

# Unzip
os.makedirs(EXTRACT_DIR, exist_ok=True)
with zipfile.ZipFile(ZIP_PATH, 'r') as zf:
    zf.extractall(EXTRACT_DIR)

print('SavedModel extracted to', EXTRACT_DIR)

# Convert
try:
    converter = tf.lite.TFLiteConverter.from_saved_model(EXTRACT_DIR)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    with open(OUT_TFLITE, 'wb') as f:
        f.write(tflite_model)
    print('TFLite model written to', OUT_TFLITE)
except Exception as e:
    print('Conversion failed:', e)
    import traceback
    traceback.print_exc()

# Optional: copy to Drive
try:
    from google.colab import drive
    drive.mount('/content/drive')
    drive_path = '/content/drive/MyDrive/sales_forecast.tflite'
    os.replace(OUT_TFLITE, drive_path)
    print('TFLite moved to Google Drive:', drive_path)
except Exception:
    print('Skipping copy to Drive (not running in Colab mount or copy failed).')
