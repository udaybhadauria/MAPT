#!/bin/bash

# Get eth0 IPv4 address
IP_ADDR=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$IP_ADDR" ]; then
    echo "❌ eth0 has no IPv4 address!"
    exit 1
fi

# Extract the last byte
LAST_BYTE=${IP_ADDR##*.}

# Print results
echo "eth0 IPv4 address: $IP_ADDR"
echo "Last byte        : $LAST_BYTE"
