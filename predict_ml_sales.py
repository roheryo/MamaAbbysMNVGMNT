import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import sqlite3
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Machine Learning Libraries
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV, TimeSeriesSplit
from sklearn.preprocessing import StandardScaler, LabelEncoder, RobustScaler, MinMaxScaler
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor, ExtraTreesRegressor, VotingRegressor
from sklearn.linear_model import LinearRegression, Ridge, Lasso, ElasticNet, HuberRegressor
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from sklearn.tree import DecisionTreeRegressor
from sklearn.svm import SVR
from sklearn.neural_network import MLPRegressor
from sklearn.kernel_ridge import KernelRidge
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import RBF, WhiteKernel
from sklearn.pipeline import Pipeline

try:
    import skl2onnx
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType
    ONNX_EXPORT_AVAILABLE = True
except Exception:
    ONNX_EXPORT_AVAILABLE = False

# Advanced ML Libraries
try:
    import xgboost as xgb
    XGBOOST_AVAILABLE = True
except ImportError:
    XGBOOST_AVAILABLE = False
    print("XGBoost not available. Install with: pip install xgboost")

try:
    import lightgbm as lgb
    LIGHTGBM_AVAILABLE = True
except ImportError:
    LIGHTGBM_AVAILABLE = False
    print("LightGBM not available. Install with: pip install lightgbm")

try:
    from sklearn.ensemble import StackingRegressor
    STACKING_AVAILABLE = True
except ImportError:
    STACKING_AVAILABLE = False

# Data source configuration (SQLite)
DB_PATH = r"C:\\Users\\admin\\Downloads\\Mama_Abbys\\MamaAbbysMNVGMNT\\.dart_tool\\sqflite_common_ffi\\databases\\app.db"
TABLE_NAME = "store_sales"

# Set style for better plots
try:
    plt.style.use('seaborn-v0_8')
except OSError:
    try:
        plt.style.use('seaborn')
    except OSError:
        plt.style.use('default')

try:
    sns.set_palette("husl")
except:
    pass  # Use default palette if seaborn palette fails

