#!/bin/bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")

HOME="/home/pi"
PROJECT_DIR="$HOME/drone-rpi3"

ARM_VERSION="OpenNI-Linux-Arm-2.3.0.63"
OPENNISDK_SOURCE="$PROJECT_DIR/sdks/$ARM_VERSION"
OPENNISDK_DIR="$HOME/openni"
OPENNISDK_DEST="$OPENNISDK_DIR/$ARM_VERSION"
GNU_LIB_DIR="/lib/arm-linux-gnueabihf"
SIMPLE_READ_EXAMPLE="$OPENNISDK_DEST/Samples/SimpleRead"
OPENNI2_REDIST_DIR="$OPENNISDK_DEST/Redist"

DRONE_DIR="$HOME/drone-rpi3"
NAVIO2_GIT="https://github.com/emlid/Navio2.git"
NAVIO2_DIR="$HOME/Navio2"
NAVIO2_PYTHON_DIR="$NAVIO2_DIR/Python"
NAVIO2_WHEEL="$NAVIO2_PYTHON_DIR/dist/navio2-1.0.0-py3-none-any.whl"
PROJECT_INSTALL_DIR="$PROJECT_DIR/install"

LOG_DIR="$HOME/install_logs"
BUILD_LOG="$LOG_DIR/install.log"

mkdir -p "$LOG_DIR"
exec > >(tee "$BUILD_LOG") 2>&1

log() { 
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local calling_function=${FUNCNAME[1]:-"main"}
    local line_number=${BASH_LINENO[0]:-0}

    local formatted_message="[${timestamp}] [${SCRIPT_NAME}:${calling_function}:${line_number}] ${message}"
    echo -e "\n${formatted_message}\n"
 }

log "[ 1/12] updating system packages..."
sudo apt-get update && sudo apt-get -y -qq dist-upgrade

log "[ 2/12] installing system packages..."
sudo apt-get install -y -qq build-essential freeglut3 freeglut3-dev python3-opencv python3-dev python3-venv python3-smbus python3-spidev python3-numpy python3-pip curl npm nodejs gcc g++ make python3
sudo apt-get install --reinstall -y -qq libudev1

log "[ 3/12] copying OpenNI SDK distribution..."
if [ -d "$OPENNISDK_DIR" ]; then 
    rm -r "$OPENNISDK_DIR"
fi 

mkdir "$OPENNISDK_DIR"
cp -r "$OPENNISDK_SOURCE" "$OPENNISDK_DIR"

log "[ 4/12] installing OpenNI SDK..."
cd "$OPENNISDK_DEST"
chmod +x install.sh
bash ./install.sh

log "[ 5/12] sourcing OpenNI development environment..."
source OpenNIDevEnvironment

read -p "→ OpenNI SDK installed. Replug your device, then press ENTER." _

log "[ 6/12] verifying Orbbec device..."
if lsusb | grep -q 2bc5:0407; then
    echo "Orbbec Astra Mini S detected."
elif lsusb | grep -q 2bc5; then
    echo "[ERROR] Non-supported Orbbec device detected (e.g., Astra Pro)."
    exit 1
else
    echo "[ERROR] No Orbbec device found."
    exit 1
fi

log "[ 7/12] building $SIMPLE_READ_EXAMPLE..."
cd "$SIMPLE_READ_EXAMPLE"

if [ ! -d "$OPENNISDK_DEST/Redist" ]; then
  log "[ERROR] Missing $OPENNISDK_DEST/Redist (did the SDK extract correctly?)"
  exit 1
fi

make -j"$(nproc)" \
  OPENNI2_DIR="$OPENNISDK_DEST" \
  OPENNI2_REDIST="$OPENNISDK_DEST/Redist" \
  OPENNI2_INCLUDE="$OPENNISDK_DEST/Include"

if [ ! -f "$NAVIO2_WHEEL" ]; then 
    log "[ 8/12] cloning from $NAVIO2_GIT..."

    if [ -d "$NAVIO2_DIR" ]; then 
        rm -rf "$NAVIO2_DIR"
    fi 

    cd "$HOME"
    git clone "$NAVIO2_GIT"
    cd "$NAVIO2_PYTHON_DIR" || { log "missing $NAVIO2_PYTHON_DIR"; exit 1; }
    python3 -m venv env --system-site-packages
    set +u; source env/bin/activate; set -u
    python3 -m pip install wheel
    python3 setup.py bdist_wheel
    set +u; deactivate; set -u
else 
    log "[ 8/12] skipping cloning $NAVIO2_GIT because $NAVIO2_WHEEL aleady exists..."
fi

log "[ 9/12] checking for drone project virtual environment..."
cd "$DRONE_DIR"

if [ ! -d .venv ]; then 
    python3 -m venv .venv --system-site-packages
    set +u; source .venv/bin/activate; set -u
    python -m pip install --upgrade "pip==24.0" "setuptools<69" "wheel<0.41" "tomli>=2.0.1"
    python3 -m pip install "$NAVIO2_PYTHON_DIR/dist/navio2-1.0.0-py3-none-any.whl"
    PIP_PREFER_BINARY=1 python3 -m pip install -r requirements.txt
    set +u; deactivate; set -u
else 
    set +u; source .venv/bin/activate; set -u
    python -m pip install --upgrade "pip==24.0" "setuptools<69" "wheel<0.41" "tomli>=2.0.1"
    python3 -m pip install "$NAVIO2_PYTHON_DIR/dist/navio2-1.0.0-py3-none-any.whl"
    PIP_PREFER_BINARY=1 python3 -m pip install -r requirements.txt
    set +u; deactivate; set -u
fi

log "[10/12] adding environmental variables..."
if ! grep -q "export OPENNI2_REDIST=.*$OPENNI2_REDIST_DIR" ~/.bashrc; then 
    echo "OPENNI2_REDIST=$OPENNI2_REDIST_DIR" >> ~/.bashrc
    echo "-> added $OPENNI2_REDIST_DIR to OPENNI2_REDIST environmental variable in ~/.bashrc"
    source ~/.bashrc 
fi 

log "[11/12] moving dlls..."
sudo cp -r "$OPENNI2_REDIST_DIR/"* "/lib/"

log "[12/12] verifying builds..."
file "$SIMPLE_READ_EXAMPLE/Bin/Arm-Release/SimpleRead"
file "$NAVIO2_WHEEL"

log "✅ Install complete. Logs saved to: $BUILD_LOG"
exit 0