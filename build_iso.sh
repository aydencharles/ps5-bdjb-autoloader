#!/bin/bash
set -e

# Ensure we are in the project root
cd "$(dirname "$0")"

BUILD_TYPE="dev"
DEP_ACTION="auto"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --stable) BUILD_TYPE="stable" ;;
        --dev) BUILD_TYPE="dev" ;;
        --build-deps|-b) DEP_ACTION="build" ;;
        --download-deps|-d) DEP_ACTION="download" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

DEST_DIR="payloads/poops/src/org/bdj/external"

# Helper to build dependencies from source
build_source_deps() {
    echo "=== Building dependencies from source ==="
    
    if [ ! -e "third_party/ps5-elfldr/.git" ] || [ ! -e "third_party/ps5-kexp/.git" ] || [ ! -e "third_party/ps5-payload-manager/.git" ]; then
        echo "Error: Submodules are not initialized. Please run: git submodule update --init --recursive" >&2
        exit 1
    fi
    
    # Clean old binaries
    rm -f "$DEST_DIR"/kexp-*.bin
    rm -f "$DEST_DIR"/elfldr-*.elf
    rm -f "$DEST_DIR"/kexp_v6.bin
    rm -f "$DEST_DIR"/elfldr.elf
    rm -f ps5_autoloader/pldmgr-*.elf
    rm -f ps5_autoloader/pldmgr_v*.elf
    
    echo "Building ps5-elfldr..."
    (cd third_party/ps5-elfldr && ./build.sh)
    ELFLDR_VER=$(git -C third_party/ps5-elfldr describe --tags --always)
    cp third_party/ps5-elfldr/elfldr-ps5.elf "$DEST_DIR/elfldr-ps5-${ELFLDR_VER}.elf"
    
    echo "Building ps5-kexp..."
    (cd third_party/ps5-kexp && ./build.sh)
    KEXP_VER=$(git -C third_party/ps5-kexp describe --tags --always)
    cp third_party/ps5-kexp/build/kexp.bin "$DEST_DIR/kexp-${KEXP_VER}.bin"
    
    echo "Building ps5-payload-manager..."
    (cd third_party/ps5-payload-manager && ./build_release.sh)
    PLDMGR_ELF=$(ls third_party/ps5-payload-manager/pldmgr_v*.elf 2>/dev/null | head -n 1)
    if [ -z "$PLDMGR_ELF" ]; then
        echo "Error: Failed to find built pldmgr ELF." >&2
        exit 1
    fi
    PLDMGR_NAME=$(basename "$PLDMGR_ELF")
    cp "$PLDMGR_ELF" "ps5_autoloader/$PLDMGR_NAME"
    sed -E "s/pldmgr[_v|-]+[0-9.]+\.elf/$PLDMGR_NAME/" ps5_autoloader/autoload.txt > ps5_autoloader/autoload.txt.tmp
    mv ps5_autoloader/autoload.txt.tmp ps5_autoloader/autoload.txt
    
    echo "Source build complete."
}

# Helper to download dependencies
download_prebuilt_deps() {
    echo "=== Downloading dependencies from GitHub releases ==="
    ./scripts/download_deps.sh
}

# Resolve dependency action
if [ "$DEP_ACTION" = "download" ]; then
    download_prebuilt_deps
elif [ "$DEP_ACTION" = "build" ]; then
    build_source_deps
else
    # Auto mode: check if binaries exist
    HAS_KEXP=$(ls "$DEST_DIR"/kexp-*.bin 2>/dev/null | head -n 1)
    HAS_ELFLDR=$(ls "$DEST_DIR"/elfldr-*.elf 2>/dev/null | head -n 1)
    HAS_PLDMGR=$(ls ps5_autoloader/pldmgr-*.elf ps5_autoloader/pldmgr_v*.elf 2>/dev/null | head -n 1)
    
    if [ -n "$HAS_KEXP" ] && [ -n "$HAS_ELFLDR" ] && [ -n "$HAS_PLDMGR" ]; then
        echo "Dependencies already present."
    else
        # If submodules checked out, build from source
        if [ -e "third_party/ps5-elfldr/.git" ] && [ -e "third_party/ps5-kexp/.git" ] && [ -e "third_party/ps5-payload-manager/.git" ]; then
            build_source_deps
        else
            download_prebuilt_deps
        fi
    fi
fi

echo "Starting PS5 BD-JB Autoloader Docker Builder ($BUILD_TYPE)..."

# Build the docker image if needed
docker compose build builder

# Run the build process
docker compose run --rm --remove-orphans -e BUILD_TYPE=$BUILD_TYPE builder
