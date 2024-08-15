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

cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa

./easyrsa init-pki
./easyrsa build-ca

./easyrsa gen-req server nopass
./easyrsa sign-req server server

./easyrsa gen-dh

openvpn --genkey --secret ta.key

cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem ta.key /etc/openvpn/

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

# Use PAM authentication for username/password
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
verify-client-cert none
username-as-common-name
EOF


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

apt install iptables-persistent
netfilter-persistent save

systemctl start openvpn@server
systemctl enable openvpn@server

