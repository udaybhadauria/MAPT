#!/bin/bash
set -e

OUTPUT_FILE="/root/ui_jool/01-network-manager-all.yaml"
CONFIG_FILE="/root/ui_jool/config_ui.json"

# ------------------- Detect interfaces -------------------
# Try ENX interfaces first
mapfile -t ENX_INTERFACES < <(ls /sys/class/net | grep '^enx' | sort)

# If no ENX found, fallback to eth interfaces (skip eth0)
if [ ${#ENX_INTERFACES[@]} -eq 0 ]; then
    mapfile -t ETH_INTERFACES < <(ls /sys/class/net | grep '^eth' | sort)
    if [ ${#ETH_INTERFACES[@]} -ge 2 ]; then
        # pick eth1 as fallback ENX
        ENX_INTERFACES=("${ETH_INTERFACES[1]}")
    elif [ ${#ETH_INTERFACES[@]} -eq 1 ]; then
        ENX_INTERFACES=("${ETH_INTERFACES[0]}")
    else
        echo "ERROR: No suitable network interface found"
        exit 1
    fi
fi

echo "Selected interface: ${ENX_INTERFACES[0]}"

# ------------------- Read IP info from config -------------------
# IPv4 base
V4_PREFIX=$(jq -r '.s46.v4_prefix' "$CONFIG_FILE")
# Convert last octet to .1 for gateway
V4_IP="${V4_PREFIX%.*}.1/24"

# IPv6 subnet (take the base /64 from dhcp6.subnet or s46.v6_rule_prefix)
V6_SUBNET=$(jq -r '.dhcp6.subnet' "$CONFIG_FILE")
# Remove the /60 and assign ::1/64
V6_IP="${V6_SUBNET%%/*}1/64"

# ------------------- Write netplan file -------------------
cat <<EOF > "$OUTPUT_FILE"
network:
  version: 2
  renderer: NetworkManager

  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
      accept-ra: true
      optional: true
      # WAN side (Internet)
      # Automatically gets both IPv4 and IPv6

    ${ENX_INTERFACES[0]}:
      dhcp4: false
      dhcp6: false
      addresses:
        - $V4_IP
        - $V6_IP
      #gateway4: $V4_IP
EOF

echo "Netplan file created at: $OUTPUT_FILE"
