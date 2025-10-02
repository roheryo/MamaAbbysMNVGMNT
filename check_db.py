import sqlite3
import pandas as pd

def check_db():
    try:
        conn = sqlite3.connect('.dart_tool/sqflite_common_ffi/databases/app.db')
        
        # Get table schema
        cursor = conn.execute('SELECT sql FROM sqlite_master WHERE type="table" AND name="store_sales"')
        schema = cursor.fetchone()
        print("\nTable Schema:")
        print(schema[0] if schema else "Table not found")
        
        # Get a sample of data
        try:
            df = pd.read_sql_query("SELECT * FROM store_sales LIMIT 5", conn)
            print("\nColumns in the table:")
            print(df.columns.tolist())
            print("\nSample data:")
            print(df)
        except Exception as e:
            print(f"Error reading data: {e}")
            
        conn.close()
        
    except Exception as e:
        print(f"Error accessing database: {e}")

if __name__ == "__main__":
    check_db()