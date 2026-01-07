#!/bin/bash
set -euo pipefail

CONFIG="config_ui.json"
OUT_CFG="/etc/kea/kea-dhcp6.conf"

############################################
# PRECHECKS
############################################
command -v jq >/dev/null || { echo "jq missing"; exit 1; }
command -v kea-dhcp6 >/dev/null || { echo "kea-dhcp6 missing"; exit 1; }
[[ -f "$CONFIG" ]] || { echo "config_ui.json missing"; exit 1; }

############################################
# DETECT INTERFACE
############################################
IFACE="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]' | xargs)"

if [ -z "$IFACE" ]; then
    echo "ERROR: No network interface detected by local_interface.sh"
    exit 1
fi

echo "Selected interface: $IFACE"

#[[ -n "$IFACE" ]] || { echo "No enx interface found"; exit 1; }

############################################
# READ CONFIG
############################################
SUBNET=$(jq -r '.dhcp6.subnet' "$CONFIG")
POOL_START=$(jq -r '.dhcp6.pool.start' "$CONFIG")
POOL_END=$(jq -r '.dhcp6.pool.end' "$CONFIG")
DNS=$(jq -r '.dhcp6.dns | join(",")' "$CONFIG")

V4_PREFIX=$(jq -r '.s46.v4_prefix' "$CONFIG")
V4_PLEN=$(jq -r '.s46.v4_plen' "$CONFIG")
EA_LEN=$(jq -r '.s46.ea_len' "$CONFIG")
V6_RULE_PREFIX=$(jq -r '.s46.v6_rule_prefix' "$CONFIG")
DMR=$(jq -r '.s46.dmr' "$CONFIG")

############################################
# VALIDATION
############################################
jq -e '.devices | length > 0' "$CONFIG" >/dev/null || {
  echo "No devices defined"; exit 1;
}

# Duplicate MAC check
DUP_MACS=$(jq -r '.devices[].mac' "$CONFIG" | sort | uniq -d)
[[ -z "$DUP_MACS" ]] || { echo "Duplicate MAC(s): $DUP_MACS"; exit 1; }

############################################
# START FILE (OVERWRITE)
############################################
cat > "$OUT_CFG" <<EOF
{
  "Dhcp6": {
    "interfaces-config": {
      "interfaces": ["$IFACE"]
    },

    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/dhcp6.leases"
    },

    "subnet6": [
      {
        "id": 1,
        "subnet": "$SUBNET",
        "interface": "$IFACE",

        "pools": [
          { "pool": "$POOL_START - $POOL_END" }
        ],

        "option-data": [
          {
            "name": "dns-servers",
            "data": "$DNS"
          }
        ],

        "preferred-lifetime": 604800,
        "valid-lifetime": 604800,
        "renew-timer": 518400,
        "rebind-timer": 604800,

        "reservations": [
EOF

############################################
# RESERVATIONS (SAFE LOOP)
############################################
TOTAL=$(jq '.devices | length' "$CONFIG")

for ((i=0; i<TOTAL; i++)); do
  MAC=$(jq -r ".devices[$i].mac" "$CONFIG")
  PREFIX=$(jq -r ".devices[$i].v6_prefix" "$CONFIG")
  PSID=$(jq -r ".devices[$i].psid" "$CONFIG")
  PSID_LEN=$(jq -r ".devices[$i].psid_len" "$CONFIG")

  [[ $i -lt $((TOTAL-1)) ]] && COMMA="," || COMMA=""

cat >> "$OUT_CFG" <<EOF
          {
            "hw-address": "$MAC",
            "prefixes": ["$PREFIX"],
            "option-data": [
              { "name": "s46-cont-mapt" },
              {
                "space": "s46-cont-mapt-options",
                "name": "s46-rule",
                "data": "0, $EA_LEN, $V4_PLEN, $V4_PREFIX, $V6_RULE_PREFIX"
              },
              {
                "space": "s46-cont-mapt-options",
                "name": "s46-dmr",
                "data": "$DMR"
              },
              {
                "space": "s46-rule-options",
                "name": "s46-portparams",
                "data": "4, $PSID/$PSID_LEN"
              }
            ]
          }$COMMA
EOF
done

############################################
# FOOTER
############################################
cat >> "$OUT_CFG" <<EOF
        ]
      }
    ],

    "loggers": [
      {
        "name": "kea-dhcp6",
        "output_options": [
          {
            "output": "/var/log/kea/kea-dhcp6.log",
            "maxsize": 1048576,
            "maxver": 3
          }
        ],
        "severity": "DEBUG",
        "debuglevel": 99
      }
    ]
  }
}
EOF

############################################
# VALIDATE & RESTART
############################################
kea-dhcp6 -t "$OUT_CFG"
systemctl restart kea-dhcp6-server
echo "✅ Kea DHCPv6 config applied correctly"
