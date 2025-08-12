#!/usr/bin/env bash
set -euo pipefail

REQUIRED_DTBO=(rcio.dtbo spi0-4cs.dtbo spi1-1cs.dtbo)  # core for Navio2
CANDIDATE_BOOT_DIRS=(/boot/firmware /boot)

log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$*"; }

detect_bootdir() {
  local d
  for d in "${CANDIDATE_BOOT_DIRS[@]}"; do
    if [[ -f "$d/config.txt" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

check_dtbo_presence() {
  local over="$1/overlays"
  [[ -d "$over" ]] || { echo "NO_OVERLAYS_DIR"; return 0; }
  local missing=()
  for f in "${REQUIRED_DTBO[@]}"; do
    [[ -f "$over/$f" ]] || missing+=("$f")
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'MISSING_DTBO %s\n' "${missing[@]}"
  else
    echo "OK"
  fi
}

show_status() {
  log "Kernel: $(uname -a)"
  local bootdir; bootdir="$(detect_bootdir || true)"
  if [[ -n "${bootdir:-}" ]]; then
    log "Boot config found at: $bootdir/config.txt"
    log "Overlays dir: $bootdir/overlays"
    log "First 10 lines of config.txt:"
    head -n 10 "$bootdir/config.txt" | sed 's/^/  /'
  else
    log "Could not find config.txt in /boot or /boot/firmware"
  fi
  echo

  log "Overlay(s) currently applied (at runtime):"
  if [[ -d /proc/device-tree/overlays ]]; then
    ls -1 /proc/device-tree/overlays || true
  else
    echo "  (no overlays dir)"
  fi
  echo

  log "DTBO presence check:"
  if [[ -n "${bootdir:-}" ]]; then
    local res; res="$(check_dtbo_presence "$bootdir")"
    if [[ "$res" == "OK" ]]; then
      echo "  All required DTBOs present."
    elif [[ "$res" == "NO_OVERLAYS_DIR" ]]; then
      echo "  $bootdir/overlays does not exist (boot partition not mounted? wrong image?)"
    else
      echo "  Missing: ${res#MISSING_DTBO }"
    fi
  fi
  echo

  log "SPI devices:"
  ls -1 /dev/spidev* 2>/dev/null || echo "  (none)"
  echo

  log "PWM chips:"
  ls -d /sys/class/pwm/pwmchip* 2>/dev/null || echo "  (none)"
}

apply_fix() {
  local bootdir; bootdir="$(detect_bootdir)"
  local conf="$bootdir/config.txt"
  local overdir="$bootdir/overlays"

  # sanity: overlays dir + files must exist
  if [[ ! -d "$overdir" ]]; then
    echo "ERROR: $overdir does not exist. Cannot proceed." >&2
    echo "→ This usually means you’re looking at the wrong boot mount OR your boot files are incomplete." >&2
    echo "  Run:  mount | egrep ' /boot|/boot/firmware '   and confirm which is the actual boot partition." >&2
    exit 2
  fi
  local miss=()
  for f in "${REQUIRED_DTBO[@]}"; do
    [[ -f "$overdir/$f" ]] || miss+=("$f")
  done
  if (( ${#miss[@]} > 0 )); then
    echo "ERROR: Missing DTBO(s): ${miss[*]} in $overdir" >&2
    echo "→ You need to restore/copy these overlay files to $overdir before continuing." >&2
    echo "  Options:" >&2
    echo "   - Mount an official Emlid/Navio2 image and copy $overdir/{${REQUIRED_DTBO[*]// /, }} to this system." >&2
    echo "   - Or reinstall the bootloader/firmware package that provides overlays for your kernel." >&2
    exit 3
  fi

  # backup and edit
  local backup="${conf}.bak.$(date +%Y%m%d-%H%M%S)"
  sudo cp -a "$conf" "$backup"
  log "Backed up $conf -> $backup"

  # Remove any existing lines for these keys to avoid duplicates
  sudo sed -i -E 's/^[#[:space:]]*dtoverlay=(rcio|spi0-4cs|spi1-1cs|navio2).*$//g' "$conf"
  sudo sed -i -E 's/^[#[:space:]]*dtparam=spi=.*$//g' "$conf"

  # Append the correct lines
  {
    echo "dtoverlay=rcio"
    echo "dtoverlay=spi0-4cs"
    echo "dtoverlay=spi1-1cs"
    echo "dtparam=spi=on"
    # optional LED overlay: echo "dtoverlay=navio-rgb"
  } | sudo tee -a "$conf" >/dev/null

  log "Updated $conf:"
  grep -E '^(dtoverlay|dtparam)=' "$conf" | sed 's/^/  /'

  echo
  read -rp "Reboot now to apply overlays? [y/N] " ans
  if [[ "${ans,,}" == "y" ]]; then
    log "Rebooting..."
    sudo sync
    sudo systemctl reboot
  else
    log "Reboot skipped. Please reboot before testing."
  fi
}

case "${1:-}" in
  verify)  show_status ;;
  fix)     apply_fix ;;
  *) echo "Usage: $0 {verify|fix}"; exit 2 ;;
esac
