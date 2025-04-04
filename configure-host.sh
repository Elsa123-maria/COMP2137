#!/bin/bash

#To ignore signals TERM, HUP, and INT
trap '' TERM HUP INT

VERBOSE=false

log_msg() {
    logger "$1"
    $VERBOSE && echo "$1"
}

# For checing current hostname
CURRENT_HOSTNAME=$(hostname)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            ;;
        -name)
            shift
            DESIRED_NAME="$1"
            ;;
        -ip)
            shift
            DESIRED_IP="$1"
            ;;
        -hostentry)
            shift
            ENTRY_NAME="$1"
            shift
            ENTRY_IP="$1"
            ;;
        *)
            echo "Unknown option: $1"
            ;;
    esac
    shift
done

# To change hostname if required
if [[ -n "$DESIRED_NAME" && "$CURRENT_HOSTNAME" != "$DESIRED_NAME" ]]; then
    echo "$DESIRED_NAME" > /etc/hostname
    hostnamectl set-hostname "$DESIRED_NAME"

    # To update /etc/hosts
    if grep -q "$CURRENT_HOSTNAME" /etc/hosts; then
        sed -i "s/\b$CURRENT_HOSTNAME\b/$DESIRED_NAME/g" /etc/hosts
    else
        echo "127.0.1.1 $DESIRED_NAME" >> /etc/hosts
    fi

    log_msg "Hostname updated from $CURRENT_HOSTNAME to $DESIRED_NAME"
fi

# To change IP if needed
if [[ -n "$DESIRED_IP" ]]; then
    INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
    CURRENT_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [[ "$CURRENT_IP" != "$DESIRED_IP" ]]; then
        NETPLAN_FILE=$(find /etc/netplan -type f | head -n 1)
        sed -i "s/$CURRENT_IP/$DESIRED_IP/g" "$NETPLAN_FILE"
        netplan apply

        # To update /etc/hosts
        if grep -q "$DESIRED_NAME" /etc/hosts; then
            sed -i "s/.*$DESIRED_NAME/$DESIRED_IP $DESIRED_NAME/" /etc/hosts
        else
            echo "$DESIRED_IP $DESIRED_NAME" >> /etc/hosts
        fi

        log_msg "IP updated from $CURRENT_IP to $DESIRED_IP on interface $INTERFACE"
    fi
fi

# To add/update host entry
if [[ -n "$ENTRY_NAME" && -n "$ENTRY_IP" ]]; then
    if grep -q "$ENTRY_NAME" /etc/hosts; then
        sed -i "s/.*$ENTRY_NAME/$ENTRY_IP $ENTRY_NAME/" /etc/hosts
        log_msg "Host entry for $ENTRY_NAME updated to $ENTRY_IP"
    else
        echo "$ENTRY_IP $ENTRY_NAME" >> /etc/hosts
        log_msg "Host entry for $ENTRY_NAME added as $ENTRY_IP"
    fi
fi
