#!/bin/bash
set -e

RADVD_CONF="/etc/radvd.conf"
CONFIG_JSON="/root/ui_jool/config_ui.json"

# ------------------- Get interface from local_interface.sh -------------------
INTERFACE="$(/root/ui_jool/local_interface.sh | tr -d '[:space:]')"

if [ -z "$INTERFACE" ]; then
    echo "ERROR: No network interface detected by local_interface.sh"
    exit 1
fi

echo "Selected interface: $INTERFACE"

# ------------------- Read values from config_ui.json -------------------
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed. Please install jq to parse JSON."
    exit 1
fi

# IPv6 prefix
IPV6_PREFIX=$(jq -r '.dhcp6.subnet' "$CONFIG_JSON")

# DNS servers (comma-separated → convert to space-separated)
DNS_SERVERS_RAW=$(jq -r '.dhcp6.dns[0]' "$CONFIG_JSON")
DNS_SERVERS=$(echo "$DNS_SERVERS_RAW" | tr ',' ' ')

if [ -z "$IPV6_PREFIX" ] || [ -z "$DNS_SERVERS" ]; then
    echo "ERROR: Missing IPv6 prefix or DNS servers in config_ui.json"
    exit 1
fi

echo "Using IPv6 prefix: $IPV6_PREFIX"
echo "Using DNS servers: $DNS_SERVERS"

# ------------------- Generate radvd.conf -------------------
cat > "$RADVD_CONF" <<EOF
interface $INTERFACE {
    AdvSendAdvert on;

    AdvManagedFlag off;
    AdvOtherConfigFlag off;

    MaxRtrAdvInterval 30;
    MinRtrAdvInterval 10;

    AdvLinkMTU 1500;
    AdvDefaultLifetime 1800;
    AdvDefaultPreference medium;

    prefix $IPV6_PREFIX {
        AdvOnLink on;
        AdvAutonomous on;
        AdvRouterAddr on;

        AdvValidLifetime 604800;
        AdvPreferredLifetime 604800;
    };

    RDNSS $DNS_SERVERS {
        AdvRDNSSLifetime 86400;
    };

    DNSSL example.com {
        AdvDNSSLLifetime 86400;
    };
};
EOF

# set IPv6 forwarding rule for RA
sudo sysctl -w net.ipv6.conf.all.forwarding=1

echo "radvd.conf generated successfully at $RADVD_CONF"
