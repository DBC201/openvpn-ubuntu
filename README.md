Here's a detailed setup guide for configuring OpenVPN on Ubuntu, using only the server certificate and username/password authentication for clients. This guide will walk you through the entire process from installing the necessary software to configuring both the server and client.

### **Step 1: Install OpenVPN and Easy-RSA**

First, ensure your system is up to date and then install OpenVPN and Easy-RSA:

```bash
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install openvpn easy-rsa
```

### **Step 2: Set Up the Certificate Authority (CA) and Server Certificate**

1. **Copy Easy-RSA to a Working Directory:**

   It's recommended to copy the Easy-RSA directory to another location:

   ```bash
   cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
   cd /etc/openvpn/easy-rsa
   ```

2. **Configure the `vars` File:**

   Rename the `vars.example` file to `vars` and edit it:

   ```bash
   mv vars.example vars
   nano vars
   ```

   Uncomment and set the following values in the `vars` file:

   ```bash
   set_var EASYRSA_REQ_COUNTRY     "US"
   set_var EASYRSA_REQ_PROVINCE    "California"
   set_var EASYRSA_REQ_CITY        "San Francisco"
   set_var EASYRSA_REQ_ORG         "My Organization"
   set_var EASYRSA_REQ_OU          "IT Department"
   set_var EASYRSA_REQ_EMAIL       "admin@mydomain.com"
   set_var EASYRSA_REQ_CN          "My VPN Server"
   set_var EASYRSA_KEY_SIZE        2048
   set_var EASYRSA_CA_EXPIRE       3650
   set_var EASYRSA_CERT_EXPIRE     1080
   ```

   Save and exit the file.

3. **Initialize the PKI Environment:**

   ```bash
   ./easyrsa init-pki
   ```

4. **Build the CA:**

   ```bash
   ./easyrsa build-ca
   ```

   You'll be prompted to enter a passphrase for the CA and confirm the default values set in the `vars` file.

5. **Generate the Server Certificate and Key:**

   ```bash
   ./easyrsa gen-req server nopass
   ./easyrsa sign-req server server
   ```

   The `nopass` option creates the private key without a passphrase, which is necessary for the OpenVPN server to start automatically.

6. **Generate the Diffie-Hellman Parameters:**

   ```bash
   ./easyrsa gen-dh
   ```

7. **Generate the HMAC Key for TLS Authentication:**

   ```bash
   openvpn --genkey --secret ta.key
   ```

8. **Copy the Necessary Files to the OpenVPN Directory:**

   ```bash
   cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem ta.key /etc/openvpn/
   ```

### **Step 3: Configure the OpenVPN Server**

1. Create server.conf

2. **Enable IP Forwarding:**

   Edit the `sysctl.conf` file to enable IP forwarding:

   ```bash
   sudo nano /etc/sysctl.conf
   ```

   Uncomment the following line:

   ```bash
   net.ipv4.ip_forward=1
   ```

   Apply the changes:

   ```bash
   sudo sysctl -p
   ```

### **Step 4: Configure the Firewall**

```sudo iptables -I INPUT -p udp --dport 1194 -j ACCEPT```

Enable IP Masquerading:

If you need to allow VPN clients to route through the server:

```sudo iptables -t nat -I POSTROUTING -s 10.31.69.0/24 -o eth0 -j MASQUERADE```

Adjust eth0 to the name of your network interface if it's different.

```sudo iptables -I FORWARD -s 10.31.69.0/24 -j ACCEPT```
```sudo iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT```


Save the iptables Rules:

To ensure that these rules persist across reboots, you’ll need to save them:
```sudo apt install iptables-persistent```
```sudo netfilter-persistent save```


### **Step 5: Start and Enable the OpenVPN Service**

1. **Start the OpenVPN Service:**

   ```bash
   sudo systemctl start openvpn@server
   ```

2. **Enable OpenVPN to Start on Boot:**

   ```bash
   sudo systemctl enable openvpn@server
   ```

### **Step 6: Configure the Client**

For each client, you will create a configuration file that only uses the server certificate, HMAC key, and username/password for authentication.

1. **Create a Client Configuration File:**

   On your local machine or server:

   ```bash
   nano client.ovpn
   ```

2. **Populate the Client Configuration File:**

   ```bash
   client
   dev tun
   proto udp
   remote YOUR_SERVER_IP 1194
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

   <ca>
   -----BEGIN CERTIFICATE-----
   # Paste the contents of the ca.crt file here
   -----END CERTIFICATE-----
   </ca>

   <tls-auth>
   -----BEGIN OpenVPN Static key V1-----
   # Paste the contents of the ta.key file here
   -----END OpenVPN Static key V1-----
   </tls-auth>
   ```

   Replace `YOUR_SERVER_IP` with the public IP address or domain name of your server.

3. **Transfer the `client.ovpn` File to the Client Device:**

   Use a secure method (e.g., SCP, email, USB) to transfer the `client.ovpn` file to the client device.

### **Step 7: Create Users on the VPN Server**

1. **Create a New User:**

   Use the `adduser` command to create a new user on the VPN server:

   ```bash
   sudo adduser username
   ```

   Set a strong password when prompted.

2. **Client Authentication:**

   The client will authenticate using the username and password you set when they connect to the VPN using the `client.ovpn` file.

### **Step 8: Connecting with the Client**

1. **Install the OpenVPN Client:**

   On the client device, install the OpenVPN client (e.g., OpenVPN Connect for mobile or the OpenVPN package on another Linux machine).

2. **Import the Configuration File:**

   Import the `client.ovpn` file into the OpenVPN client application.

3. **Connect to the VPN:**

   The client will be prompted for a username and password upon connecting. Use the credentials of the Linux user account created earlier.

### **Security Considerations**

- **Strong Passwords:** Ensure that all users have strong passwords to prevent unauthorized access.
- **Firewall Configuration:** Properly configure the firewall to restrict access to only necessary resources.
- **Regular Audits:** Regularly audit user accounts and access logs to ensure that no unauthorized users are accessing the VPN.

### **Summary**

This setup allows you to authenticate VPN clients using only the server certificate and a username/password combination, simplifying client management while maintaining strong security through TLS/SSL encryption.