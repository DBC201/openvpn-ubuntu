#!/bin/bash

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run this script as root (using sudo)"
  exit 1
fi

apt-get update
apt-get upgrade
apt-get install openvpn easy-rsa

mkdir -p /etc/openvpn/easy-rsa

cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

./easyrsa init-pki
./easyrsa build-ca

./easyrsa gen-req server nopass
./easyrsa sign-req server server

./easyrsa gen-dh

openvpn --genkey --secret ta.key

cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem ta.key /etc/openvpn/

cd ..

apt-get install python3
apt-get install python3-pip
apt-get install sqlite3

sqlite3 /etc/openvpn/users.db <<EOF
CREATE TABLE users (
    username TEXT PRIMARY KEY,
    password TEXT
);
EOF

pip3 install bcrypt

cat <<EOF > ./auth.py
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
EOF

chmod +x auth.py

cat <<EOF > ./server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA256
tls-auth ta.key 0
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
mode server
tls-server
key-direction 0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"

server 10.31.69.0 255.255.255.0

verify-client-cert none
username-as-common-name

# Use PAM authentication for username/password
#plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login

auth-user-pass-verify /etc/openvpn/auth.py via-file
script-security 3
EOF

cat <<EOF > ./create_user.py
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
        cursor.execute("INSERT INTO users (username, password) VALUES (?, ?)", (username, hashed_password.decode('utf-8')))
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
EOF

chmod +x ./create_user.py

echo "Uncomment the following line: net.ipv4.ip_forward=1"
echo "Press Enter to open the file and continue editing..."
read  # Waits for the user to press Enter

vi /etc/sysctl.conf

sysctl -p

iptables -I INPUT -p udp --dport 1194 -j ACCEPT

ip a
echo "Please enter the NIC card you use for the external network:"
read nic  # This will store the user's input in the variable 'nic'

iptables -t nat -I POSTROUTING -s 10.31.69.0/24 -o $nic -j MASQUERADE

iptables -I FORWARD -s 10.31.69.0/24 -j ACCEPT
iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

apt-get install iptables-persistent
netfilter-persistent save

systemctl start openvpn@server
systemctl enable openvpn@server