class SalesMLAnalyzer:
    def __init__(self, csv_file):
        """Initialize the Sales ML Analyzer"""
        self.csv_file = csv_file
        self.df = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.scaler = StandardScaler()
        self.models = {}
        self.results = {}
        self.plot_enabled = True  # Flag to enable/disable plotting
    
    def safe_plot(self, fig, filename=None):
        """Safely display plots"""
        try:
            if self.plot_enabled:
                plt.tight_layout()
                plt.show()
        except Exception as e:
            print(f"Plotting error (non-critical): {e}")
        finally:
            plt.close(fig)
        
    def load_and_preprocess_data(self):
        """Load and preprocess the sales data with advanced feature engineering"""
        print("Loading and preprocessing data with advanced feature engineering...")
        
        # Load from SQLite store_sales instead of CSV
        with sqlite3.connect(DB_PATH) as conn:
            query = f"""
                SELECT
                    id,
                    sale_date,
                    day_of_week,
                    month,
                    holiday_flag,
                    sales
                FROM {TABLE_NAME}
                ORDER BY sale_date
            """
            self.df = pd.read_sql_query(query, conn)
        
        # Convert sale_date to datetime (auto-parse)
        self.df['sale_date'] = pd.to_datetime(self.df['sale_date'])
        
        # Normalize schema types from DB
        # Ensure month and holiday_flag are integers
        self.df['month'] = pd.to_numeric(self.df['month'], errors='coerce').fillna(self.df['sale_date'].dt.month).astype(int)
        self.df['holiday_flag'] = pd.to_numeric(self.df['holiday_flag'], errors='coerce').fillna(0).astype(int)
        
        # Ensure day_of_week is mapped to standard names if needed
        # If already names like 'Monday'.. it will map directly below
        # If numeric strings present, convert to names via weekday number
        dow_series = self.df['day_of_week'].astype(str).str.strip()
        name_candidates = set(['monday','tuesday','wednesday','thursday','friday','saturday','sunday',
                               'Mon','Tue','Wed','Thu','Fri','Sat','Sun','MON','TUE','WED','THU','FRI','SAT','SUN'])
        if not dow_series.str.lower().isin({n.lower() for n in name_candidates}).all():
            # Try convert numerics 0-6 to names
            as_num = pd.to_numeric(dow_series, errors='coerce')
            mapper = {0:'Monday',1:'Tuesday',2:'Wednesday',3:'Thursday',4:'Friday',5:'Saturday',6:'Sunday'}
            self.df['day_of_week'] = as_num.map(mapper).fillna(self.df['day_of_week'])
        
        # Extract comprehensive date features
        self.df['year'] = self.df['sale_date'].dt.year
        self.df['day'] = self.df['sale_date'].dt.day
        self.df['quarter'] = self.df['sale_date'].dt.quarter
        self.df['weekday'] = self.df['sale_date'].dt.weekday
        self.df['week_of_year'] = self.df['sale_date'].dt.isocalendar().week
        self.df['day_of_year'] = self.df['sale_date'].dt.dayofyear
        self.df['is_weekend'] = (self.df['weekday'] >= 5).astype(int)
        self.df['is_month_start'] = self.df['sale_date'].dt.is_month_start.astype(int)
        self.df['is_month_end'] = self.df['sale_date'].dt.is_month_end.astype(int)
        self.df['is_quarter_start'] = self.df['sale_date'].dt.is_quarter_start.astype(int)
        self.df['is_quarter_end'] = self.df['sale_date'].dt.is_quarter_end.astype(int)
        
        # Encode day_of_week as numerical values
        day_mapping = {
            'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3,
            'Friday': 4, 'Saturday': 5, 'Sunday': 6
        }
        self.df['day_of_week_encoded'] = self.df['day_of_week'].map(day_mapping)
        
        # Create advanced cyclical features
        self.df['month_sin'] = np.sin(2 * np.pi * self.df['month'] / 12)
        self.df['month_cos'] = np.cos(2 * np.pi * self.df['month'] / 12)
        self.df['day_sin'] = np.sin(2 * np.pi * self.df['day'] / 31)
        self.df['day_cos'] = np.cos(2 * np.pi * self.df['day'] / 31)
        self.df['weekday_sin'] = np.sin(2 * np.pi * self.df['weekday'] / 7)
        self.df['weekday_cos'] = np.cos(2 * np.pi * self.df['weekday'] / 7)
        self.df['quarter_sin'] = np.sin(2 * np.pi * self.df['quarter'] / 4)
        self.df['quarter_cos'] = np.cos(2 * np.pi * self.df['quarter'] / 4)
        self.df['week_sin'] = np.sin(2 * np.pi * self.df['week_of_year'] / 52)
        self.df['week_cos'] = np.cos(2 * np.pi * self.df['week_of_year'] / 52)
        
        # Create comprehensive lag features
        for lag in [1, 2, 3, 7, 14, 21, 30]:
            self.df[f'sales_lag{lag}'] = self.df['sales'].shift(lag)
        
        # Create rolling statistics with multiple windows
        for window in [3, 7, 14, 21, 30]:
            self.df[f'sales_ma{window}'] = self.df['sales'].rolling(window=window).mean()
            self.df[f'sales_std{window}'] = self.df['sales'].rolling(window=window).std()
            self.df[f'sales_min{window}'] = self.df['sales'].rolling(window=window).min()
            self.df[f'sales_max{window}'] = self.df['sales'].rolling(window=window).max()
            self.df[f'sales_median{window}'] = self.df['sales'].rolling(window=window).median()
        
        # Create exponential moving averages
        for span in [7, 14, 30]:
            self.df[f'sales_ema{span}'] = self.df['sales'].ewm(span=span).mean()
        
        # Create trend features
        self.df['sales_diff1'] = self.df['sales'].diff(1)
        self.df['sales_diff7'] = self.df['sales'].diff(7)
        self.df['sales_pct_change1'] = self.df['sales'].pct_change(1)
        self.df['sales_pct_change7'] = self.df['sales'].pct_change(7)
        
        # Create interaction features
        self.df['month_holiday'] = self.df['month'] * self.df['holiday_flag']
        self.df['weekday_holiday'] = self.df['weekday'] * self.df['holiday_flag']
        self.df['is_weekend_holiday'] = self.df['is_weekend'] * self.df['holiday_flag']
        
        # Create polynomial features for key variables
        self.df['month_squared'] = self.df['month'] ** 2
        self.df['weekday_squared'] = self.df['weekday'] ** 2
        self.df['day_squared'] = self.df['day'] ** 2
        
        # Create ratio features
        self.df['sales_to_ma7_ratio'] = self.df['sales'] / (self.df['sales_ma7'] + 1e-8)
        self.df['sales_to_ma30_ratio'] = self.df['sales'] / (self.df['sales_ma30'] + 1e-8)
        self.df['ma7_to_ma30_ratio'] = self.df['sales_ma7'] / (self.df['sales_ma30'] + 1e-8)
        
        # Create volatility features
        self.df['sales_volatility_7'] = self.df['sales'].rolling(window=7).std() / (self.df['sales'].rolling(window=7).mean() + 1e-8)
        self.df['sales_volatility_30'] = self.df['sales'].rolling(window=30).std() / (self.df['sales'].rolling(window=30).mean() + 1e-8)
        
        # Create seasonal decomposition features (simplified)
        self.df['sales_detrended'] = self.df['sales'] - self.df['sales_ma30']
        
        # Drop rows with NaN values from lag features
        self.df = self.df.dropna()
        
        print(f"Data shape after advanced preprocessing: {self.df.shape}")
        print(f"Date range: {self.df['sale_date'].min()} to {self.df['sale_date'].max()}")
        print(f"Number of features created: {len(self.df.columns) - 3}")  # -3 for id, sale_date, day_of_week, sales
        
        return self.df
    
    def explore_data(self):
        """Perform exploratory data analysis"""
        print("\n" + "="*50)
        print("EXPLORATORY DATA ANALYSIS")
        print("="*50)
        
        # Basic statistics
        print("\nBasic Statistics:")
        print(self.df[['sales', 'month', 'holiday_flag', 'is_weekend']].describe())
        
        # Sales distribution
        plt.figure(figsize=(15, 10))
        
        plt.subplot(2, 3, 1)
        plt.hist(self.df['sales'], bins=50, alpha=0.7, color='skyblue')
        plt.title('Sales Distribution')
        plt.xlabel('Sales Amount')
        plt.ylabel('Frequency')
        
        # Sales by month
        plt.subplot(2, 3, 2)
        monthly_sales = self.df.groupby('month')['sales'].mean()
        plt.bar(monthly_sales.index, monthly_sales.values, color='lightcoral')
        plt.title('Average Sales by Month')
        plt.xlabel('Month')
        plt.ylabel('Average Sales')
        
        # Sales by day of week
        plt.subplot(2, 3, 3)
        daily_sales = self.df.groupby('day_of_week')['sales'].mean()
        plt.bar(range(len(daily_sales)), daily_sales.values, color='lightgreen')
        plt.title('Average Sales by Day of Week')
        plt.xlabel('Day of Week')
        plt.ylabel('Average Sales')
        plt.xticks(range(len(daily_sales)), daily_sales.index, rotation=45)
        
        # Holiday vs Non-holiday sales
        plt.subplot(2, 3, 4)
        holiday_sales = self.df.groupby('holiday_flag')['sales'].mean()
        plt.bar(['Non-Holiday', 'Holiday'], holiday_sales.values, color=['orange', 'purple'])
        plt.title('Average Sales: Holiday vs Non-Holiday')
        plt.ylabel('Average Sales')
        
        # Time series plot
        plt.subplot(2, 3, 5)
        plt.plot(self.df['sale_date'], self.df['sales'], alpha=0.7, color='blue')
        plt.title('Sales Over Time')
        plt.xlabel('Date')
        plt.ylabel('Sales')
        plt.xticks(rotation=45)
        
        # Weekend vs Weekday
        plt.subplot(2, 3, 6)
        weekend_sales = self.df.groupby('is_weekend')['sales'].mean()
        plt.bar(['Weekday', 'Weekend'], weekend_sales.values, color=['red', 'green'])
        plt.title('Average Sales: Weekday vs Weekend')
        plt.ylabel('Average Sales')
        
        fig1 = plt.gcf()
        self.safe_plot(fig1, 'sales_analysis.png')
        
        # Correlation heatmap
        fig2 = plt.figure(figsize=(15, 12))
        
        # Get numeric columns (exclude non-numeric ones)
        exclude_cols = ['id', 'sale_date', 'day_of_week']
        numeric_cols = [col for col in self.df.columns if col not in exclude_cols and self.df[col].dtype in ['int64', 'float64']]
        
        # Limit to most important features for readability
        if len(numeric_cols) > 30:
            # Select top features by correlation with sales
            sales_corr = self.df[numeric_cols].corr()['sales'].abs().sort_values(ascending=False)
            top_features = sales_corr.head(30).index.tolist()
            numeric_cols = top_features
        
        correlation_matrix = self.df[numeric_cols].corr()
        
        # Create heatmap with better formatting
        mask = np.triu(np.ones_like(correlation_matrix, dtype=bool))
        sns.heatmap(correlation_matrix, mask=mask, annot=False, cmap='coolwarm', center=0, 
                   square=True, fmt='.2f', cbar_kws={'shrink': 0.8})
        plt.title('Feature Correlation Matrix (Top Features)')
        plt.tight_layout()
        self.safe_plot(fig2, 'correlation_matrix.png')
    
    def prepare_features(self):
        """Prepare features for machine learning with advanced preprocessing"""
        print("\nPreparing features for machine learning with advanced preprocessing...")
        
        # Select all engineered features (excluding target and metadata)
        exclude_cols = ['id', 'sale_date', 'day_of_week', 'sales']
        feature_cols = [col for col in self.df.columns if col not in exclude_cols]
        
        X = self.df[feature_cols]
        y = self.df['sales']
        
        # Handle any remaining NaN values
        X = X.fillna(X.median())
        
        # Split the data with time series split
        split_point = int(len(X) * 0.8)
        self.X_train = X.iloc[:split_point]
        self.X_test = X.iloc[split_point:]
        self.y_train = y.iloc[:split_point]
        self.y_test = y.iloc[split_point:]
        
        # Create multiple scalers for different model types
        self.scaler_standard = StandardScaler()
        self.scaler_robust = RobustScaler()
        self.scaler_minmax = MinMaxScaler()
        
        # Scale the features with different methods
        self.X_train_standard = self.scaler_standard.fit_transform(self.X_train)
        self.X_test_standard = self.scaler_standard.transform(self.X_test)
        
        self.X_train_robust = self.scaler_robust.fit_transform(self.X_train)
        self.X_test_robust = self.scaler_robust.transform(self.X_test)
        
        self.X_train_minmax = self.scaler_minmax.fit_transform(self.X_train)
        self.X_test_minmax = self.scaler_minmax.transform(self.X_test)
        
        # For backward compatibility
        self.X_train_scaled = self.X_train_standard
        self.X_test_scaled = self.X_test_standard
        
        print(f"Training set shape: {self.X_train.shape}")
        print(f"Test set shape: {self.X_test.shape}")
        print(f"Number of features: {len(feature_cols)}")
        print(f"Feature names: {feature_cols[:10]}...")  # Show first 10 features
        
        return self.X_train, self.X_test, self.y_train, self.y_test
    
    def train_models(self):
        """Train advanced machine learning models with hyperparameter tuning"""
        print("\n" + "="*50)
        print("TRAINING ADVANCED MACHINE LEARNING MODELS")
        print("="*50)
        
        # Define base models with hyperparameter grids
        models_config = {
            'Ridge Regression': {
                'model': Ridge(),
                'params': {'alpha': [0.01, 0.1, 1.0, 10.0, 100.0]},
                'scaler': 'standard'
            },
            'Lasso Regression': {
                'model': Lasso(),
                'params': {'alpha': [0.001, 0.01, 0.1, 1.0, 10.0]},
                'scaler': 'standard'
            },
            'ElasticNet': {
                'model': ElasticNet(),
                'params': {'alpha': [0.001, 0.01, 0.1, 1.0], 'l1_ratio': [0.1, 0.5, 0.7, 0.9]},
                'scaler': 'standard'
            },
            'Random Forest': {
                'model': RandomForestRegressor(random_state=42),
                'params': {
                    'n_estimators': [200, 300, 500],
                    'max_depth': [10, 20, None],
                    'min_samples_split': [2, 5, 10],
                    'min_samples_leaf': [1, 2, 4]
                },
                'scaler': 'none'
            },
            'Extra Trees': {
                'model': ExtraTreesRegressor(random_state=42),
                'params': {
                    'n_estimators': [200, 300, 500],
                    'max_depth': [10, 20, None],
                    'min_samples_split': [2, 5, 10]
                },
                'scaler': 'none'
            },
            'Gradient Boosting': {
                'model': GradientBoostingRegressor(random_state=42),
                'params': {
                    'n_estimators': [200, 300, 500],
                    'learning_rate': [0.01, 0.05, 0.1],
                    'max_depth': [3, 5, 7],
                    'subsample': [0.8, 0.9, 1.0]
                },
                'scaler': 'none'
            },
            'SVR': {
                'model': SVR(),
                'params': {
                    'C': [0.1, 1, 10, 100],
                    'gamma': ['scale', 'auto', 0.001, 0.01, 0.1],
                    'epsilon': [0.01, 0.1, 0.2]
                },
                'scaler': 'standard'
            },
            'MLP Regressor': {
                'model': MLPRegressor(random_state=42, max_iter=1000),
                'params': {
                    'hidden_layer_sizes': [(100,), (100, 50), (200, 100), (200, 100, 50)],
                    'activation': ['relu', 'tanh'],
                    'alpha': [0.0001, 0.001, 0.01],
                    'learning_rate': ['constant', 'adaptive']
                },
                'scaler': 'minmax'
            },
            'Kernel Ridge': {
                'model': KernelRidge(),
                'params': {
                    'alpha': [0.1, 1.0, 10.0],
                    'kernel': ['rbf', 'polynomial'],
                    'gamma': [0.001, 0.01, 0.1]
                },
                'scaler': 'standard'
            }
        }
        
        # Add XGBoost if available
        if XGBOOST_AVAILABLE:
            models_config['XGBoost'] = {
                'model': xgb.XGBRegressor(random_state=42, n_jobs=-1),
                'params': {
                    'n_estimators': [200, 300, 500],
                    'max_depth': [3, 5, 7],
                    'learning_rate': [0.01, 0.05, 0.1],
                    'subsample': [0.8, 0.9, 1.0],
                    'colsample_bytree': [0.8, 0.9, 1.0]
                },
                'scaler': 'none'
            }
        
        # Add LightGBM if available
        if LIGHTGBM_AVAILABLE:
            models_config['LightGBM'] = {
                'model': lgb.LGBMRegressor(random_state=42, n_jobs=-1, verbose=-1),
                'params': {
                    'n_estimators': [200, 300, 500],
                    'max_depth': [3, 5, 7],
                    'learning_rate': [0.01, 0.05, 0.1],
                    'subsample': [0.8, 0.9, 1.0],
                    'colsample_bytree': [0.8, 0.9, 1.0]
                },
                'scaler': 'none'
            }
        
        # Train and tune models
        for name, config in models_config.items():
            print(f"\nTraining and tuning {name}...")
            
            # Select appropriate scaler
            if config['scaler'] == 'standard':
                X_train_use = self.X_train_standard
                X_test_use = self.X_test_standard
            elif config['scaler'] == 'robust':
                X_train_use = self.X_train_robust
                X_test_use = self.X_test_robust
            elif config['scaler'] == 'minmax':
                X_train_use = self.X_train_minmax
                X_test_use = self.X_test_minmax
            else:  # none
                X_train_use = self.X_train
                X_test_use = self.X_test
            
            # Use TimeSeriesSplit for cross-validation
            tscv = TimeSeriesSplit(n_splits=5)
            
            # Grid search with time series cross-validation
            grid_search = GridSearchCV(
                config['model'], 
                config['params'], 
                cv=tscv, 
                scoring='neg_mean_squared_error',
                n_jobs=-1,
                verbose=0
            )
            
            # Fit the model
            grid_search.fit(X_train_use, self.y_train)
            
            # Get best model and predictions
            best_model = grid_search.best_estimator_
            y_pred = best_model.predict(X_test_use)
            
            # Calculate metrics
            mse = mean_squared_error(self.y_test, y_pred)
            mae = mean_absolute_error(self.y_test, y_pred)
            r2 = r2_score(self.y_test, y_pred)
            rmse = np.sqrt(mse)
            
            # Store results
            self.models[name] = best_model
            self.results[name] = {
                'MSE': mse,
                'MAE': mae,
                'R2': r2,
                'RMSE': rmse,
                'predictions': y_pred,
                'best_params': grid_search.best_params_,
                'cv_score': -grid_search.best_score_
            }
            
            print(f"  Best RMSE: {rmse:.4f}")
            print(f"  Best MAE: {mae:.4f}")
            print(f"  Best R²: {r2:.6f}")
            print(f"  Best params: {grid_search.best_params_}")
        
        # Create ensemble model if we have multiple good models
        self.create_ensemble_model()
    
    def create_ensemble_model(self):
        """Create ensemble models for better performance"""
        print("\n" + "="*50)
        print("CREATING ENSEMBLE MODELS")
        print("="*50)
        
        # Get top 5 models by RMSE
        sorted_models = sorted(self.results.items(), key=lambda x: x[1]['RMSE'])[:5]
        
        if len(sorted_models) < 2:
            print("Not enough models for ensemble. Skipping...")
            return
        
        print(f"Creating ensemble from top {len(sorted_models)} models...")
        
        # Create voting regressor
        estimators = []
        for name, _ in sorted_models:
            estimators.append((name, self.models[name]))
        
        # Voting Regressor
        voting_regressor = VotingRegressor(estimators=estimators)
        voting_regressor.fit(self.X_train, self.y_train)
        voting_pred = voting_regressor.predict(self.X_test)
        
        # Calculate metrics for voting regressor
        voting_mse = mean_squared_error(self.y_test, voting_pred)
        voting_mae = mean_absolute_error(self.y_test, voting_pred)
        voting_r2 = r2_score(self.y_test, voting_pred)
        voting_rmse = np.sqrt(voting_mse)
        
        # Store voting regressor results
        self.models['Voting Ensemble'] = voting_regressor
        self.results['Voting Ensemble'] = {
            'MSE': voting_mse,
            'MAE': voting_mae,
            'R2': voting_r2,
            'RMSE': voting_rmse,
            'predictions': voting_pred,
            'best_params': 'Voting of top models',
            'cv_score': None
        }
        
        print(f"Voting Ensemble RMSE: {voting_rmse:.4f}")
        print(f"Voting Ensemble R²: {voting_r2:.6f}")
        
        # Create stacking regressor if available
        if STACKING_AVAILABLE and len(sorted_models) >= 3:
            print("\nCreating Stacking Regressor...")
            
            # Use top 3 models as base estimators
            base_estimators = [(name, self.models[name]) for name, _ in sorted_models[:3]]
            
            # Use the best single model as final estimator
            best_single_model = sorted_models[0][0]
            final_estimator = self.models[best_single_model]
            
            stacking_regressor = StackingRegressor(
                estimators=base_estimators,
                final_estimator=final_estimator,
                cv=5
            )
            
            stacking_regressor.fit(self.X_train, self.y_train)
            stacking_pred = stacking_regressor.predict(self.X_test)
            
            # Calculate metrics for stacking regressor
            stacking_mse = mean_squared_error(self.y_test, stacking_pred)
            stacking_mae = mean_absolute_error(self.y_test, stacking_pred)
            stacking_r2 = r2_score(self.y_test, stacking_pred)
            stacking_rmse = np.sqrt(stacking_mse)
            
            # Store stacking regressor results
            self.models['Stacking Ensemble'] = stacking_regressor
            self.results['Stacking Ensemble'] = {
                'MSE': stacking_mse,
                'MAE': stacking_mae,
                'R2': stacking_r2,
                'RMSE': stacking_rmse,
                'predictions': stacking_pred,
                'best_params': 'Stacking of top models',
                'cv_score': None
            }
            
            print(f"Stacking Ensemble RMSE: {stacking_rmse:.4f}")
            print(f"Stacking Ensemble R²: {stacking_r2:.6f}")
        
        # Create weighted ensemble based on performance
        self.create_weighted_ensemble(sorted_models)
    
    def create_weighted_ensemble(self, sorted_models):
        """Create a weighted ensemble based on model performance"""
        print("\nCreating Weighted Ensemble...")
        
        # Calculate weights based on inverse RMSE
        weights = []
        models_list = []
        
        for name, results in sorted_models:
            weight = 1.0 / (results['RMSE'] + 1e-8)  # Add small epsilon to avoid division by zero
            weights.append(weight)
            models_list.append(self.models[name])
        
        # Normalize weights
        total_weight = sum(weights)
        weights = [w / total_weight for w in weights]
        
        print(f"Weights: {[f'{w:.3f}' for w in weights]}")
        
        # Create weighted predictions
        weighted_pred = np.zeros(len(self.y_test))
        
        for i, (name, model) in enumerate([(name, self.models[name]) for name, _ in sorted_models]):
            # Use appropriate scaler for each model
            if name in ['Ridge Regression', 'Lasso Regression', 'ElasticNet', 'SVR', 'MLP Regressor', 'Kernel Ridge']:
                if name == 'MLP Regressor':
                    pred = model.predict(self.X_test_minmax)
                else:
                    pred = model.predict(self.X_test_standard)
            else:
                pred = model.predict(self.X_test)
            
            weighted_pred += weights[i] * pred
        
        # Calculate metrics for weighted ensemble
        weighted_mse = mean_squared_error(self.y_test, weighted_pred)
        weighted_mae = mean_absolute_error(self.y_test, weighted_pred)
        weighted_r2 = r2_score(self.y_test, weighted_pred)
        weighted_rmse = np.sqrt(weighted_mse)
        
        # Store weighted ensemble results
        self.models['Weighted Ensemble'] = None  # No single model object
        self.results['Weighted Ensemble'] = {
            'MSE': weighted_mse,
            'MAE': weighted_mae,
            'R2': weighted_r2,
            'RMSE': weighted_rmse,
            'predictions': weighted_pred,
            'best_params': f'Weighted: {weights}',
            'cv_score': None
        }
        
        print(f"Weighted Ensemble RMSE: {weighted_rmse:.4f}")
        print(f"Weighted Ensemble R²: {weighted_r2:.6f}")
    
    def evaluate_models(self):
        """Evaluate and compare model performance"""
        print("\n" + "="*50)
        print("MODEL EVALUATION RESULTS")
        print("="*50)
        
        # Create results DataFrame
        results_df = pd.DataFrame({
            'Model': list(self.results.keys()),
            'RMSE': [self.results[model]['RMSE'] for model in self.results.keys()],
            'MAE': [self.results[model]['MAE'] for model in self.results.keys()],
            'R²': [self.results[model]['R2'] for model in self.results.keys()]
        })
        
        # Sort by RMSE (lower is better)
        results_df = results_df.sort_values('RMSE')
        
        print("\nModel Performance Comparison:")
        print(results_df.to_string(index=False, float_format='%.4f'))
        
        # Plot model comparison
        plt.figure(figsize=(15, 5))
        
        plt.subplot(1, 3, 1)
        plt.bar(results_df['Model'], results_df['RMSE'], color='skyblue')
        plt.title('Model RMSE Comparison')
        plt.ylabel('RMSE')
        plt.xticks(rotation=45)
        
        plt.subplot(1, 3, 2)
        plt.bar(results_df['Model'], results_df['MAE'], color='lightcoral')
        plt.title('Model MAE Comparison')
        plt.ylabel('MAE')
        plt.xticks(rotation=45)
        
        plt.subplot(1, 3, 3)
        plt.bar(results_df['Model'], results_df['R²'], color='lightgreen')
        plt.title('Model R² Comparison')
        plt.ylabel('R² Score')
        plt.xticks(rotation=45)
        
        fig = plt.gcf()
        self.safe_plot(fig, 'model_comparison.png')
        
        return results_df

    def export_best_model_to_onnx(self, onnx_path='assets/models/sales_forecast.onnx', features_path='assets/models/sales_forecast_features.json'):
        """Export the best-performing scaler+model to ONNX, along with feature order.
        This exports a minimal pipeline (scaler where applicable + regressor) that consumes
        the engineered features in the same column order used during training.
        """
        try:
            import json, os
            if not ONNX_EXPORT_AVAILABLE:
                print('ONNX export not available. Install: pip install skl2onnx onnx')
                return False

            # Identify best model by RMSE
            best_name = min(self.results.keys(), key=lambda x: self.results[x]['RMSE'])
            best_model = self.models[best_name]

            # Choose scaler consistent with training
            if best_name in ['Ridge Regression', 'Lasso Regression', 'ElasticNet', 'SVR', 'Kernel Ridge']:
                scaler = self.scaler_standard
                X_train = self.X_train_standard
            elif best_name == 'MLP Regressor':
                scaler = self.scaler_minmax
                X_train = self.X_train_minmax
            else:
                scaler = None
                X_train = self.X_train.values

            # Build a pipeline if scaler exists
            if scaler is not None:
                # We cannot directly export StandardScaler fitted in numpy; we wrap with sklearn Pipeline-like behavior by re-fitting a new scaler to match params
                # However, for consistency, we will export a model that expects already-scaled inputs. To keep things predictable on-device,
                # we instead export WITHOUT scaler and expect Dart to compute raw features and pass them in unscaled.
                # So fall back to raw model export and ensure Dart uses raw feature order.
                initial_type = [('input', FloatTensorType([None, X_train.shape[1]]))]
                onx = convert_sklearn(best_model, initial_types=initial_type, target_opset=15)
            else:
                initial_type = [('input', FloatTensorType([None, self.X_train.shape[1]]))]
                onx = convert_sklearn(best_model, initial_types=initial_type, target_opset=15)

            # Ensure directories
            os.makedirs(os.path.dirname(onnx_path), exist_ok=True)
            with open(onnx_path, 'wb') as f:
                f.write(onx.SerializeToString())

            # Save feature list in order
            feature_cols = [col for col in self.X_train.columns]
            with open(features_path, 'w') as f:
                json.dump(feature_cols, f)

            print(f'Exported ONNX model to {onnx_path}')
            print(f'Exported feature list to {features_path}')
            return True
        except Exception as e:
            print(f'Failed to export ONNX: {e}')
            return False
    
    def feature_importance_analysis(self):
        """Analyze feature importance for tree-based models"""
        print("\n" + "="*50)
        print("FEATURE IMPORTANCE ANALYSIS")
        print("="*50)
        
        try:
            # Get actual feature names from the training data
            feature_names = list(self.X_train.columns)
            print(f"Total features available: {len(feature_names)}")
            
            # Plot feature importance for Random Forest
            if 'Random Forest' in self.models:
                rf_model = self.models['Random Forest']
                importance = rf_model.feature_importances_
                
                plt.figure(figsize=(15, 10))
                indices = np.argsort(importance)[::-1]
                
                # Only show top 20 features to avoid overcrowding
                top_n = min(20, len(importance))
                top_indices = indices[:top_n]
                top_importance = importance[top_indices]
                top_names = [feature_names[i] for i in top_indices]
                
                plt.bar(range(len(top_importance)), top_importance)
                plt.title(f'Random Forest Feature Importance (Top {top_n})')
                plt.xlabel('Features')
                plt.ylabel('Importance')
                plt.xticks(range(len(top_importance)), top_names, rotation=45, ha='right')
                fig = plt.gcf()
                self.safe_plot(fig, 'feature_importance.png')
                
                # Print top features
                print(f"\nTop {min(15, len(importance))} Most Important Features (Random Forest):")
                for i in range(min(15, len(importance))):
                    idx = indices[i]
                    if idx < len(feature_names):  # Safety check
                        print(f"{i+1:2d}. {feature_names[idx]:<25}: {importance[idx]:.6f}")
            
            # Also analyze other tree-based models if available
            tree_models = ['Extra Trees', 'Gradient Boosting', 'XGBoost', 'LightGBM']
            for model_name in tree_models:
                if model_name in self.models:
                    model = self.models[model_name]
                    if hasattr(model, 'feature_importances_'):
                        importance = model.feature_importances_
                        indices = np.argsort(importance)[::-1]
                        
                        print(f"\nTop 10 Most Important Features ({model_name}):")
                        for i in range(min(10, len(importance))):
                            idx = indices[i]
                            if idx < len(feature_names):  # Safety check
                                print(f"{i+1:2d}. {feature_names[idx]:<25}: {importance[idx]:.6f}")
        
        except Exception as e:
            print(f"Error in feature importance analysis: {e}")
            print("Skipping feature importance analysis...")
    
    def plot_actual_vs_predicted(self):
        """Plot actual vs predicted values for all models"""
        print("\n" + "="*50)
        print("ACTUAL VS PREDICTED COMPARISON")
        print("="*50)
        
        # Create subplots for each model
        n_models = len(self.results)
        cols = 3
        rows = (n_models + cols - 1) // cols
        
        plt.figure(figsize=(18, 6 * rows))
        
        for i, (model_name, results) in enumerate(self.results.items()):
            plt.subplot(rows, cols, i + 1)
            
            # Get predictions
            y_pred = results['predictions']
            
            # Create scatter plot
            plt.scatter(self.y_test, y_pred, alpha=0.6, s=50)
            
            # Perfect prediction line
            min_val = min(self.y_test.min(), y_pred.min())
            max_val = max(self.y_test.max(), y_pred.max())
            plt.plot([min_val, max_val], [min_val, max_val], 'r--', linewidth=2, label='Perfect Prediction')
            
            # Calculate R² for this plot
            r2 = results['R2']
            rmse = results['RMSE']
            
            plt.xlabel('Actual Sales')
            plt.ylabel('Predicted Sales')
            plt.title(f'{model_name}\nR² = {r2:.4f}, RMSE = {rmse:.2f}')
            plt.legend()
            plt.grid(True, alpha=0.3)
        
        fig = plt.gcf()
        self.safe_plot(fig, 'actual_vs_predicted.png')
        
        # Create a comprehensive time series plot
        self.plot_time_series_comparison()
    
    def plot_time_series_comparison(self):
        """Plot time series comparison of actual vs predicted"""
        print("\nPlotting time series comparison...")
        
        # Get test dates (last 20% of data)
        test_size = len(self.y_test)
        test_dates = self.df['sale_date'].iloc[-test_size:]
        
        # Create figure with subplots for top 3 models
        top_models = sorted(self.results.items(), key=lambda x: x[1]['RMSE'])[:3]
        
        plt.figure(figsize=(20, 12))
        
        for i, (model_name, results) in enumerate(top_models):
            plt.subplot(3, 1, i + 1)
            
            # Plot actual values
            plt.plot(test_dates, self.y_test.values, label='Actual Sales', 
                    color='blue', linewidth=2, alpha=0.8)
            
            # Plot predicted values
            plt.plot(test_dates, results['predictions'], label='Predicted Sales', 
                    color='red', linewidth=2, alpha=0.8, linestyle='--')
            
            # Add error bars (difference between actual and predicted)
            errors = np.abs(self.y_test.values - results['predictions'])
            plt.fill_between(test_dates, 
                           self.y_test.values - errors, 
                           self.y_test.values + errors, 
                           alpha=0.2, color='gray', label='Prediction Error')
            
            plt.title(f'{model_name} - Time Series Comparison (RMSE: {results["RMSE"]:.2f})')
            plt.xlabel('Date')
            plt.ylabel('Sales')
            plt.legend()
            plt.grid(True, alpha=0.3)
            plt.xticks(rotation=45)
        
        fig = plt.gcf()
        self.safe_plot(fig, 'time_series_comparison.png')
        
        # Create residual plots
        self.plot_residuals()
    
    def plot_residuals(self):
        """Plot residuals for model evaluation"""
        print("\nPlotting residual analysis...")
        
        # Get top 3 models
        top_models = sorted(self.results.items(), key=lambda x: x[1]['RMSE'])[:3]
        
        plt.figure(figsize=(18, 6))
        
        for i, (model_name, results) in enumerate(top_models):
            plt.subplot(1, 3, i + 1)
            
            # Calculate residuals
            residuals = self.y_test.values - results['predictions']
            
            # Plot residuals
            plt.scatter(results['predictions'], residuals, alpha=0.6, s=50)
            plt.axhline(y=0, color='r', linestyle='--', linewidth=2)
            
            plt.xlabel('Predicted Sales')
            plt.ylabel('Residuals (Actual - Predicted)')
            plt.title(f'{model_name} - Residual Plot')
            plt.grid(True, alpha=0.3)
        
        fig = plt.gcf()
        self.safe_plot(fig, 'residual_analysis.png')
    
    def predict_future_sales(self, days_ahead=30):
        """Make predictions for future sales using full feature set and proper scaling"""
        print(f"\n" + "="*50)
        print(f"PREDICTING FUTURE SALES ({days_ahead} days ahead)")
        print("="*50)
        
        # Choose best model
        best_model_name = min(self.results.keys(), key=lambda x: self.results[x]['RMSE'])
        best_model = self.models[best_model_name]
        print(f"Using best model: {best_model_name}")
        
        # Determine scaler used for this model
        def select_scaler_for_model(name: str):
            if name in ['Ridge Regression', 'Lasso Regression', 'ElasticNet', 'SVR', 'Kernel Ridge']:
                return self.scaler_standard
            if name == 'MLP Regressor':
                return self.scaler_minmax
            return None
        scaler = select_scaler_for_model(best_model_name)
        
        # Prepare future dates
        last_date = self.df['sale_date'].max()
        future_dates = pd.date_range(start=last_date + pd.Timedelta(days=1), periods=days_ahead)
        
        # Start from the last available feature row
        feature_cols = list(self.X_train.columns)
        last_row_features = self.df.iloc[-1][feature_cols].copy()
        last_known_sales = float(self.df.iloc[-1]['sales'])
        
        predictions = []
        rolling_window_7 = list(self.df['sales'].iloc[-7:])
        rolling_window_30 = list(self.df['sales'].iloc[-30:]) if len(self.df) >= 30 else list(self.df['sales'].tolist())
        
        for i, future_date in enumerate(future_dates):
            future_feat = last_row_features.copy()
            
            # Update calendar features
            future_feat['month'] = future_date.month
            future_feat['day'] = future_date.day
            future_feat['quarter'] = future_date.quarter
            future_feat['weekday'] = future_date.weekday()
            future_feat['week_of_year'] = future_date.isocalendar().week
            future_feat['day_of_year'] = future_date.timetuple().tm_yday
            future_feat['is_weekend'] = 1 if future_date.weekday() >= 5 else 0
            future_feat['is_month_start'] = 1 if future_date.day == 1 else 0
            # month end approx (safe for our purpose)
            next_day = future_date + pd.Timedelta(days=1)
            future_feat['is_month_end'] = 1 if next_day.month != future_date.month else 0
            future_feat['is_quarter_start'] = 1 if future_date.month in [1, 4, 7, 10] and future_date.day == 1 else 0
            future_feat['is_quarter_end'] = 1 if future_date.month in [3, 6, 9, 12] and future_date.day in [30, 31] else 0
            
            # Update encoded/cyclical features
            future_feat['day_of_week_encoded'] = future_date.weekday()
            future_feat['month_sin'] = np.sin(2 * np.pi * future_date.month / 12)
            future_feat['month_cos'] = np.cos(2 * np.pi * future_date.month / 12)
            future_feat['day_sin'] = np.sin(2 * np.pi * future_date.day / 31)
            future_feat['day_cos'] = np.cos(2 * np.pi * future_date.day / 31)
            future_feat['weekday_sin'] = np.sin(2 * np.pi * future_date.weekday() / 7)
            future_feat['weekday_cos'] = np.cos(2 * np.pi * future_date.weekday() / 7)
            future_feat['quarter_sin'] = np.sin(2 * np.pi * future_feat['quarter'] / 4)
            future_feat['quarter_cos'] = np.cos(2 * np.pi * future_feat['quarter'] / 4)
            future_feat['week_sin'] = np.sin(2 * np.pi * float(future_feat['week_of_year']) / 52)
            future_feat['week_cos'] = np.cos(2 * np.pi * float(future_feat['week_of_year']) / 52)
            
            # Update lag features using last known/predicted sales
            future_feat['sales_lag1'] = last_known_sales
            if 'sales_lag2' in future_feat:
                # Approximate shift for additional lags
                future_feat['sales_lag2'] = rolling_window_7[-2] if len(rolling_window_7) >= 2 else last_known_sales
            if 'sales_lag3' in future_feat:
                future_feat['sales_lag3'] = rolling_window_7[-3] if len(rolling_window_7) >= 3 else last_known_sales
            if 'sales_lag7' in future_feat:
                future_feat['sales_lag7'] = rolling_window_7[0] if len(rolling_window_7) == 7 else last_known_sales
            if 'sales_lag14' in future_feat:
                future_feat['sales_lag14'] = rolling_window_30[-14] if len(rolling_window_30) >= 14 else last_known_sales
            if 'sales_lag21' in future_feat:
                future_feat['sales_lag21'] = rolling_window_30[-21] if len(rolling_window_30) >= 21 else last_known_sales
            if 'sales_lag30' in future_feat:
                future_feat['sales_lag30'] = rolling_window_30[0] if len(rolling_window_30) >= 30 else last_known_sales
            
            # Rolling stats based on available rolling windows
            if 'sales_ma7' in feature_cols:
                future_feat['sales_ma7'] = float(np.mean(rolling_window_7))
            if 'sales_ma14' in feature_cols:
                window14 = rolling_window_30[-14:] if len(rolling_window_30) >= 14 else rolling_window_30
                future_feat['sales_ma14'] = float(np.mean(window14))
            if 'sales_ma21' in feature_cols:
                window21 = rolling_window_30[-21:] if len(rolling_window_30) >= 21 else rolling_window_30
                future_feat['sales_ma21'] = float(np.mean(window21))
            if 'sales_ma30' in feature_cols:
                future_feat['sales_ma30'] = float(np.mean(rolling_window_30))
            if 'sales_std7' in feature_cols:
                future_feat['sales_std7'] = float(np.std(rolling_window_7, ddof=1)) if len(rolling_window_7) > 1 else 0.0
            if 'sales_std30' in feature_cols:
                future_feat['sales_std30'] = float(np.std(rolling_window_30, ddof=1)) if len(rolling_window_30) > 1 else 0.0
            
            # Polynomial helpers
            if 'month_squared' in feature_cols:
                future_feat['month_squared'] = future_feat['month'] ** 2
            if 'weekday_squared' in feature_cols:
                future_feat['weekday_squared'] = future_feat['weekday'] ** 2
            if 'day_squared' in feature_cols:
                future_feat['day_squared'] = future_feat['day'] ** 2
            
            # Ratios/volatility use last known averages
            if 'sales_to_ma7_ratio' in feature_cols and 'sales_ma7' in feature_cols:
                future_feat['sales_to_ma7_ratio'] = last_known_sales / (future_feat['sales_ma7'] + 1e-8)
            if 'sales_to_ma30_ratio' in feature_cols and 'sales_ma30' in feature_cols:
                future_feat['sales_to_ma30_ratio'] = last_known_sales / (future_feat['sales_ma30'] + 1e-8)
            if 'ma7_to_ma30_ratio' in feature_cols and 'sales_ma7' in feature_cols and 'sales_ma30' in feature_cols:
                future_feat['ma7_to_ma30_ratio'] = future_feat['sales_ma7'] / (future_feat['sales_ma30'] + 1e-8)
            if 'sales_volatility_7' in feature_cols and 'sales_ma7' in feature_cols:
                future_feat['sales_volatility_7'] = (float(np.std(rolling_window_7, ddof=1)) / (future_feat['sales_ma7'] + 1e-8)) if len(rolling_window_7) > 1 else 0.0
            if 'sales_volatility_30' in feature_cols and 'sales_ma30' in feature_cols:
                future_feat['sales_volatility_30'] = (float(np.std(rolling_window_30, ddof=1)) / (future_feat['sales_ma30'] + 1e-8)) if len(rolling_window_30) > 1 else 0.0
            if 'sales_detrended' in feature_cols and 'sales_ma30' in feature_cols:
                future_feat['sales_detrended'] = last_known_sales - future_feat['sales_ma30']
            
            # Ensure order matches training columns
            future_row_df = pd.DataFrame([future_feat.values], columns=feature_cols)
            
            # Scale if needed
            if scaler is not None:
                X_future = scaler.transform(future_row_df)
            else:
                X_future = future_row_df.values
            
            # Predict
            pred = float(best_model.predict(X_future)[0])
            predictions.append(pred)
            
            # Update rolling windows for next step
            last_known_sales = pred
            rolling_window_7.append(pred)
            if len(rolling_window_7) > 7:
                rolling_window_7.pop(0)
            rolling_window_30.append(pred)
            if len(rolling_window_30) > 30:
                rolling_window_30.pop(0)
            
            # Carry forward for next iteration
            last_row_features = future_feat
        
        future_df = pd.DataFrame({'date': future_dates, 'predicted_sales': predictions})
        
        # Plot
        plt.figure(figsize=(15, 6))
        plt.plot(self.df['sale_date'][-100:], self.df['sales'][-100:], label='Historical Sales', color='blue', alpha=0.7)
        plt.plot(future_df['date'], future_df['predicted_sales'], label='Predicted Sales', color='red', linestyle='--', linewidth=2)
        plt.title(f'Future Sales Predictions ({days_ahead} days ahead)')
        plt.xlabel('Date')
        plt.ylabel('Sales')
        plt.legend()
        plt.xticks(rotation=45)
        fig = plt.gcf()
        self.safe_plot(fig, 'future_predictions.png')
        
        print(f"\nPredicted sales for the next {days_ahead} days:")
        print(future_df.to_string(index=False, float_format='%.2f'))
        return future_df
    
    def run_complete_analysis(self):
        """Run the complete machine learning analysis"""
        print("SALES MACHINE LEARNING ANALYSIS")
        print("="*50)
        
        # Load and preprocess data
        self.load_and_preprocess_data()
        
        # Explore data
        self.explore_data()
        
        # Prepare features
        self.prepare_features()
        
        # Train models
        self.train_models()
        
        # Evaluate models
        results_df = self.evaluate_models()
        
        # Plot actual vs predicted comparisons
        self.plot_actual_vs_predicted()
        
        # Feature importance analysis
        self.feature_importance_analysis()
        
        # Make future predictions
        future_predictions = self.predict_future_sales()

        # Export best model for on-device inference
        self.export_best_model_to_onnx()
        
        print("\n" + "="*50)
        print("ANALYSIS COMPLETE!")
        print("="*50)
        
        return results_df, future_predictions

def main():
    """Main function to run the analysis"""
    # Initialize the analyzer
    analyzer = SalesMLAnalyzer('mach_l-try1.csv')
    
    # Run complete analysis
    results, predictions = analyzer.run_complete_analysis()
    
    return analyzer, results, predictions

if __name__ == "__main__":
    analyzer, results, predictions = main()
