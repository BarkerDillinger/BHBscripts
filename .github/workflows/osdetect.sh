#!/bin/bash

# Check for root privileges
if [[ "${EUID}" -ne 0 ]]; then
    echo "The Nmap OS detection scan type (-O) requires root privileges."
    exit 1
fi

# Check if arguments are provided
if [[ "$#" -eq 0 ]]; then
    echo "You must pass one or more IP addresses or ranges."
    echo "Error: No IP address or range provided."
    echo "Usage: $0 <IP_ADDRESS_1> [<IP_ADDRESS_2> ... <IP_ADDRESS_N>]"
    echo "Example: $0 192.168.1.1 192.168.1.0/24 10.0.0.1"
    exit 1
fi

# Store IP addresses in an array
IP_ADDRESSES=("$@")

echo "Running an OS Detection Scan against the following hosts:"
for ip in "${IP_ADDRESSES[@]}"; do
    echo " - $ip"
done

# Loop through the array and perform scans
for HOST in "${IP_ADDRESSES[@]}"; do
    echo "Scanning ${HOST}..."
    nmap_scan=$(sudo nmap -O "${HOST}" -oG -)

    while read -r line; do
        ip=$(echo "${line}" | awk '{print $2}')
        os=$(echo "${line}" | grep -oP '(?<=OS: ).*?(?= Seq)' | sed 's/Seq.*//g')

        if [[ -n "${ip}" ]] && [[ -n "${os}" ]]; then
            echo "IP: ${ip}"
            echo "OS: ${os}"
        fi
    done <<< "${nmap_scan}"
done
