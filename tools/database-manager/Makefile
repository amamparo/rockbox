# Rockbox Database Manager - Portable Makefile
#
# Usage:
#   IPOD_PATH=/Volumes/IPOD make build_database    # Full rebuild
#   IPOD_PATH=/Volumes/IPOD make update_database   # Incremental
#
# Or set IPOD_PATH in your environment/parent Makefile

.PHONY: build_database update_database help

help:
	@echo "Rockbox Database Manager"
	@echo ""
	@echo "Usage:"
	@echo "  IPOD_PATH=/Volumes/IPOD make build_database   - Full rebuild (clears existing)"
	@echo "  IPOD_PATH=/Volumes/IPOD make update_database  - Incremental update"
	@echo ""
	@echo "Set IPOD_PATH to your mounted iPod path."

build_database:
	@./build.sh --full

update_database:
	@./build.sh
