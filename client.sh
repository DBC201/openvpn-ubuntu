#!/bin/bash

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run this script as root (using sudo)"
  exit 1
fi

cd /etc/openvpn

echo "Enter public ip:"
read public_ip

cat <<EOF > ./client.ovpn
client
dev tun
proto udp
remote $public_ip 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-CBC
key-direction 1
auth-user-pass
verb 3
auth-nocache
block-outside-dns

<ca>
$(cat ./ca.crt)
</ca>

<tls-auth>
$(cat ./ta.key)
</tls-auth>
EOF

echo "client.ovpn created sucessfully at $(pwd)/client.ovpn"

