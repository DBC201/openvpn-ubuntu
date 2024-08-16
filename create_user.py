#!/usr/bin/env python3
import sys
import sqlite3
import bcrypt

# Path to your SQLite database
DB_PATH = '/etc/openvpn/users.db'

def create_user(username, password):
    # Connect to the SQLite database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Hash the password using bcrypt
    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    try:
        # Insert the user into the database
        cursor.execute("INSERT INTO users (username, password) VALUES (?, ?)", (username, hashed_password))
        conn.commit()
        print(f"User {username} added successfully.")
    except sqlite3.IntegrityError:
        print(f"User {username} already exists.")
    finally:
        # Close the database connection
        conn.close()

def main():
    if len(sys.argv) != 3:
        print("Usage: create_user.py <username> <password>")
        sys.exit(1)

    username = sys.argv[1]
    password = sys.argv[2]

    create_user(username, password)

if __name__ == "__main__":
    main()
