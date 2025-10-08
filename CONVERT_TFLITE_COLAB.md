# Convert SavedModel to TFLite using Google Colab

If local TFLite conversion fails due to low-level LLVM/type issues, a simple workaround is to convert the SavedModel on Colab where TF/TFLite binaries are already configured.

Steps

1. Create a zip of your SavedModel directory locally (the repo has a helper):

```powershell
python tools/pack_savedmodel.py assets/models/sales_forecast_saved assets/models/sales_forecast_saved.zip
```

2. Open a new Google Colab notebook: https://colab.research.google.com/

3. Upload the zip file using the left Files pane or run:

```python
from google.colab import files
uploaded = files.upload()  # select sales_forecast_saved.zip
```

4. Copy/paste the conversion code from `tools/convert_savedmodel_colab.py` into a Colab cell (or upload that file and run it). Update `ZIP_PATH` if needed.

5. Run the cell. If conversion succeeds the script will write `/content/sales_forecast.tflite` and attempt to move it to your Google Drive at `/MyDrive/sales_forecast.tflite` (you'll be prompted to mount Drive).

6. Download the `.tflite` from the Colab Files pane or from your Drive.

Notes

- If the conversion fails in Colab, copy the error traceback and include it when asking for help (some models/ops are not supported by TFLite or require custom conversion steps).
- Colab uses a different TF build than your local Windows setup; this often avoids local LLVM/toolchain issues.

Troubleshooting

- If you see errors about missing custom ops, you may need to export using `tf.saved_model.save` with concrete functions or use the TFLite converter options for signatures. I can help adapt the conversion call if you hit that.
