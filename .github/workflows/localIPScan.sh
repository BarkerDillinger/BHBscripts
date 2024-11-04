#!/bin/bash

# Function to display help
function show_help() {
    echo "Usage: $0 [output_file] [--fast]"
    echo
    echo "   output_file : Specify the output file to save the results."
    echo "                 Default is IP_Add_Local.txt."
    echo "   --fast      : Enable fast mode to speed up the ping sweep."
    echo
    echo "This script scans all directly connected network segments and verifies live hosts."
}

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Check for help flag
if [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Define the output file
output_file="${1:-IP_Add_Local.txt}"

# Clear the output file if it exists
> "$output_file"

# Get the list of all connected interfaces
interfaces=$(ip -o -f inet addr show | awk '{print $2}')

# Perform ping sweep for each interface
for iface in $interfaces; do
    # Skip the loopback interface
    if [ "$iface" == "lo" ]; then
        continue
    fi

    # Get the network address and netmask
    network=$(ip -o -f inet addr show $iface | awk '{print $4}')
    
    # Extract the base network address (CIDR notation)
    base_network=$(echo $network | cut -d '/' -f 1)

    # Remove the final octet to prepare for the ping sweep
    base_ip=$(echo $base_network | awk -F. '{print $1 "." $2 "." $3}')

    # Perform the ping sweep
    echo "Scanning network: $base_ip.0/24"

    # Total number of IPs to scan
    total_ips=254

    # Initialize progress counter
    count=0
    # Enable fast mode if specified
    fast_mode=0
    if [[ "$2" == "--fast" ]]; then
        fast_mode=1
    fi

    # Function to perform a ping test in the background
    ping_host() {
        local ip=$1
        if ping -c 1 -W 1 "$ip" > /dev/null; then
            echo "Alive: $ip"  # Print successful IP hits
            echo "$ip" >> "$output_file"
        fi
    }

    # Loop through IP addresses
    for ip in $(seq 1 254); do
        # Construct the current IP address
        current_ip="$base_ip.$ip"

        # Call the ping_host function in the background
        ping_host "$current_ip" &

        # Adjust the sleep time for fast mode
        if [ $fast_mode -eq 0 ]; then
            sleep 0.1  # Slow down for standard mode
        fi
    done

    # Wait for all background jobs to finish
    wait

    # Print a newline for better readability
    echo
done

# Use arp-scan to verify the hosts
echo "Running arp-scan to verify hosts..."
arp-scan --localnet >> "$output_file"

# Output the final results
echo "Ping sweep complete. Results saved to $output_file."
