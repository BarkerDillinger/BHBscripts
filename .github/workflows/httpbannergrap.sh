#!/bin/bash

# Check if input is provided
if [ -z "${1}" ]; then
    echo "Usage:"
    echo "  -s --simple: ${0} -s <IP Address> <Port>"
    echo "  -d --domain: ${0} -d <Domain Name>"
    echo "  -l --list: ${0} -l <IP Address / Domain List> <Port List>"
    exit 1
fi

OPTION=${1}

case ${OPTION} in
    -s|--simple)
        echo "Simple Scan"
        ip=${2}
        port=${3}
        if [ -z "$ip" ] || [ -z "$port" ]; then
            echo "Error: IP Address and Port are required for a simple scan."
            exit 1
        fi
        # Perform a simple scan
        echo "Scanning ${ip}:${port}"
        curl --head "http://${ip}:${port}" || echo "Curl failed for ${ip}:${port}"
        nmap -O "${ip}"
        ;;

    -d|--domain)
        echo "Domain Scan"
        domain=${2}
        if [ -z "$domain" ]; then
            echo "Error: Requires Domain Name"
            exit 1
        fi
        # Perform a domain scan
        echo "Scanning domain: www.${domain}"
        curl --head "http://www.${domain}" || echo "Curl failed for ${domain}"
        nmap -O "${domain}"
        ;;

    -l|--list)
        echo "List Scan"
        host_list=${2}
        port_list=${3}

        # Check if the host and port list files exist
        if [ ! -f "$host_list" ] || [ ! -f "$port_list" ]; then
            echo "Error: Host list or port list file does not exist."
            exit 1
        fi

        # Read hosts and ports from the provided files
        hosts=($(cat "$host_list"))
        ports=($(cat "$port_list"))

        # Iterate through hosts and ports
        for host in "${hosts[@]}"; do
            echo "Checking host: $host"
            for port in "${ports[@]}"; do
                echo "  Checking port: $port on host $host"
                curl --head "http://${host}:${port}" || echo "Curl failed for ${host}:${port}"
                nmap -O "${host}" > /dev/null
            done
        done
        ;;

    *)
        echo "Invalid option. Usage:"
        echo "  -s --simple: ${0} -s <IP Address> <Port>"
        echo "  -d --domain: ${0} -d <Domain Name>"
        echo "  -l --list: ${0} -l <IP Address / Domain List> <Port List>"
        exit 1
        ;;
esac
