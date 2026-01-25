# Rockbox Database Manager

Self-contained tool to build the Rockbox music database on a computer (much faster than on-device).

## Requirements

- Docker
- Mounted iPod with Rockbox installed

## Usage

### Via Make

```bash
# Full rebuild (clears existing database)
IPOD_PATH=/Volumes/IPOD make build_database

# Incremental update (only new/changed files)
IPOD_PATH=/Volumes/IPOD make update_database
```

### Via Script

```bash
# Incremental update
IPOD_PATH=/Volumes/IPOD ./build.sh

# Full rebuild
IPOD_PATH=/Volumes/IPOD ./build.sh --full
```

### Integration with Parent Makefile

In your parent Makefile:

```makefile
IPOD_PATH ?= /Volumes/IPOD

build_database:
	cd database-manager && IPOD_PATH=$(IPOD_PATH) ./build.sh --full

update_database:
	cd database-manager && IPOD_PATH=$(IPOD_PATH) ./build.sh
```

## Optional: Use Local Rockbox Source

By default, the Docker image includes a rockbox clone. To use a local checkout instead:

```bash
IPOD_PATH=/Volumes/IPOD ROCKBOX_REPO=/path/to/rockbox ./build.sh
```

## First Run

The first run takes a while (~10-15 minutes) because it:
1. Builds the Docker image
2. Compiles the ARM cross-compiler toolchain

Subsequent runs reuse the cached image and are much faster.

## Files

- `Dockerfile` - Docker image with ARM toolchain
- `build.sh` - Main build script
- `Makefile` - Convenience targets
