#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Root Makefile for Rockbox builds
#
# Usage:
#   make              - Show help
#   make build        - Build Rockbox firmware for iPod Video (via Docker)
#   make rbutil       - Build Rockbox Utility for macOS (native)
#   make clean        - Remove build artifacts

.PHONY: help build rbutil mount install database build_database update_database eject clean

help:
	@echo "Rockbox Build System"
	@echo ""
	@echo "Build targets:"
	@echo "  make build    - Build Rockbox firmware for iPod Video 5.5G (via Docker)"
	@echo "  make rbutil   - Build Rockbox Utility for macOS Apple Silicon (native)"
	@echo "  make clean    - Remove build artifacts from output/"
	@echo ""
	@echo "iPod targets:"
	@echo "  make mount          - Detect and mount connected device"
	@echo "  make install        - Install Rockbox to device (runs mount first)"
	@echo "  make build_database - Full rebuild of music database (clears existing)"
	@echo "  make update_database - Update database (only new/changed files)"
	@echo "  make eject          - Safely eject device"
	@echo ""
	@echo "Artifacts are placed in output/"
	@echo ""
	@echo "For other targets or manual builds, see docs/README"

build:
	./tools/docker_ipodvideo/build.sh build

mount:
	./tools/mount_device.sh

install: mount
	./tools/install_ipod.sh

build_database: mount
	./tools/build_database.sh --full

update_database: mount
	./tools/build_database.sh

# Alias for backwards compatibility
database: build_database

eject:
	./tools/mount_ipod.sh --eject

rbutil:
	./utils/rbutilqt/macos/build.sh build

clean:
	./tools/docker_ipodvideo/build.sh clean
	./utils/rbutilqt/macos/build.sh clean
