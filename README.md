# openvpn-ubuntu

Set up a connection to your ubuntu server using OpenVPN.

## Installing OpenVPN Server on Ubuntu
Simply run ```sudo ./setup.sh```.

This script will prompt the user twice, once for commenting ```net.ipv4.ip_forward=1``` in ```/etc/sysctl.conf``` and once for selecting the network interface card.

## Adding User Accounts
Run ```sudo python3 create_user.py <username> <password>```.
This will create a new user account with the specified username and password. The username and password will be used to authenticate the user when they connect to the VPN server.

## Creating Client Configuration File
Run ```sudo ./client.sh```.

This creates your client configuration file. It will output the path where it's created at.
Send this to the client machine you want to connect to vpn from and import it with the OpenVPN's client application. The client applications can be found [here](https://openvpn.net/client/). For android and iOS, you can use the official OpenVPN app from the Play Store and App Store respectively.
