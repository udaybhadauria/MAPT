#!/bin/bash

CONFIG="/etc/kea/kea-dhcp6.conf"

# Remove multi-line C-style comments safely
cleaned=$(awk '
    BEGIN {inside=0}
    /\/\*/ {inside=1; next}
    /\*\// {inside=0; next}
    inside==0 {print}
' "$CONFIG" | tr -d '\n')

# Extract s46-rule data
s46_rule=$(echo "$cleaned" | grep -o '"name"[ ]*:[ ]*"s46-rule"[ ]*,[ ]*"data"[ ]*:[ ]*"[^"]*"' | head -n1 | sed 's/.*"data"[ ]*:[ ]*"\([^"]*\)".*/\1/')

# Check if s46-rule was found
if [ -z "$s46_rule" ]; then
    echo "❌ s46-rule not found in config!"
    exit 1
fi

# Split into variables
IFS=',' read -r RULE_ID EA_BITS PSID_LEN BR_IPV4 IPV6_PREFIX <<< "$s46_rule"

# Trim spaces
RULE_ID=${RULE_ID// /}
EA_BITS=${EA_BITS// /}
PSID_LEN=${PSID_LEN// /}
BR_IPV4=${BR_IPV4// /}
IPV6_PREFIX=${IPV6_PREFIX// /}

# Validate all fields
if [ -z "$RULE_ID" ] || [ -z "$EA_BITS" ] || [ -z "$PSID_LEN" ] || [ -z "$BR_IPV4" ] || [ -z "$IPV6_PREFIX" ]; then
    echo "❌ ERROR: One or more s46-rule values are missing!"
    exit 1
fi

# Print results
echo "RULE_ID    : $RULE_ID"
echo "EA_BITS    : $EA_BITS"
echo "PSID_LEN   : $PSID_LEN"
echo "BR_IPV4    : $BR_IPV4"
echo "IPV6_PREFIX: $IPV6_PREFIX"
