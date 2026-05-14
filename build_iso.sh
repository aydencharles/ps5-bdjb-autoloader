#!/bin/bash
set -e

# Ensure we are in the project root
cd "$(dirname "$0")"

BUILD_TYPE="dev"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --stable) BUILD_TYPE="stable" ;;
        --dev) BUILD_TYPE="dev" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "Starting PS5 BD-JB Autoloader Docker Builder ($BUILD_TYPE)..."

# Build the docker image if needed
docker compose build builder

# Run the build process
docker compose run --rm --remove-orphans -e BUILD_TYPE=$BUILD_TYPE builder
