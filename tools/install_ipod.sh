#!/bin/bash
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Install Rockbox to a connected iPod
#
# Prerequisites: Run 'make mount' first to mount the iPod
#
# This script:
# 1. Gets the iPod mount point from mount_ipod.sh
# 2. Extracts rockbox.zip to local cache (if newer)
# 3. Syncs .rockbox to iPod using rsync (fast incremental updates)
# 4. Installs third-party themes from themes/thirdparty/*.zip
# 5. Installs first-party themes from themes/firstparty/*/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$ROOT_DIR/output"
ZIP_FILE="$OUTPUT_DIR/rockbox.zip"
CACHE_DIR="$OUTPUT_DIR/.rockbox-cache"
THEMES_DIR="$ROOT_DIR/themes/thirdparty"
THEMES_FIRSTPARTY_DIR="$ROOT_DIR/themes/firstparty"
THEMES_CACHE_DIR="$OUTPUT_DIR/.themes-cache"

# Check if rockbox.zip exists
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: $ZIP_FILE not found"
    echo "Run 'make build' first to create the firmware package"
    exit 1
fi

# Get iPod mount point from shared mount script
MOUNT_POINT=$("$SCRIPT_DIR/mount_ipod.sh" --get) || {
    echo "Error: iPod not mounted"
    echo "Run 'make mount' first"
    exit 1
}

echo "Using iPod at $MOUNT_POINT"

# Extract to local cache if zip is newer than cache
update_cache() {
    if [ ! -d "$CACHE_DIR/.rockbox" ] || [ "$ZIP_FILE" -nt "$CACHE_DIR/.rockbox" ]; then
        echo "Updating local cache..."
        rm -rf "$CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        unzip -q -o "$ZIP_FILE" -d "$CACHE_DIR"
        touch "$CACHE_DIR/.rockbox"  # Update timestamp for future comparisons
    else
        echo "Local cache is up to date"
    fi
}

# Extract theme zips to cache if newer, then sync to iPod
install_themes() {
    # Install third-party themes (from zip files)
    if [ -d "$THEMES_DIR" ]; then
        local theme_zips=("$THEMES_DIR"/*.zip)
        if [ -e "${theme_zips[0]}" ]; then
            echo "Installing third-party themes..."
            mkdir -p "$THEMES_CACHE_DIR"

            for theme_zip in "${theme_zips[@]}"; do
                local theme_name
                theme_name=$(basename "$theme_zip" .zip)
                local theme_cache="$THEMES_CACHE_DIR/$theme_name"

                # Extract if zip is newer than cache
                if [ ! -d "$theme_cache" ] || [ "$theme_zip" -nt "$theme_cache" ]; then
                    echo "  Extracting $theme_name..."
                    rm -rf "$theme_cache"
                    mkdir -p "$theme_cache"
                    unzip -q -o "$theme_zip" -d "$theme_cache"
                    touch "$theme_cache"
                fi

                # Sync theme to iPod (no --delete, we want to merge)
                # Theme zips contain a .rockbox folder, so sync its contents
                echo "  Syncing $theme_name..."
                rsync -a "$theme_cache/.rockbox/" "$MOUNT_POINT/.rockbox/"
            done
        fi
    fi

    # Install first-party themes (from directories)
    if [ -d "$THEMES_FIRSTPARTY_DIR" ]; then
        local has_themes=false
        for theme_dir in "$THEMES_FIRSTPARTY_DIR"/*/; do
            if [ -d "$theme_dir/.rockbox" ]; then
                has_themes=true
                break
            fi
        done

        if [ "$has_themes" = true ]; then
            echo "Installing first-party themes..."
            for theme_dir in "$THEMES_FIRSTPARTY_DIR"/*/; do
                if [ -d "$theme_dir/.rockbox" ]; then
                    local theme_name
                    theme_name=$(basename "$theme_dir")
                    echo "  Syncing $theme_name..."
                    rsync -a "$theme_dir/.rockbox/" "$MOUNT_POINT/.rockbox/"
                fi
            done
        fi
    fi
}

# Update local cache from zip
update_cache

# Sync to iPod using rsync (only transfers changed files)
# Exclude user-generated files that should be preserved
echo "Syncing .rockbox to iPod..."
rsync -a --delete \
    --exclude='config.cfg' \
    --exclude='config.cfg.*' \
    --exclude='.resume.cfg' \
    --exclude='.resume.cfg.*' \
    --exclude='.playlist_control' \
    --exclude='.playlist_control.*' \
    --exclude='database_*.tcd' \
    --exclude='database_idx.tcd' \
    --exclude='playername.txt' \
    --exclude='battery_bench.txt' \
    "$CACHE_DIR/.rockbox" "$MOUNT_POINT/"

# Verify sync succeeded
if [ ! -d "$MOUNT_POINT/.rockbox" ]; then
    echo "Error: Sync failed - .rockbox directory not found"
    exit 1
fi

# Install third-party themes
install_themes

echo "Rockbox installed successfully!"
echo "Run 'make eject' when ready to disconnect."
