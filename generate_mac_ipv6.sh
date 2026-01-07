#!/bin/bash

CONFIG="config_ui.json"
PY_SCRIPT="pd_calc.py"
IPV4_IFACE="eth0"
MAPPING_FILE="mac_ipv6_mapping.txt"
OUTPUT_JSON="output.json"

# ---------- extract common JSON values ----------
V4_PREFIX=$(jq -r '.s46.v4_prefix' "$CONFIG")
V4_PLEN=$(jq -r '.s46.v4_plen' "$CONFIG")
V6_RULE_PREFIX=$(jq -r '.s46.v6_rule_prefix' "$CONFIG")

# ---------- hardcoded psid length ----------
PSID_LEN=6

# ---------- IPv4 suffix ----------
LAST_BYTE=$(ip -4 addr show "$IPV4_IFACE" \
    | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
    | awk -F. '{print $4}' \
    | head -n1)

if [[ -z "$LAST_BYTE" ]]; then
    echo "ERROR: No IPv4 found on $IPV4_IFACE"
    exit 1
fi

# ---------- check for duplicate PSIDs ----------
PSID_LIST=($(jq -r '.devices[].psid' "$CONFIG"))
DUPLICATES=$(printf "%s\n" "${PSID_LIST[@]}" | sort | uniq -d)
if [[ -n "$DUPLICATES" ]]; then
    echo "ERROR: Duplicate PSID(s) detected: $DUPLICATES"
    exit 1
fi

# ---------- prepare mapping file ----------
> "$MAPPING_FILE"

# ---------- loop over devices ----------
DEVICE_COUNT=$(jq '.devices | length' "$CONFIG")

for ((i=0; i<DEVICE_COUNT; i++)); do
    MAC=$(jq -r ".devices[$i].mac" "$CONFIG")
    PSID=$(jq -r ".devices[$i].psid" "$CONFIG")

    OUTPUT=$(python3 "$PY_SCRIPT" \
        --v4_prefix ${V4_PREFIX}/${V4_PLEN} \
        --psid_len $PSID_LEN \
        --v6_prefix $V6_RULE_PREFIX \
        --v4_suffix $LAST_BYTE \
        --psid $PSID 2>/dev/null)

    IPV6_PD=$(echo "$OUTPUT" | awk -F': ' '/^IPv6 PD:/ {print $2}')
    FULL_IPV6=$(echo "$OUTPUT" | awk -F': ' '/^Full IPv6 Address:/ {print $2}')

    if [[ -z "$IPV6_PD" || -z "$FULL_IPV6" ]]; then
        echo "ERROR: pd_calc.py failed for MAC $MAC"
        exit 1
    fi

    # ---------- update config_ui.json v6_prefix ----------
    TMP_JSON=$(mktemp)
    jq --arg mac "$MAC" --arg pd "$IPV6_PD" \
       '(.devices[] | select(.mac==$mac) | .v6_prefix) = $pd' \
       "$CONFIG" > "$TMP_JSON" && mv "$TMP_JSON" "$CONFIG"

    # ---------- save mapping ----------
    # Format: MAC|PSID|IPv6_PD|FullIPv6
    echo "$MAC|$PSID|$IPV6_PD|$FULL_IPV6" >> "$MAPPING_FILE"

    echo "Device $((i+1)) WAN MAC: $MAC"
    echo "PSID              : $PSID"
    echo "IPv6 PD           : $IPV6_PD"
    echo "Full IPv6 Address : $FULL_IPV6"
    echo "============================================"
done

echo "config_ui.json updated successfully."
echo "Mapping file saved as $MAPPING_FILE"

# ---------- generate output.json ----------
echo '{ "devices": [' > "$OUTPUT_JSON"

COUNT=$(wc -l < "$MAPPING_FILE")
i=0

while IFS="|" read -r mac psid ipv6_pd ipv6_addr; do
    i=$((i+1))

    cat >> "$OUTPUT_JSON" <<EOF
    {
      "mac": "$mac",
      "psid": $psid,
      "ipv6_pd": "$ipv6_pd",
      "ipv6_address": "$ipv6_addr"
    }$( [ "$i" -lt "$COUNT" ] && echo "," )
EOF
done < "$MAPPING_FILE"

echo "] }" >> "$OUTPUT_JSON"

echo "JSON saved to $OUTPUT_JSON"
