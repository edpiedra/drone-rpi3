#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

log "adding environmental variables..."
if ! grep -q "export OPENNI2_REDIST=.*$OPENNISDK_REDIST_DIR" ~/.bashrc; then 
    echo "OPENNI2_REDIST=$OPENNISDK_REDIST_DIR" >> ~/.bashrc
    echo "-> added $OPENNISDK_REDIST_DIR to OPENNI2_REDIST environmental variable in ~/.bashrc"
    source ~/.bashrc 
fi 
if ! grep -q "export CXX=arm-linux-gnueabihf-g++" ~/.bashrc; then 
    echo "CXX=arm-linux-gnueabihf-g++" >> ~/.bashrc
    echo "-> added arm-linux-gnueabihf-g++ to CXX environmental variable in ~/.bashrc"
    source ~/.bashrc 
fi 

log "moving dlls..."
sudo cp -r "$OPENNISDK_REDIST_DIR/"* "/lib/"

log "verifying builds..."
file "$SIMPLE_READ_EXAMPLE/Bin/Arm-Release/SimpleRead"
file "$NAVIO2_WHEEL"