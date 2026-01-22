#!/bin/sh
# ═══════════════════════════════════════════════════════════
# PairDrop RTC Config Generator
# BAUER GROUP | CS-PairDrop
# ═══════════════════════════════════════════════════════════
# Generates rtc_config.json based on environment:
# - With TURN vars: Full TURN/STUN config for TURN server
# - Without TURN vars: Public STUN servers only (no config file)
# ═══════════════════════════════════════════════════════════

set -e

TEMPLATE_FILE="/templates/rtc_config.template.json"
OUTPUT_FILE="/config/rtc_config.json"

echo "╔════════════════════════════════════════════════════════╗"
echo "║        PairDrop RTC Config Generator                   ║"
echo "╚════════════════════════════════════════════════════════╝"

# Check if TURN configuration is provided
if [ -z "$TURN_HOSTNAME" ] || [ -z "$TURN_SECRET" ]; then
    echo "→ TURN_HOSTNAME or TURN_SECRET not set"
    echo "→ PairDrop will use default public STUN servers"
    echo "✓ No config file generated (defaults used)"
    echo "═══════════════════════════════════════════════════════════"
    exit 0
fi

echo "→ TURN_HOSTNAME: ${TURN_HOSTNAME}"
echo "→ Generating TURN/STUN config..."

# Generate config using envsubst
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "✓ Config generated: ${OUTPUT_FILE}"
echo ""
cat "$OUTPUT_FILE"
echo ""
echo "═══════════════════════════════════════════════════════════"
