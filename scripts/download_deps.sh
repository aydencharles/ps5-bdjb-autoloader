#!/usr/bin/env bash
# Script to download dependency binaries from GitHub releases

set -euo pipefail

# Ensure we are in the project root
cd "$(dirname "$0")/.."

DEST_DIR="payloads/poops/src/org/bdj/external"
mkdir -p "$DEST_DIR"

AUTOLOADER_DIR="ps5_autoloader"
mkdir -p "$AUTOLOADER_DIR"

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

echo "Fetching latest release URL for ps5-payload-manager..."
PLDMGR_URL=$(curl -s https://api.github.com/repos/itsPLK/ps5-payload-manager/releases/latest | grep -o 'https://github.com/itsPLK/ps5-payload-manager/releases/download/[^"]*\.elf' | head -n 1)
if [ -z "$PLDMGR_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-payload-manager." >&2
    exit 1
fi
PLDMGR_FILE=$(basename "$PLDMGR_URL")

# Clean old dependency files
echo "Cleaning old binaries from $DEST_DIR..."
rm -f "$DEST_DIR"/kexp-*.bin
rm -f "$DEST_DIR"/elfldr-*.elf
rm -f "$DEST_DIR"/kexp_v6.bin
rm -f "$DEST_DIR"/elfldr.elf

echo "Cleaning old payload manager binaries from $AUTOLOADER_DIR..."
rm -f "$AUTOLOADER_DIR"/pldmgr-*.elf
rm -f "$AUTOLOADER_DIR"/pldmgr_v*.elf

# Download assets
echo "Downloading $ELFLDR_FILE..."
curl -L -o "$DEST_DIR/$ELFLDR_FILE" "$ELFLDR_URL"

echo "Downloading $KEXP_FILE..."
curl -L -o "$DEST_DIR/$KEXP_FILE" "$KEXP_URL"

echo "Downloading $PLDMGR_FILE..."
curl -L -o "$AUTOLOADER_DIR/$PLDMGR_FILE" "$PLDMGR_URL"

echo "Updating autoload.txt with $PLDMGR_FILE..."
sed -E "s/pldmgr[_v|-]+[0-9.]+\.elf/$PLDMGR_FILE/" "$AUTOLOADER_DIR/autoload.txt" > "$AUTOLOADER_DIR/autoload.txt.tmp"
mv "$AUTOLOADER_DIR/autoload.txt.tmp" "$AUTOLOADER_DIR/autoload.txt"

echo "Successfully downloaded all dependencies!"
ls -la "$DEST_DIR"
ls -la "$AUTOLOADER_DIR"

