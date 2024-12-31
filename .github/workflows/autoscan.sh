#!/bin/bash

# Function to display help
function show_help() {
    echo "Usage: $0 [output_prefix] [-d | --directory <dir>] [-f | --fast] [-h | --help]"
    echo
    echo "   output_prefix : Specify the output file prefix to save the results."
    echo "                   The ping scan results will be saved to <output_prefix>.ip."
    echo "                   The arp-scan results will be saved to <output_prefix>.arp."
    echo "   -d, --directory : Specify the directory to save the output files."
    echo "   -f, --fast      : Enable fast mode to speed up the ping sweep."
    echo "   -h, --help      : Display this help message."
    echo
    echo "This script scans all directly connected network segments and verifies live hosts."
}

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Initialize variables
output_prefix="IP_Add_Local"  # Default output prefix
fast_mode=0                   # Default is not fast mode
output_dir="scanResults"      # Default output directory

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--fast)
            fast_mode=1
            ;;
        -d|--directory)
            shift
            output_dir="$1"
            ;;
        *)
            output_prefix="$1"  # Set output prefix to the first non-flag argument
            ;;
    esac
    shift  # Move to the next argument
done

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Define output file names with the directory
ping_output_file="${output_dir}/${output_prefix}.ip"
arp_output_file="${output_dir}/${output_prefix}.arp"

# Clear the output files if they exist
> "$ping_output_file"
> "$arp_output_file"

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

    # Function to perform a ping test in the background
    ping_host() {
        local ip=$1
        if ping -c 1 -W 1 "$ip" > /dev/null; then
            echo "Alive: $ip"  # Print successful IP hits
            echo "$ip" >> "$ping_output_file"  # Save to ping output file
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
arp-scan --localnet >> "$arp_output_file"  # Save to arp output file

# Output the final results
echo "Ping sweep complete. Results saved to $ping_output_file and $arp_output_file."

# Nmap port scan with reports classified by port number
HOSTS_FILE="${output_dir}/${output_prefix}.ip"

# Ensure the 'nmap' command is correctly defined
echo "Beginning nmap port scan..."
RESULT=$(nmap -iL "${HOSTS_FILE}" --open | grep -E "Nmap scan report|tcp open")

# Read the nmap output line by line
while read -r line; do
    if echo "${line}" | grep -q "report for"; then
        ip=$(echo "${line}" | awk -F "for " '{print $2}')
    elif echo "${line}" | grep -q "tcp open"; then
        port=$(echo "${line}" | awk -F'/' '{print $1}')
        file="${output_dir}/port-${port}.out"
        echo "${ip}" >> "${file}"
    fi
done <<< "${RESULT}"
echo "Scan Complete - Files Located in ${PWD}/${output_dir}"
