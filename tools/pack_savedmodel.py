"""Pack a TensorFlow SavedModel directory into a zip file for easy upload.

Usage:
  python tools/pack_savedmodel.py path/to/saved_model_dir path/to/output.zip

Example:
  python tools/pack_savedmodel.py assets/models/sales_forecast_saved assets/models/sales_forecast_saved.zip
"""
import os
import sys
import zipfile


def zipdir(path, ziph):
    # ziph is zipfile handle
    for root, dirs, files in os.walk(path):
        for file in files:
            fullpath = os.path.join(root, file)
            relpath = os.path.relpath(fullpath, os.path.dirname(path))
            ziph.write(fullpath, relpath)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python tools/pack_savedmodel.py path/to/saved_model_dir path/to/output.zip")
        sys.exit(1)
    saved_model_dir = sys.argv[1]
    out_zip = sys.argv[2]
    if not os.path.isdir(saved_model_dir):
        print(f"SavedModel directory not found: {saved_model_dir}")
        sys.exit(2)
    os.makedirs(os.path.dirname(out_zip) or '.', exist_ok=True)
    with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
        zipdir(saved_model_dir, zf)
    print(f"Created zip: {out_zip}")
