#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

log "updating system packages..."
sudo apt-get update && sudo apt-get -y -qq dist-upgrade

log "installing system packages..."
sudo apt-get install -y -qq build-essential  \
    python3-dev python3-venv python3-smbus python3-spidev \
    python3-pip curl npm nodejs gcc g++ make python3


log "system packages ready..."