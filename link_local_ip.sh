#!/bin/bash

CONFIG_FILE="/root/ui_jool/config_ui.json"

# ------------------- Get interface from local_interface.sh -------------------
IFACE="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]' | xargs)"

if [ -z "$IFACE" ]; then
    echo "ERROR: No network interface detected by local_interface.sh"
    exit 1
fi

echo "Selected interface: $IFACE"
#------------------------------------------------------------------------------

MAC=$(cat /sys/class/net/$IFACE/address)

LL64="fe80::$(printf '%02x%02x:%02x%02x:ff:fe:%02x%02x' \
    0x${MAC:0:2} 0x${MAC:3:2} 0x${MAC:6:2} 0x${MAC:9:2} 0x${MAC:12:2} 0x${MAC:15:2})/64"

# IPv6 subnet (take the base /64 from dhcp6.subnet or s46.v6_rule_prefix)
V6_SUBNET=$(jq -r '.dhcp6.subnet' "$CONFIG_FILE")
# Remove the /60 and assign ::1/64
V6_IP="${V6_SUBNET%%/*}1/64"

echo "$V6_IP"

sudo ip addr add 192.168.5.1/24 dev $IFACE
sudo ip -6 addr add $V6_IP dev $IFACE
sudo ip -6 addr add $LL64 dev $IFACE scope link
sudo ip link set dev $IFACE up
