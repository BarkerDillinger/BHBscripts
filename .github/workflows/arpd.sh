#!/bin/bash

# Function to extract all IP addresses from the system
get_local_ips() {
    echo "Local IP Addresses Assigned to Interfaces:"
    ip addr show | awk '/inet / {print $2}' | column -t
    echo ""
}

# Function to retrieve ARP table and match MACs with IEEE OUI database
get_arp_table_with_vendor() {
    local ieee_oui_file="/usr/share/arp-scan/ieee-oui.txt"

    if [[ ! -f "$ieee_oui_file" ]]; then
        echo "ERROR: IEEE OUI file not found at $ieee_oui_file"
        exit 1
    fi

    echo "Discovered Devices:"
    echo "IP Address        MAC Address        Vendor"
    echo "-----------------------------------------------------"

    arp -a | awk '{print $2, $4}' | sed 's/[()]//g' | while read -r ip mac; do
        if [[ "$mac" == "<incomplete>" || "$mac" == "00:00:00:00:00:00" ]]; then
            continue
        fi

        oui_prefix=$(echo "$mac" | awk -F: '{print toupper($1$2$3)}')
        vendor=$(grep -i "^$oui_prefix" "$ieee_oui_file" | awk -F'\t' '{print $2}' | sed 's/^ *//g')

        if [[ -z "$vendor" ]]; then
            vendor="Unknown"
        fi

        printf "%-16s %-17s %s\n" "$ip" "$mac" "$vendor"
    done
}

# Run the functions
get_local_ips
get_arp_table_with_vendor
