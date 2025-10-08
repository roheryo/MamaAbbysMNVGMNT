from predict_ml_sales import SalesMLAnalyzer

an = SalesMLAnalyzer(None)
print('Loading and preprocessing data...')
dan = an.load_and_preprocess_data()
print('Preparing features...')
an.prepare_features()
# If models not trained, run training pipeline which also exports model; otherwise use existing models
if not an.models:
    print('No trained models in current session. Running complete analysis (this will train models and export).')
    an.run_complete_analysis()
else:
    future = an.predict_future_sales()
    print('\nPython 30-day predictions:')
    print(future.to_string(index=False, float_format='%.2f'))
