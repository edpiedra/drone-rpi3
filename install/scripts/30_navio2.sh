#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

NAVIO2_GIT="https://github.com/emlid/Navio2.git"

if [ ! -f "$NAVIO2_WHEEL" ]; then 
    log "cloning from $NAVIO2_GIT..."

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
    log "skipping cloning $NAVIO2_GIT because $NAVIO2_WHEEL aleady exists..."
fi 

log ="adding navio2 related overlays..."
sudo bash "$SCRIPTS_DIR/131_navio2_overlays.sh"
