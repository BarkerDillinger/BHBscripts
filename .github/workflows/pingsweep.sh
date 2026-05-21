#!/usr/bin/env bash

# ==========================================================
# Script Name: pingsweep.sh
# Purpose:     Discover active IPv4 hosts on local subnet(s)
# Output:      Wordlist-style file of active IP addresses
# ==========================================================

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_NAME="$(basename "$0")"

OUTPUT_FILE="subnet"
VERBOSE=0
SLOW_SCAN=0
INTERFACE_FILTER=""
ETH_ONLY=0
WIFI_ONLY=0

# User-defined CIDR ranges.
# Example:
#   -r 192.168.1.0/24
#   -r 172.23.23.33/24
declare -a RANGE_LIST=()

FAST_TIMEOUT=1
FAST_COUNT=1
FAST_JOBS=128

SLOW_TIMEOUT=2
SLOW_COUNT=2
SLOW_JOBS=32

TMP_DIR="$(mktemp -d)"
RAW_RESULTS="${TMP_DIR}/raw_results.txt"
FAILED_HOSTS="${TMP_DIR}/failed_hosts.txt"
SLOW_RESULTS="${TMP_DIR}/slow_results.txt"

trap 'rm -rf "${TMP_DIR}"' EXIT


show_help() {
    cat << EOF
${SCRIPT_NAME}

Usage:
  ${SCRIPT_NAME} [options]

Options:
  -v                  Verbose mode. Print active IP addresses to console.
  -f <filename>       Output filename. Default: subnet
  -i <interface>      Scan only the specified local interface.
  -r <ip/cidr>        Scan a manually defined IPv4 CIDR range.
                      May be used multiple times.
  -e                  Scan only Ethernet-style interfaces.
  -w                  Scan only WiFi-style interfaces.
  -s                  Slow mode. Recheck failed hosts more carefully.
  -h                  Show this help message.

Range Mode:
  The -r option allows you to define one or more IPv4 networks manually
  instead of extracting subnet information from local interfaces.

  The value must be in IPv4 CIDR format:

      ip-address/prefix

  Examples:

      192.168.1.0/24
      192.168.1.25/24
      172.23.23.0/24
      10.10.10.10/30

  The IP address does not need to be the actual network address. For example,
  if you provide:

      192.168.1.25/24

  the script calculates the real network address:

      192.168.1.0/24

  and scans the usable host range:

      192.168.1.1 through 192.168.1.254

  Multiple ranges may be scanned in one command:

      ${SCRIPT_NAME} -r 192.168.1.0/24 -r 172.23.23.0/24 -v

Examples:
  ./${SCRIPT_NAME}
  ./${SCRIPT_NAME} -v
  ./${SCRIPT_NAME} -f subnet.txt
  ./${SCRIPT_NAME} -i eth0
  ./${SCRIPT_NAME} -i wlan0 -v
  ./${SCRIPT_NAME} -e -v
  ./${SCRIPT_NAME} -w -f wifi-subnet.txt
  ./${SCRIPT_NAME} -r 192.168.1.0/24 -v
  ./${SCRIPT_NAME} -r 192.168.1.25/24 -r 172.23.23.0/24 -f targets.txt
  ./${SCRIPT_NAME} -s -v

Description:
  This script extracts IPv4 interface information from the local system,
  calculates each subnet, pings all usable host addresses, and writes only
  responsive IP addresses to a text file.

  If one or more -r options are provided, the script scans those manually
  defined CIDR ranges instead of scanning local interfaces.

  The output file is formatted as a simple wordlist, one IP address per line,
  so it can be reused by tools such as nmap.

EOF
}


die() {
    echo "[ERROR] $*" >&2
    exit 1
}


log_info() {
    if [[ "${VERBOSE}" -eq 1 ]]; then
        echo "[INFO] $*"
    fi
}


require_command() {
    local cmd="$1"

    if ! command -v "${cmd}" >/dev/null 2>&1; then
        die "Required command not found: ${cmd}"
    fi
}


