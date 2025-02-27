#!/bin/bash

# Define the correct OUI file location for arp-scan
OUI_FILE="/usr/share/arp-scan/ieee-oui.txt"

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check if arp-scan is installed
if ! check_command "arp-scan"; then
    echo "ERROR: 'arp-scan' is not installed. Please install it using your package manager:"
    echo " - Debian/Ubuntu: sudo apt install arp-scan"
    echo " - Arch Linux: sudo pacman -S arp-scan"
    echo " - CentOS/RHEL: sudo yum install arp-scan"
    exit 1
fi

# Check if the OUI database file exists
if [ ! -f "$OUI_FILE" ]; then
    echo "ERROR: OUI file not found at $OUI_FILE"
    echo "Please ensure 'arp-scan' is correctly installed and includes the OUI database."
    exit 1
fi

# Run arp-scan to actively scan the network
echo "Scanning network using arp-scan (requires sudo)..."
sudo arp-scan --localnet --ouifile="$OUI_FILE" > /tmp/arp_scan_results.txt

# Display header
echo -e "\n---------------------------------------------"
echo -e "  IP Address   |      MAC Address     |  Vendor"
echo -e "---------------------------------------------"

# Parse arp-scan output and extract IP, MAC, and Vendor
grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" /tmp/arp_scan_results.txt | while read -r ip mac vendor; do
    if [[ "$mac" =~ ([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2} ]]; then
        # If vendor is missing, mark it as unknown
        vendor=${vendor:-"Unknown Vendor"}
        echo -e "$ip\t$mac\t$vendor"
    fi
done

echo -e "\n---------------------------------------------"
echo "OUI Lookup Complete."
echo "---------------------------------------------"
