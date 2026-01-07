#!/bin/bash

CONFIG="config_ui.json"
MAPPING="mac_ipv6_mapping.txt"

# ------------------- Read interface -------------------
IFACE="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]' | xargs)"
if [[ -z "$IFACE" || "$IFACE" == "null" ]]; then
    echo "ERROR: Interface not defined in $CONFIG"
    exit 1
fi

echo "Lan Interface is $IFACE."

# Ensure interface is up
sudo ip link set dev "$IFACE" up

# ------------------- Flush old entries -------------------
echo "Flushing existing IPv6 route rules for old or prefixes & addresses..."
sudo ip -6 addr flush dev "$IFACE"

echo "Flushing existing IPv6 neighbor entries and PD addresses..."
# Flush all permanent neighbors
sudo ip -6 neigh flush all nud permanent

# Remove all PD /60 addresses assigned to interface
jq -r '.devices[].v6_prefix' "$CONFIG" | while read PREFIX; do
    PREFIX_NO_MASK="${PREFIX%/*}"
    # Delete the ::1 address if it exists
    sudo ip -6 addr del "${PREFIX_NO_MASK}1/60" dev "$IFACE" 2>/dev/null || true
done

# ------------------- Assign PD /60 prefixes -------------------
echo "Assigning PD /60 prefixes to $IFACE..."
jq -r '.devices[].v6_prefix' "$CONFIG" | while read PREFIX; do
    PREFIX_NO_MASK="${PREFIX%/*}"
    echo "Adding address ${PREFIX_NO_MASK}1/60 to $IFACE"
    sudo ip -6 addr add "${PREFIX_NO_MASK}1/60" dev "$IFACE"
done

# ------------------- Add permanent neighbors -------------------
if [[ ! -f "$MAPPING" ]]; then
    echo "ERROR: Mapping file $MAPPING not found"
    exit 1
fi

echo "Adding permanent neighbor entries..."
while IFS='|' read -r MAC PSID PREFIX IPV6; do
    [[ -z "$MAC" || -z "$IPV6" ]] && continue
    sudo ip -6 neigh replace "$IPV6" dev "$IFACE" lladdr "$MAC" nud permanent
    echo "Neighbor entry added: $IPV6 -> $MAC"
done < "$MAPPING"

echo "All PD addresses and neighbors configured successfully."