parse_args() {
    while getopts ":vf:i:r:ewsh" opt; do
        case "${opt}" in
            v)
                VERBOSE=1
                ;;

            f)
                OUTPUT_FILE="${OPTARG}"
                ;;

            i)
                INTERFACE_FILTER="${OPTARG}"
                ;;

            r)
                RANGE_LIST+=("${OPTARG}")
                ;;

            e)
                ETH_ONLY=1
                ;;

            w)
                WIFI_ONLY=1
                ;;

            s)
                SLOW_SCAN=1
                ;;

            h)
                show_help
                exit 0
                ;;

            :)
                die "Option -${OPTARG} requires an argument."
                ;;

            \?)
                die "Invalid option: -${OPTARG}. Use -h for help."
                ;;
        esac
    done

    if [[ "${ETH_ONLY}" -eq 1 && "${WIFI_ONLY}" -eq 1 ]]; then
        die "Options -e and -w cannot be used together."
    fi

    if [[ -n "${INTERFACE_FILTER}" && "${ETH_ONLY}" -eq 1 ]]; then
        die "Options -i and -e should not be used together."
    fi

    if [[ -n "${INTERFACE_FILTER}" && "${WIFI_ONLY}" -eq 1 ]]; then
        die "Options -i and -w should not be used together."
    fi

    if (( ${#RANGE_LIST[@]} > 0 )); then
        if [[ -n "${INTERFACE_FILTER}" ]]; then
            die "Options -r and -i cannot be used together. Use either a manual range or an interface scan."
        fi

        if [[ "${ETH_ONLY}" -eq 1 ]]; then
            die "Options -r and -e cannot be used together. Use either a manual range or Ethernet interface discovery."
        fi

        if [[ "${WIFI_ONLY}" -eq 1 ]]; then
            die "Options -r and -w cannot be used together. Use either a manual range or WiFi interface discovery."
        fi
    fi
}


validate_ipv4() {
    local ip="$1"
    local a b c d

    [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

    IFS=. read -r a b c d <<< "${ip}"

    for octet in "${a}" "${b}" "${c}" "${d}"; do
        [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done

    return 0
}


validate_cidr() {
    local cidr="$1"
    local ip prefix

    [[ "${cidr}" == */* ]] || return 1

    ip="${cidr%/*}"
    prefix="${cidr#*/}"

    validate_ipv4 "${ip}" || return 1

    [[ "${prefix}" =~ ^[0-9]+$ ]] || return 1
    (( prefix >= 0 && prefix <= 32 )) || return 1

    return 0
}


ip_to_int() {
    local ip="$1"
    local a b c d

    IFS=. read -r a b c d <<< "${ip}"

    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}


int_to_ip() {
    local int="$1"

    echo "$(( (int >> 24) & 255 )).$(( (int >> 16) & 255 )).$(( (int >> 8) & 255 )).$(( int & 255 ))"
}


prefix_to_mask_int() {
    local prefix="$1"

    if (( prefix == 0 )); then
        echo 0
    else
        echo $(( 0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF ))
    fi
}


cidr_network_address() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    local ip_int mask_int network_int

    ip_int="$(ip_to_int "${ip}")"
    mask_int="$(prefix_to_mask_int "${prefix}")"
    network_int=$(( ip_int & mask_int ))

    int_to_ip "${network_int}"
}


cidr_broadcast_address() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    local ip_int mask_int network_int broadcast_int

    ip_int="$(ip_to_int "${ip}")"
    mask_int="$(prefix_to_mask_int "${prefix}")"
    network_int=$(( ip_int & mask_int ))
    broadcast_int=$(( network_int | (~mask_int & 0xFFFFFFFF) ))

    int_to_ip "${broadcast_int}"
}


safe_range_name() {
    local cidr="$1"

    echo "${cidr}" | sed 's#[/.]#_#g'
}


is_ethernet_interface() {
    local iface="$1"

    [[ "${iface}" =~ ^(eth|en|eno|ens|enp) ]]
}


is_wifi_interface() {
    local iface="$1"

    [[ "${iface}" =~ ^(wlan|wifi|wl|wlp) ]]
}


get_interfaces() {
    ip -o -4 addr show up scope global | awk '{print $2, $4}' | while read -r iface cidr; do

        if [[ -n "${INTERFACE_FILTER}" && "${iface}" != "${INTERFACE_FILTER}" ]]; then
            continue
        fi

        if [[ "${ETH_ONLY}" -eq 1 ]] && ! is_ethernet_interface "${iface}"; then
            continue
        fi

        if [[ "${WIFI_ONLY}" -eq 1 ]] && ! is_wifi_interface "${iface}"; then
            continue
        fi

        echo "${iface} ${cidr}"
    done
}


generate_hosts_from_cidr() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    local ip_int mask_int network_int broadcast_int
    local first_host last_host host_int

    ip_int="$(ip_to_int "${ip}")"
    mask_int="$(prefix_to_mask_int "${prefix}")"

    network_int=$(( ip_int & mask_int ))
    broadcast_int=$(( network_int | (~mask_int & 0xFFFFFFFF) ))

    if (( prefix == 32 )); then
        echo "${ip}"
        return
    fi

    if (( prefix == 31 )); then
        int_to_ip "${network_int}"
        int_to_ip "${broadcast_int}"
        return
    fi

    first_host=$(( network_int + 1 ))
    last_host=$(( broadcast_int - 1 ))

    for (( host_int = first_host; host_int <= last_host; host_int++ )); do
        int_to_ip "${host_int}"
    done
}


run_parallel_fast_scan() {
    local hosts_file="$1"

    xargs -a "${hosts_file}" -n 1 -P "${FAST_JOBS}" -I {} bash -c '
        ip="$1"
        count="$2"
        timeout="$3"
        failed_file="$4"

        if ping -n -c "${count}" -W "${timeout}" "${ip}" >/dev/null 2>&1; then
            echo "${ip}"
        else
            echo "${ip}" >> "${failed_file}"
        fi
    ' _ {} "${FAST_COUNT}" "${FAST_TIMEOUT}" "${FAILED_HOSTS}" >> "${RAW_RESULTS}"
}


run_parallel_slow_scan() {
    if [[ ! -s "${FAILED_HOSTS}" ]]; then
        return
    fi

    sort -u "${FAILED_HOSTS}" > "${TMP_DIR}/failed_sorted.txt"

    xargs -a "${TMP_DIR}/failed_sorted.txt" -n 1 -P "${SLOW_JOBS}" -I {} bash -c '
        ip="$1"
        count="$2"
        timeout="$3"

        if ping -n -c "${count}" -W "${timeout}" "${ip}" >/dev/null 2>&1; then
            echo "${ip}"
        fi
    ' _ {} "${SLOW_COUNT}" "${SLOW_TIMEOUT}" >> "${SLOW_RESULTS}"
}


scan_interface() {
    local iface="$1"
    local cidr="$2"
    local hosts_file="${TMP_DIR}/${iface}_hosts.txt"

    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    local network
    local broadcast

    network="$(cidr_network_address "${cidr}")"
    broadcast="$(cidr_broadcast_address "${cidr}")"

    log_info "Interface: ${iface}"
    log_info "Address:   ${ip}"
    log_info "Prefix:    /${prefix}"
    log_info "Network:   ${network}"
    log_info "Broadcast: ${broadcast}"

    generate_hosts_from_cidr "${cidr}" > "${hosts_file}"

    local host_count
    host_count="$(wc -l < "${hosts_file}")"

    log_info "Hosts to scan on ${iface}: ${host_count}"

    if (( host_count > 65534 )); then
        echo "[WARN] ${iface} has ${host_count} hosts. This is a large subnet and may take a while." >&2
    fi

    run_parallel_fast_scan "${hosts_file}"
}


scan_range() {
    local cidr="$1"
    local safe_name
    local hosts_file

    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"
    local network
    local broadcast

    validate_cidr "${cidr}" || die "Invalid CIDR range: ${cidr}"

    safe_name="$(safe_range_name "${cidr}")"
    hosts_file="${TMP_DIR}/range_${safe_name}_hosts.txt"

    network="$(cidr_network_address "${cidr}")"
    broadcast="$(cidr_broadcast_address "${cidr}")"

    log_info "Range:     ${cidr}"
    log_info "Address:   ${ip}"
    log_info "Prefix:    /${prefix}"
    log_info "Network:   ${network}"
    log_info "Broadcast: ${broadcast}"

    generate_hosts_from_cidr "${cidr}" > "${hosts_file}"

    local host_count
    host_count="$(wc -l < "${hosts_file}")"

    log_info "Hosts to scan in ${network}/${prefix}: ${host_count}"

    if (( host_count > 65534 )); then
        echo "[WARN] ${cidr} contains ${host_count} hosts. This is a large subnet and may take a while." >&2
    fi

    run_parallel_fast_scan "${hosts_file}"
}


write_results() {
    cat "${RAW_RESULTS}" "${SLOW_RESULTS}" 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -u -V \
        > "${OUTPUT_FILE}"

    if [[ "${VERBOSE}" -eq 1 ]]; then
        echo
        echo "Active IP Addresses:"
        cat "${OUTPUT_FILE}"
    fi

    echo
    echo "Results written to: ${OUTPUT_FILE}"
    echo "Active hosts found: $(wc -l < "${OUTPUT_FILE}")"
}


main() {
    parse_args "$@"

    require_command ip
    require_command awk
    require_command ping
    require_command xargs
    require_command sort
    require_command grep
    require_command wc
    require_command sed

    : > "${RAW_RESULTS}"
    : > "${FAILED_HOSTS}"
    : > "${SLOW_RESULTS}"

    if (( ${#RANGE_LIST[@]} > 0 )); then
        for cidr in "${RANGE_LIST[@]}"; do
            scan_range "${cidr}"
        done
    else
        local found_interface=0

        while read -r iface cidr; do
            found_interface=1
            scan_interface "${iface}" "${cidr}"
        done < <(get_interfaces)

        if [[ "${found_interface}" -eq 0 ]]; then
            die "No matching active IPv4 interfaces found."
        fi
    fi

    if [[ "${SLOW_SCAN}" -eq 1 ]]; then
        log_info "Slow mode enabled. Rechecking failed hosts..."
        run_parallel_slow_scan
    fi

    write_results
}


main "$@"
