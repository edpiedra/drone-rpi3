#!/usr/bin/env bash
set -Eeuo pipefail

$SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

log "adding environmental variables..."
if ! grep -q "export OPENNI2_REDIST=.*$OPENNI2_REDIST_DIR" ~/.bashrc; then 
    echo "OPENNI2_REDIST=$OPENNI2_REDIST_DIR" >> ~/.bashrc
    echo "-> added $OPENNI2_REDIST_DIR to OPENNI2_REDIST environmental variable in ~/.bashrc"
    source ~/.bashrc 
fi 

log "moving dlls..."
sudo cp -r "$OPENNI2_REDIST_DIR/"* "/lib/"

log "verifying builds..."
file "$SIMPLE_READ_EXAMPLE/Bin/Arm-Release/SimpleRead"
file "$NAVIO2_WHEEL"