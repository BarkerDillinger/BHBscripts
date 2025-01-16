#!/bin/bash

FILE="${1}"
OUTPUT_FOLDER="${2}"

# Validate the input file
if [[ ! -s "${FILE}" ]]; then
    echo "Host File Argument is required."
    echo "Usage: ${0} <File> <Output Folder>"
    exit 1
fi

# Set default output folder if not provided
if [[ -z "${OUTPUT_FOLDER}" ]]; then
    OUTPUT_FOLDER="data_out"
fi

# Read the input file line by line
while read -r line; do
    # Trim whitespace and validate URL, IP, or IP with port
    url=$(echo "${line}" | xargs)
    if [[ -n "${url}" ]]; then
        if [[ "${url}" =~ ^https?:// ]] || [[ "${url}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]]; then
            echo "Testing ${url} for Directory Indexing..."
            if curl -L -s "${url}" | grep -q -e "Index of /" -e "[PARENTDIR]"; then
                echo -e "\t -!- Found Directory Indexing page at ${url}"
                echo -e "\t -!- Downloading to the \"${OUTPUT_FOLDER}\" folder..."
                mkdir -p "${OUTPUT_FOLDER}"
                wget -q -r -np -R "index.html*" "${url}" -P "${OUTPUT_FOLDER}"
            else
                echo -e "\t -!- No Directory Indexing found at ${url}"
            fi
        else
            echo "Invalid URL or IP Address with port format: ${url}"
        fi
    fi
done < "${FILE}"
