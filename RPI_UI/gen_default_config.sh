#!/bin/bash

CONFIG_FILE="config_ui.json"

# If config file already exists, skip creation
if [[ -e "$CONFIG_FILE" ]]; then
  echo "ℹ️  $CONFIG_FILE already exists. Skipping creation."
  exit 0
fi

# Write config_ui.json
cat > "$CONFIG_FILE" <<EOF
{
    "dhcp6": {
        "subnet": "",
        "pool": { "start": "", "end": "" },
        "dns": []
    },
    "s46": {
        "v4_prefix": "192.168.12.0",
        "v4_plen": 24,
        "ea_len": 14,
        "v6_rule_prefix": "2600:8809:a504::/46",
        "dmr": "2600:8809:bfff:ffff::/64"
    },
    "devices": []
}
EOF

echo "✅ $CONFIG_FILE generated with interface: $ENX_IFACE"
