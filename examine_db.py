import sqlite3
import os

# Check if database exists
db_path = '.dart_tool/sqflite_common_ffi/databases/app.db'
if os.path.exists(db_path):
    print(f"Database found at: {db_path}")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get table schema
    cursor.execute('PRAGMA table_info(store_sales)')
    print('\nStore Sales Table Schema:')
    for row in cursor.fetchall():
        print(row)
    
    # Get record count
    cursor.execute('SELECT COUNT(*) FROM store_sales')
    count = cursor.fetchone()[0]
    print(f'\nTotal records: {count}')
    
    # Get sample data
    cursor.execute('SELECT * FROM store_sales LIMIT 5')
    print('\nSample data:')
    for row in cursor.fetchall():
        print(row)
    
    # Get date range
    cursor.execute('SELECT MIN(sale_date), MAX(sale_date) FROM store_sales')
    date_range = cursor.fetchone()
    print(f'\nDate range: {date_range[0]} to {date_range[1]}')
    
    conn.close()
else:
    print(f"Database not found at: {db_path}")
    print("Available files in .dart_tool directory:")
    if os.path.exists('.dart_tool'):
        for root, dirs, files in os.walk('.dart_tool'):
            for file in files:
                if file.endswith('.db'):
                    print(f"  {os.path.join(root, file)}")
    else:
        print("  .dart_tool directory not found")
