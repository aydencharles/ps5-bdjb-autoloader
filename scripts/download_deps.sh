#!/usr/bin/env bash
# Script to download dependency binaries from GitHub releases

set -euo pipefail

# Ensure we are in the project root
cd "$(dirname "$0")/.."

DEST_DIR="payloads/poops/src/org/bdj/external"
AUTOLOADER_DEST_DIR="payloads/autoloader"
mkdir -p "$DEST_DIR"
mkdir -p "$AUTOLOADER_DEST_DIR"

echo "Checking for curl..."
if ! command -v curl &> /dev/null; then
    echo "Error: curl is required to download dependencies." >&2
    exit 1
fi

echo "Fetching latest release URL for ps5-payload-dev/elfldr..."
ELFLDR_RELEASE_JSON=$(curl -s https://api.github.com/repos/ps5-payload-dev/elfldr/releases/latest)
ELFLDR_URL=$(echo "$ELFLDR_RELEASE_JSON" | grep -o 'https://github.com/ps5-payload-dev/elfldr/releases/download/[^"]*elfldr-ps5\.elf' | head -n 1)
if [ -z "$ELFLDR_URL" ]; then
    # Fallback: asset may be named differently
    ELFLDR_URL=$(echo "$ELFLDR_RELEASE_JSON" | grep -o 'https://github.com/ps5-payload-dev/elfldr/releases/download/[^"]*\.elf' | head -n 1)
fi
if [ -z "$ELFLDR_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-payload-dev/elfldr." >&2
    exit 1
fi

echo "Fetching latest release URL for ps5-kexp..."
KEXP_URL=$(curl -s https://api.github.com/repos/itsPLK/ps5-kexp/releases/latest | grep -o 'https://github.com/itsPLK/ps5-kexp/releases/download/[^"]*\.bin' | head -n 1)
if [ -z "$KEXP_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-kexp." >&2
    exit 1
fi

echo "Fetching latest release URL for ps5-unified-autoloader..."
AUTOLOADER_RELEASE_JSON=$(curl -s https://api.github.com/repos/itsPLK/ps5-unified-autoloader/releases/latest)
AUTOLOADER_URL=$(echo "$AUTOLOADER_RELEASE_JSON" | grep -o 'https://github.com/itsPLK/ps5-unified-autoloader/releases/download/[^"]*\.elf' | head -n 1)
if [ -z "$AUTOLOADER_URL" ]; then
    echo "Error: Could not retrieve latest release URL for ps5-unified-autoloader." >&2
    exit 1
fi

ELFLDR_VER=$(echo "$ELFLDR_URL" | grep -oE 'download/[^/]+' | cut -d'/' -f2)
KEXP_VER=$(echo "$KEXP_URL" | grep -oE 'download/[^/]+' | cut -d'/' -f2)
AUTOLOADER_VER=$(echo "$AUTOLOADER_URL" | grep -oE 'download/[^/]+' | cut -d'/' -f2)

if [ "${GITHUB_OUTPUT:-}" ]; then
    echo "elfldr_ver=${ELFLDR_VER}" >> "$GITHUB_OUTPUT"
    echo "kexp_ver=${KEXP_VER}" >> "$GITHUB_OUTPUT"
    echo "unified_autoloader_ver=${AUTOLOADER_VER}" >> "$GITHUB_OUTPUT"
fi

# Clean old dependency files
echo "Cleaning old binaries..."
rm -f "$DEST_DIR"/kexp-*.bin
rm -f "$DEST_DIR"/elfldr-*.elf
rm -f "$DEST_DIR"/kexp_v6.bin
rm -f "$DEST_DIR"/elfldr.elf
rm -f "$AUTOLOADER_DEST_DIR"/ps5-unified-autoloader*.elf

ELFLDR_FILE="elfldr-ps5-${ELFLDR_VER}.elf"
KEXP_FILE="kexp-${KEXP_VER}.bin"
AUTOLOADER_FILE="ps5-unified-autoloader.elf"

# Download assets
echo "Downloading $ELFLDR_URL to $DEST_DIR/$ELFLDR_FILE..."
curl -L -o "$DEST_DIR/$ELFLDR_FILE" "$ELFLDR_URL"

echo "Downloading $KEXP_URL to $DEST_DIR/$KEXP_FILE..."
curl -L -o "$DEST_DIR/$KEXP_FILE" "$KEXP_URL"

echo "Downloading $AUTOLOADER_URL to $AUTOLOADER_DEST_DIR/$AUTOLOADER_FILE..."
curl -L -o "$AUTOLOADER_DEST_DIR/$AUTOLOADER_FILE" "$AUTOLOADER_URL"

echo "Successfully downloaded all dependencies!"
echo "Dependency versions:"
echo "  - elfldr: $ELFLDR_VER (ps5-payload-dev/elfldr)"
echo "  - kexp: $KEXP_VER"
echo "  - unified-autoloader: $AUTOLOADER_VER"
ls -la "$DEST_DIR"
ls -la "$AUTOLOADER_DEST_DIR"
