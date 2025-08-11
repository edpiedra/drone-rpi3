#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

echo "run Simple Read example with: "
echo "sudo $SIMPLE_READ_EXAMPLE/Bin/Arm-Release/SimpleRead"
