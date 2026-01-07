#!/usr/bin/env bash
set -euo pipefail

# Detect enx* interfaces
IFACES="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]' | xargs)"
#IFACES=$(ifconfig | grep -o '^enx[^:]*' | sort -u)

if [ -z "$IFACES" ]; then
    echo "No enx* interface found"
    exit 0
fi

for IFACE in $IFACES; do
    echo "Cleaning IPv6 neighbors on interface: $IFACE"

    ip -6 neigh show dev "$IFACE" \
    | awk '$2=="FAILED" || $2=="INCOMPLETE" {print $1}' \
    | while read -r IP; do
        echo "  deleting $IP"
        ip -6 neigh del "$IP" dev "$IFACE" 2>/dev/null || true
    done
done

echo "IPv6 neighbor cleanup complete."
