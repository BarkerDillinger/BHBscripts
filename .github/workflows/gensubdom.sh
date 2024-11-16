#!/bin/bash

# Initialize variables
DOMAIN=""
WORDLIST=""
OUTPUT_FILE=""
APPEND_MODE=false

# Display help message
usage() {
    echo "Usage: $0 -d <domain> -w <wordlist> [-o <output_file>] [-a]"
    echo
    echo "Options:"
    echo "  -d <domain>       The domain name to append to subdomains (required)."
    echo "  -w <wordlist>     The wordlist file containing subdomains (required)."
    echo "  -o <output_file>  Specify the output file to store results (optional)."
    echo "  -a                Append to the output file instead of overwriting (optional)."
    echo
    echo "Example:"
    echo "  $0 -d example.com -w subdomains.txt -o output.txt -a"
    exit 1
}

# Parse command-line arguments
while getopts ":d:w:o:a" opt; do
    case $opt in
        d)
            DOMAIN="$OPTARG"
            ;;
        w)
            WORDLIST="$OPTARG"
            ;;
        o)
            OUTPUT_FILE="$OPTARG"
            ;;
        a)
            APPEND_MODE=true
            ;;
        *)
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$DOMAIN" ] || [ -z "$WORDLIST" ]; then
    echo "Error: Both -d (domain) and -w (wordlist) options are required."
    usage
fi

# Validate that the wordlist file exists
if [ ! -f "$WORDLIST" ]; then
    echo "Error: Wordlist file '$WORDLIST' not found."
    exit 1
fi

# Handle output file overwrite or append
if [ -n "$OUTPUT_FILE" ] && [ "$APPEND_MODE" = false ]; then
    > "$OUTPUT_FILE"  # Clear the file if append mode is not enabled
fi

# Process the wordlist and generate domain list
if [ -n "$OUTPUT_FILE" ]; then
    # Write to the specified output file (suppress stdout)
    while read -r subdomain; do
        echo "${subdomain}.${DOMAIN}"
    done < "$WORDLIST" >> "$OUTPUT_FILE"
    
    # Count lines in the output file and display
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    echo "${OUTPUT_FILE} contains ${LINE_COUNT} lines."
else
    # Print domains to stdout
    while read -r subdomain; do
        echo "${subdomain}.${DOMAIN}"
    done < "$WORDLIST"
fi
