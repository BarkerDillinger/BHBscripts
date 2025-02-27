#!/bin/bash

# Get the system's primary IP address
IP_ADDR=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

# Get the system's default gateway
GATEWAY=$(ip route | grep default | awk '{print $3}')

# Define public IP and FQDN for testing
PUBLIC_IP="1.1.1.1"  # Cloudflare DNS (alternative: 8.8.8.8 for Google DNS)
FQDN="cloudflare.com"     # Fully Qualified Domain Name for DNS resolution

echo "--------------------------------------"
echo "   Network Connectivity Diagnostics   "
echo "--------------------------------------"

# Rule 1: Ping the loopback address (127.0.0.1)
echo -e "\n[1] Testing Loopback Address (127.0.0.1)"
ping -c 4 127.0.0.1

# Rule 2: Ping the local system's IP address
if [[ -n "$IP_ADDR" ]]; then
    echo -e "\n[2] Testing Local Interface ($IP_ADDR)"
    ping -c 4 "$IP_ADDR"
else
    echo -e "\n[2] ERROR: Could not determine local IP address!"
fi

# Rule 3: Ping the default gateway
if [[ -n "$GATEWAY" ]]; then
    echo -e "\n[3] Testing Default Gateway ($GATEWAY)"
    ping -c 4 "$GATEWAY"
else
    echo -e "\n[3] ERROR: Could not determine default gateway!"
fi

# Rule 4: Ping a public internet IP address
echo -e "\n[4] Testing Internet Connectivity ($PUBLIC_IP)"
ping -c 4 "$PUBLIC_IP"

# Rule 5: Ping a Fully Qualified Domain Name (FQDN)
echo -e "\n[5] Testing DNS Resolution ($FQDN)"
ping -c 4 "$FQDN"

echo -e "\n--------------------------------------"
echo "   Diagnostics Complete   "
echo "--------------------------------------"
