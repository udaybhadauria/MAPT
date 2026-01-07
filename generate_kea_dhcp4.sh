#!/bin/bash
set -euo pipefail

CONFIG="config_ui.json"
OUT_CFG="/etc/kea/kea-dhcp4.conf"

############################################
# PRECHECKS
############################################
command -v jq >/dev/null || { echo "jq missing"; exit 1; }
command -v kea-dhcp4 >/dev/null || { echo "kea-dhcp4 missing"; exit 1; }
[[ -f "$CONFIG" ]] || { echo "config_ui.json missing"; exit 1; }

############################################
# DETECT INTERFACE
############################################

# ------------------- Get interface from local_interface.sh -------------------
IFACE="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]' | xargs)"

if [ -z "$IFACE" ]; then
    echo "ERROR: No network interface detected by local_interface.sh"
    exit 1
fi

echo "Selected interface: $IFACE"

############################################
# STATIC CONFIG VALUES
############################################
SUBNET="192.168.5.0/24"
POOL_START="192.168.5.100"
POOL_END="192.168.5.200"
ROUTERS="192.168.5.1"
DNS="8.8.8.8,9.9.9.9"

############################################
# WRITE CONFIG
############################################
cat > "$OUT_CFG" <<EOF
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [
        "$IFACE"
      ]
    },
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/dhcp4.leases"
    },
    "subnet4": [
      {
        "id": 1,
        "subnet": "$SUBNET",
        "interface": "$IFACE",
        "pools": [
          {
            "pool": "$POOL_START - $POOL_END"
          }
        ],
        "option-data": [
          {
            "name": "routers",
            "data": "$ROUTERS"
          },
          {
            "name": "domain-name-servers",
            "data": "$DNS"
          }
        ]
      }
    ],
    "valid-lifetime": 604800,
    "renew-timer": 300,
    "rebind-timer": 600,
    "loggers": [
      {
        "name": "kea-dhcp4",
        "output_options": [
          {
            "output": "/var/log/kea/kea-dhcp4.log"
          }
        ],
        "severity": "INFO"
      }
    ]
  }
}
EOF

############################################
# VALIDATE & RESTART
############################################
kea-dhcp4 -t "$OUT_CFG"
systemctl restart kea-dhcp4-server
echo "✅ Kea DHCPv4 config applied correctly"
