#!/bin/bash
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Build and run the database tool to index music on a mounted iPod
#
# Usage:
#   build_database.sh         - Update database (incremental)
#   build_database.sh --full  - Full rebuild (clears existing database)
#
# Prerequisites: Run 'make mount' first to mount the iPod
# Reads "database scan paths" from .rockbox/config.cfg on the iPod.

set -e

FULL_REBUILD=false
if [ "$1" = "--full" ]; then
    FULL_REBUILD=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROCKBOX_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="rockbox-ipodvideo"

ensure_image() {
    local dockerfile="$SCRIPT_DIR/docker_ipodvideo/Dockerfile"
    local hash_file="$ROCKBOX_ROOT/output/.docker_image_hash"
    local current_hash
    current_hash=$(md5 -q "$dockerfile" 2>/dev/null || md5sum "$dockerfile" | cut -d' ' -f1)

    # Rebuild if image doesn't exist or Dockerfile changed
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
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR/docker_ipodvideo"
        mkdir -p "$(dirname "$hash_file")"
        echo "$current_hash" > "$hash_file"
    fi
}

# Get iPod mount point from shared mount script
IPOD_PATH=$("$SCRIPT_DIR/mount_ipod.sh" --get) || {
    echo "Error: iPod not mounted"
    echo "Run 'make mount' first"
    exit 1
}

echo "Using iPod at: $IPOD_PATH"

if [ ! -d "$IPOD_PATH/.rockbox" ]; then
    echo "Error: $IPOD_PATH does not contain a .rockbox directory"
    exit 1
fi

# Ensure Docker image exists
ensure_image

echo ""
echo "Building and running database indexer..."

# Run the database tool via Docker, mounting the iPod
docker run --rm \
    -e "FULL_REBUILD=$FULL_REBUILD" \
    -v "$ROCKBOX_ROOT:/src:ro" \
    -v "$IPOD_PATH:/ipod:cached" \
    "$IMAGE_NAME" \
    /bin/bash -c '
        set -e
        # Copy source to writable location
        cp -a /src /rockbox
        mkdir -p /rockbox/build-dbtool
        cd /rockbox/build-dbtool

        # Configure for iPod Video Database tool
        echo "Configuring..."
        echo -e "22\nD" | ../tools/configure 2>&1 | tail -5

        # Build the database tool
        echo "Compiling database tool..."
        make -j$(nproc)

        # Run from iPod root
        echo ""
        cd /ipod

        # Remove existing database if full rebuild requested
        if [ "$FULL_REBUILD" = "true" ]; then
            echo "Clearing existing database..."
            rm -f .rockbox/database_*.tcd .rockbox/database_tmp.tcd 2>/dev/null || true
        fi

        /rockbox/build-dbtool/database.ipodvideo
    '

echo ""
echo "Database updated successfully!"
echo "You may need to reboot your iPod or select Database > Update Now."
