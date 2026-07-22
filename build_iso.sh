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
AUTOLOADER_DEST_DIR="payloads/autoloader"

# Prefer `docker compose` plugin, fall back to standalone docker-compose
docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    else
        echo "Error: neither 'docker compose' nor 'docker-compose' is available." >&2
        exit 1
    fi
}

# Build original ps5-payload-dev/elfldr via Docker + official SDK
build_elfldr() {
    local ELFLDR_DIR="third_party/ps5-elfldr"
    local SDK_IMAGE="ps5-payload-sdk-elfldr"
    local SDK_DOCKERFILE="scripts/Dockerfile.elfldr-sdk"

    if [ -x "$ELFLDR_DIR/build.sh" ]; then
        # Forks may ship a helper script
        (cd "$ELFLDR_DIR" && ./build.sh)
        return
    fi

    if [ -n "${PS5_PAYLOAD_SDK:-}" ] && [ -f "${PS5_PAYLOAD_SDK}/toolchain/prospero.mk" ]; then
        echo "Building elfldr with host PS5_PAYLOAD_SDK=${PS5_PAYLOAD_SDK}..."
        (cd "$ELFLDR_DIR" && make clean all)
        return
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: building original elfldr requires Docker or PS5_PAYLOAD_SDK." >&2
        exit 1
    fi

    if [[ "$(docker images -q "$SDK_IMAGE" 2>/dev/null)" == "" ]]; then
        echo "Building Docker SDK image $SDK_IMAGE (first time may take a while)..."
        docker build -t "$SDK_IMAGE" -f "$SDK_DOCKERFILE" scripts/
    fi

    echo "Building elfldr-ps5.elf via Docker ($SDK_IMAGE)..."
    docker run --rm -v "$(cd "$ELFLDR_DIR" && pwd)":/src -w /src "$SDK_IMAGE" make clean all
}

# Helper to build dependencies from source
build_source_deps() {
    echo "=== Building dependencies from source ==="
    
    if [ ! -e "third_party/ps5-elfldr/.git" ] || [ ! -e "third_party/ps5-kexp/.git" ] || [ ! -e "third_party/ps5-unified-autoloader/.git" ]; then
        echo "Error: Submodules are not initialized. Please run: git submodule update --init --recursive" >&2
        exit 1
    fi
    
    # Clean old binaries
    rm -f "$DEST_DIR"/kexp-*.bin
    rm -f "$DEST_DIR"/elfldr-*.elf
    rm -f "$DEST_DIR"/kexp_v6.bin
    rm -f "$DEST_DIR"/elfldr.elf
    rm -f "$AUTOLOADER_DEST_DIR"/ps5-unified-autoloader*.elf
    
    echo "Building ps5-payload-dev/elfldr..."
    build_elfldr
    ELFLDR_VER=$(git -C third_party/ps5-elfldr describe --tags --always)
    if [ ! -f third_party/ps5-elfldr/elfldr-ps5.elf ]; then
        echo "Error: elfldr build succeeded but elfldr-ps5.elf not found." >&2
        exit 1
    fi
    cp third_party/ps5-elfldr/elfldr-ps5.elf "$DEST_DIR/elfldr-ps5-${ELFLDR_VER}.elf"
    
    echo "Building ps5-kexp..."
    (cd third_party/ps5-kexp && ./build.sh)
    KEXP_VER=$(git -C third_party/ps5-kexp describe --tags --always)
    cp third_party/ps5-kexp/build/kexp.bin "$DEST_DIR/kexp-${KEXP_VER}.bin"
    
    echo "Building ps5-unified-autoloader..."
    (cd third_party/ps5-unified-autoloader && ./build_release.sh -b)
    AUTOLOADER_VER=$(git -C third_party/ps5-unified-autoloader describe --tags --always)
    AUTOLOADER_ELF=$(ls third_party/ps5-unified-autoloader/autoloader_v*.elf 2>/dev/null | head -n 1)
    if [ -z "$AUTOLOADER_ELF" ]; then
        echo "Error: ps5-unified-autoloader build succeeded but no output ELF found." >&2
        exit 1
    fi
    cp "$AUTOLOADER_ELF" "$AUTOLOADER_DEST_DIR/ps5-unified-autoloader.elf"

    if [ "${GITHUB_OUTPUT:-}" ]; then
        echo "elfldr_ver=${ELFLDR_VER}" >> "$GITHUB_OUTPUT"
        echo "kexp_ver=${KEXP_VER}" >> "$GITHUB_OUTPUT"
        echo "unified_autoloader_ver=${AUTOLOADER_VER}" >> "$GITHUB_OUTPUT"
    fi
    
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
    HAS_AUTOLOADER=$(ls "$AUTOLOADER_DEST_DIR"/ps5-unified-autoloader.elf 2>/dev/null | head -n 1)
    
    if [ -n "$HAS_KEXP" ] && [ -n "$HAS_ELFLDR" ] && [ -n "$HAS_AUTOLOADER" ]; then
        echo "Dependencies already present."
    else
        # Prefer prebuilt downloads; source build needs Docker SDK image
        download_prebuilt_deps
    fi
fi

echo "Starting PS5 BD-JB Autoloader Docker Builder ($BUILD_TYPE)..."

# Build the docker image if needed
docker_compose build builder

# Run the build process
docker_compose run --rm --remove-orphans -e BUILD_TYPE=$BUILD_TYPE builder
