#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

OPENNISDK_SOURCE="$PROJECT_DIR/sdks/$ARM_VERSION"

log "copying OpenNI SDK distribution..."
if [ -d "$OPENNISDK_DIR" ]; then 
    rm -r "$OPENNISDK_DIR"
fi 

mkdir "$OPENNISDK_DIR"
cp -r "$OPENNISDK_SOURCE" "$OPENNISDK_DIR"

log "installing OpenNI SDK..."
cd "$OPENNISDK_DEST"
chmod +x install.sh
bash ./install.sh

log "sourcing OpenNI development environment..."
source OpenNIDevEnvironment

read -p "→ OpenNI SDK installed. Replug your device, then press ENTER." _

log "verifying Orbbec device..."
if lsusb | grep -q 2bc5:0407; then
    echo "Orbbec Astra Mini S detected."
elif lsusb | grep -q 2bc5; then
    echo "[ERROR] Non-supported Orbbec device detected (e.g., Astra Pro)."
    exit 1
else
    echo "[ERROR] No Orbbec device found."
    exit 1
fi

log "building $SIMPLE_READ_EXAMPLE..."
cd "$SIMPLE_READ_EXAMPLE"

if [ ! -d "$OPENNISDK_REDIST_DIR" ]; then
  log "[ERROR] Missing $OPENNISDK_REDIST_DIR (did the SDK extract correctly?)"
  exit 1
fi

make -j"$(nproc)" \
  OPENNI2_DIR="$OPENNISDK_DEST" \
  OPENNI2_REDIST="$OPENNISDK_REDIST_DIR" \
  OPENNI2_INCLUDE="$OPENNISDK_DEST/Include"