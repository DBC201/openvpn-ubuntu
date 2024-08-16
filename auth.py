#!/usr/bin/env python3
import sys
import sqlite3
import bcrypt

# Path to your SQLite database
DB_PATH = '/etc/openvpn/users.db'

def authenticate(username, password):
    # Connect to the SQLite database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Query for the user's hashed password
    cursor.execute("SELECT password FROM users WHERE username = ?", (username,))
    result = cursor.fetchone()

    # Close the database connection
    conn.close()

    # If the user exists and the password matches the hashed password
    if result:
        stored_hash = result[0]
        if bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8')):
            return True

    return False

def main():
    # OpenVPN passes the credentials via a file
    with open(sys.argv[1], 'r') as f:
        username = f.readline().strip()
        password = f.readline().strip()

    if authenticate(username, password):
        sys.exit(0)  # Authentication successful
    else:
        sys.exit(1)  # Authentication failed

if __name__ == "__main__":
    main()
