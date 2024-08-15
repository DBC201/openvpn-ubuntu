#!/bin/bash

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run this script as root (using sudo)"
  exit 1
fi

echo "Enter username:"
read username

adduser $username
