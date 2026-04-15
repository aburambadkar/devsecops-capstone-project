from flask import Flask, jsonify, render_template
import mysql.connector
import os

app = Flask(__name__)

def get_db_connection():
    
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", "password"),
        database=os.getenv("DB_NAME", "inventory")
    )

@app.route('/')
def index():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT name, category FROM tools")
        tools = cursor.fetchall()
        cursor.close()
        conn.close()
        return render_template("index.html", tools=tools)
    except Exception as e:
        return f"Database Connection Error: {str(e)}", 500

@app.route('/health')
def health():
   
    return jsonify({"status": "up"}), 200

if __name__ == '__main__':
   
    app.run(host='0.0.0.0', port=5000) # nosec B104
