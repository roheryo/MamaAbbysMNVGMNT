This application is designed to help users efficiently manage their business inventory, sales records, and delivery schedules in one platform. 
Users can add and organize their product lists to keep track of inventory, as well as monitor their daily, weekly, and monthly sales. The system also 
allows users to add and schedule deliveries, providing automatic reminders when a delivery is due. Additionally, it notifies users about low stock items

## Development environment (Python)

If you want to run the training and export utilities (for example `train_export_improved.py`), a Python environment is required.

Recommendations and quick setup for Windows (PowerShell):

- Recommended Python: 3.11 (prebuilt wheels for TensorFlow and NumPy are available and known to work).
- Create a dedicated venv in the repo (example uses `.venv311`):

```powershell
py -3.11 -m venv .venv311
.venv311\Scripts\python.exe -m pip install --upgrade pip setuptools wheel
.venv311\Scripts\python.exe -m pip install "numpy<2.0,>=1.26" tensorflow==2.16.1 pandas scikit-learn
.venv311\Scripts\python.exe -m pip install matplotlib seaborn
```

- Run the trainer (example):

```powershell
.venv311\Scripts\python.exe train_export_improved.py --db-path ".dart_tool\sqflite_common_ffi\databases\app.db" --out-dir "assets/models" --epochs 100
```

Notes:
- TensorFlow 2.16.x requires NumPy < 2.0. The repo's `requirements.txt` has been updated to pin NumPy to `>=1.26,<2.0`.
- If you use Python 3.13, pip may try to build NumPy from source and fail unless MSVC build tools and Meson are installed. Using Python 3.11 avoids that pain by using prebuilt wheels.
- The trainer will export a SavedModel directory (`assets/models/sales_forecast_saved`). Converting that SavedModel to a TFLite file can sometimes fail in local environments (LLVM/type inference issues). If TFLite conversion fails, you can:
    - Convert on a different machine or environment (e.g., Colab) with a compatible TF/TFLite toolchain.
    - Try a slightly different TensorFlow version for conversion.

If you want, I can add a dedicated development README (`DEVELOPMENT.md`) with pinned packages and a `pip freeze` output to make reproduction easier.
// -Madulara (roheryo)
    Clarin(vnchxxxxx)
    Sansano (balinojanpaul)
    
INVENTORY MANAGEMENT FOR FROZEN MEATSHOP, A REMINDER APP FOR DELIVERY, FOR STOCKS UPDATES, SALES RECORDS IN DAYS, WEEKS, MONTHS.

SET UP: DONWLOAD FLUTTER SDK, DART
INSTALL Yaml Extension 
Install Emulator or Use own mobile device.


This application is designed to help users efficiently manage their business inventory, sales records, and delivery schedules in one platform. 
Users can add and organize their product lists to keep track of inventory, as well as monitor their daily, weekly, and monthly sales. The system also 
allows users to add and schedule deliveries, providing automatic reminders when a delivery is due. Additionally, it notifies users about low stock items
and updates on their sales activities to ensure smooth business operations. Overall, this application serves as a smart assistant that helps users stay 
updated with their inventory levels, sales performance, and delivery schedules for better productivity and management.


