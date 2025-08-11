#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

log "installing requirements in drone virtual environment..."
cd "$PROJECT_DIR"

if [ ! -d .venv ]; then 
log "creating virtual environment..."
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