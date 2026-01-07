#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

CONFIG_FILE="$1"

echo "Applying MAP-T configuration from $BASE_DIR"

bash "$BASE_DIR/jool_validate_apply.sh"
bash "$BASE_DIR/generate_mac_ipv6.sh"

# HARD check
if [[ ! -s "$BASE_DIR/output.json" ]]; then
    echo "❌ ERROR: output.json not generated"
    exit 1
fi

bash "$BASE_DIR/generate_kea_dhcp6.sh"
bash "$BASE_DIR/add_neighbor_entries.sh"
bash "$BASE_DIR/check_services.sh"

echo "✅ Apply completed"
cat "$BASE_DIR/output.json"
