#!/bin/bash

# Check if a file name is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Assign the first argument to the FILE variable
FILE=$1

# Get the current date in YY_MM_DD format
DATE=$(date +%y_%m_%d)

# Combine the file name and date to create the output file
FILENAME="${FILE}_${DATE}"

# Identify the Linux distribution
if [ -f /etc/os-release ]; then
    DISTRO=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
elif [ -f /etc/lsb-release ]; then
    DISTRO=$(grep DISTRIB_ID /etc/lsb-release | cut -d'=' -f2)
elif [ -f /etc/redhat-release ]; then
    DISTRO="RedHat"
else
    DISTRO="Unknown"
fi

# Save basic system information to the output file
{
    echo "Date: $(date)"
    echo "Distro: $DISTRO"
    echo "Kernel: $(uname -r)"
    echo "OS: $(uname -o)"
    echo ""
    echo "/proc/version contents:"
    cat /proc/version
    echo ""
    echo "Installed Applications:"
    case "$DISTRO" in
        debian|ubuntu)
            dpkg -l
            ;;
        arch)
            pacman -Q
            ;;
        fedora|redhat|centos)
            rpm -qa
            ;;
        suse|opensuse)
            zypper se --installed-only
            ;;
        *)
            echo "Package manager not recognized for distribution: $DISTRO"
            ;;
    esac
} > "$FILENAME"

# Notify the user
echo "File '$FILENAME' has been created with system information."
