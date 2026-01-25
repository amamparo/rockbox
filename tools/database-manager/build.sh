#!/bin/bash
#
# Rockbox Database Tool - Portable Version
#
# Builds and runs the Rockbox database indexer via Docker.
#
# Usage:
#   IPOD_PATH=/Volumes/IPOD ./build.sh           # Incremental update
#   IPOD_PATH=/Volumes/IPOD ./build.sh --full    # Full rebuild
#
# Environment:
#   IPOD_PATH       - Path to mounted iPod (required)
#   ROCKBOX_REPO    - Path to rockbox source (optional, clones if not set)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="rockbox-database-tool"

# Parse arguments
FULL_REBUILD=false
if [ "$1" = "--full" ]; then
    FULL_REBUILD=true
fi

# Validate IPOD_PATH
if [ -z "$IPOD_PATH" ]; then
    echo "Error: IPOD_PATH environment variable not set"
    echo "Usage: IPOD_PATH=/Volumes/IPOD $0 [--full]"
    exit 1
fi

if [ ! -d "$IPOD_PATH/.rockbox" ]; then
    echo "Error: $IPOD_PATH does not contain a .rockbox directory"
    exit 1
fi

# Docker image management
ensure_image() {
    local hash_file="$SCRIPT_DIR/.docker_image_hash"
    local current_hash
    current_hash=$(md5 -q "$SCRIPT_DIR/Dockerfile" 2>/dev/null || md5sum "$SCRIPT_DIR/Dockerfile" | cut -d' ' -f1)

    local needs_rebuild=false
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        needs_rebuild=true
    elif [ ! -f "$hash_file" ] || [ "$(cat "$hash_file")" != "$current_hash" ]; then
        echo "Dockerfile changed, rebuilding image..."
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        needs_rebuild=true
    fi

    if [ "$needs_rebuild" = true ]; then
        echo "Building Docker image '$IMAGE_NAME'..."
        echo "(This takes a while on first run - building ARM cross-compiler)"
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        echo "$current_hash" > "$hash_file"
    fi
}

echo "Rockbox Database Tool"
echo "iPod: $IPOD_PATH"
echo ""

ensure_image

# Determine rockbox source location
if [ -n "$ROCKBOX_REPO" ] && [ -d "$ROCKBOX_REPO" ]; then
    ROCKBOX_SRC="$ROCKBOX_REPO"
    MOUNT_SRC="-v $ROCKBOX_SRC:/src:ro"
    echo "Using local rockbox source: $ROCKBOX_SRC"
else
    # Use the rockbox clone inside the Docker image
    MOUNT_SRC=""
    echo "Using rockbox source from Docker image"
fi

echo ""
if [ "$FULL_REBUILD" = "true" ]; then
    echo "Mode: Full rebuild (clearing existing database)"
else
    echo "Mode: Incremental update"
fi
echo ""

# Run the database tool
docker run --rm \
    -e "FULL_REBUILD=$FULL_REBUILD" \
    $MOUNT_SRC \
    -v "$IPOD_PATH:/ipod:cached" \
    "$IMAGE_NAME" \
    /bin/bash -c '
        set -e

        # Use mounted source or fall back to image source
        if [ -d "/src" ]; then
            cp -a /src /rockbox
        else
            cp -a /home/rb/rockbox /rockbox
        fi

        mkdir -p /rockbox/build-dbtool
        cd /rockbox/build-dbtool

        echo "Configuring for iPod Video..."
        echo -e "22\nD" | ../tools/configure 2>&1 | tail -3

        echo "Compiling database tool..."
        make -j$(nproc) 2>&1 | tail -5

        echo ""
        cd /ipod

        if [ "$FULL_REBUILD" = "true" ]; then
            echo "Clearing existing database..."
            rm -f .rockbox/database_*.tcd .rockbox/database_tmp.tcd 2>/dev/null || true
        fi

        echo "Scanning music files..."
        /rockbox/build-dbtool/database.ipodvideo
    '

echo ""
echo "Database updated successfully!"
echo "You may need to reboot your iPod or select Database > Update Now."
