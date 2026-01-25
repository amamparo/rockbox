#!/bin/bash
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Docker build script for iPod Video (5.5th gen)
#
# Usage:
#   ./build.sh [build|clean]
#
#   build  - Build rockbox.ipod and rockbox.zip (default)
#   clean  - Remove output directory
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROCKBOX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IMAGE_NAME="rockbox-ipodvideo"
OUTPUT_DIR="$ROCKBOX_ROOT/output"

usage() {
    echo "Usage: $0 [build|clean]"
    echo ""
    echo "  build  - Build rockbox.ipod and rockbox.zip (default)"
    echo "  clean  - Remove output directory"
    exit 1
}

build_image() {
    echo "Building Docker image '$IMAGE_NAME'..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    # Save Dockerfile hash to detect future changes
    local hash_file="$OUTPUT_DIR/.docker_image_hash"
    mkdir -p "$OUTPUT_DIR"
    (md5 -q "$SCRIPT_DIR/Dockerfile" 2>/dev/null || md5sum "$SCRIPT_DIR/Dockerfile" | cut -d' ' -f1) > "$hash_file"
}

ensure_image() {
    local hash_file="$OUTPUT_DIR/.docker_image_hash"
    local current_hash
    current_hash=$(md5 -q "$SCRIPT_DIR/Dockerfile" 2>/dev/null || md5sum "$SCRIPT_DIR/Dockerfile" | cut -d' ' -f1)

    # Rebuild if image doesn't exist or Dockerfile changed
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        build_image
    elif [ ! -f "$hash_file" ] || [ "$(cat "$hash_file")" != "$current_hash" ]; then
        echo "Dockerfile changed, rebuilding image..."
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        build_image
    fi
}

do_build() {
    ensure_image
    mkdir -p "$OUTPUT_DIR"

    echo "Building Rockbox for iPod Video..."
    docker run --rm \
        -v "$ROCKBOX_ROOT:/src:ro" \
        -v "$OUTPUT_DIR:/output" \
        "$IMAGE_NAME" \
        /bin/bash -c '
            set -e
            # Copy source to writable location (build modifies tools/)
            cp -a /src /rockbox
            # Remove host-compiled tool binaries so they get rebuilt for Linux
            rm -f /rockbox/tools/bmp2rb /rockbox/tools/scramble /rockbox/tools/convbdf \
                  /rockbox/tools/mkboot /rockbox/tools/rdf2binary /rockbox/tools/uclpack \
                  /rockbox/tools/codepages
            mkdir -p /rockbox/build
            cd /rockbox/build
            ../tools/configure --target=22 --type=N
            make -j$(nproc)
            make fullzip
            cp -v rockbox.ipod /output/
            cp -v rockbox-full.zip /output/rockbox.zip
        '

    echo ""
    echo "Build complete! Artifacts in: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR"
}

do_clean() {
    echo "Cleaning output directory..."
    rm -rf "$OUTPUT_DIR"
    echo "Done."
}

case "${1:-build}" in
    build)
        do_build
        ;;
    clean)
        do_clean
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Error: Unknown command '$1'"
        usage
        ;;
esac
