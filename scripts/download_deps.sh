#!/usr/bin/env bash
# Script to download dependency binaries from GitHub releases

set -euo pipefail

# Ensure we are in the project root
cd "$(dirname "$0")/.."

DEST_DIR="payloads/poops/src/org/bdj/external"
mkdir -p "$DEST_DIR"

echo "Checking for curl..."
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required to download dependencies." >&2
    exit 1
fi

echo "Fetching latest release URL for ps5-elfldr..."
ELFLDR_URL=$(curl -s https://api.github.com/repos/itsPLK/ps5-elfldr/releases/latest | grep -o 'https://github.com/itsPLK/ps5-elfldr/releases/download/[^"]*\.elf' | head -n 1)
if [ -z "$ELFLDR_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-elfldr." >&2
    exit 1
fi
ELFLDR_FILE=$(basename "$ELFLDR_URL")

echo "Fetching latest release URL for ps5-kexp..."
KEXP_URL=$(curl -s https://api.github.com/repos/itsPLK/ps5-kexp/releases/latest | grep -o 'https://github.com/itsPLK/ps5-kexp/releases/download/[^"]*\.bin' | head -n 1)
if [ -z "$KEXP_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-kexp." >&2
    exit 1
fi
KEXP_FILE=$(basename "$KEXP_URL")

# Clean old dependency files
echo "Cleaning old binaries from $DEST_DIR..."
rm -f "$DEST_DIR"/kexp-*.bin
rm -f "$DEST_DIR"/elfldr-*.elf
rm -f "$DEST_DIR"/kexp_v6.bin
rm -f "$DEST_DIR"/elfldr.elf

# Download assets
echo "Downloading $ELFLDR_FILE..."
curl -L -o "$DEST_DIR/$ELFLDR_FILE" "$ELFLDR_URL"

echo "Downloading $KEXP_FILE..."
curl -L -o "$DEST_DIR/$KEXP_FILE" "$KEXP_URL"

echo "Successfully downloaded dependencies to $DEST_DIR"
ls -la "$DEST_DIR"
