#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")

SCRIPTS_DIR="/home/pi/drone-rpi3/install/scripts"
source "$SCRIPTS_DIR/00_common.env"
source "$SCRIPTS_DIR/00_lib.sh"

CONF=/boot/config.txt
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/boot/config.txt.bak-${STAMP}"
OVERLAY_DIR=/boot/overlays
OVERLAY_SOURCE="$PROJECT_DIR/overlays"

require_root(){
  if [[ $EUID -ne 0 ]]; then
    echo "please run $SCRIPT_NAME with sudo." >&2
    exit 1
  fi
}

remove_lines(){
  local key="$1"
  sed -i -E "s/^[#[:space:]]*${key}=.*$//" "$CONF"
}
ensure_line(){
  local key="$1" value="$2"
  if ! grep -q -E "^${key}=${value}$" "$CONF"; then
    echo "${key}=${value}" >> "$CONF"
    log "added: ${key}=${value}"
  else
    log "already present: ${key}=${value}"
  fi
}

require_root

if [[ ! -f "$CONF" ]]; then
  echo "cannot find $CONF" >&2
  exit 1
fi

cp -a "$CONF" "$BACKUP"
log "backed up $CONF -> $BACKUP"

# cleanup config file
remove_lines "dtoverlay"
remove_lines "dtparam"

# ensure overlay and SPI are enabled
ensure_line "dtoverlay" "pi3-disable-bt"
ensure_line "dtparam" "spi=on"
ensure_line "dtparam" "i2c1=on"
ensure_line "dtparam" "i2c1_baudrate=1000000"
ensure_line "dtoverlay" "rcio"
ensure_line "dtoverlay" "spi0-4cs"
ensure_line "dtoverlay" "spi1-1cs,cs0_pin=16,cs0_spidev=disabled"
ensure_line "dtoverlay" "navio-rgb"
ensure_line "dtoverlay" "vc4-fkms-v3d"

log "verifying current settings:"
grep -E '^(dtoverlay|dtparam)=' "$CONF" | sed 's/^/  /'

log "copying overlays."
sudo cp -rf "$OVERLAY_SOURCE/" "$OVERLAY_DIR/"