#!/bin/bash
set -e

OUTPUT_FILE="/root/ui_jool/01-network-manager-all.yaml"

# Fetch all enx interfaces currently available
mapfile -t ENX_INTERFACES < <(ls /sys/class/net | grep '^enx')

# Start writing the file (exact structure preserved)
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
EOF

# Add each enx interface EXACTLY like your sample
for IFACE in "${ENX_INTERFACES[@]}"; do
cat <<EOF >> "$OUTPUT_FILE"

    $IFACE:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.2.1/24
        - fd12:3456:789a::1/64
      #gateway4: 192.168.2.1
EOF
done

echo "Netplan file created at: $OUTPUT_FILE"
echo "Included enx interfaces:"
printf ' - %s\n' "${ENX_INTERFACES[@]}"
