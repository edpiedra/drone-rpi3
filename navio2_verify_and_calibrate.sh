#!/usr/bin/env bash
set -euo pipefail

RCIO_BASE="/sys/kernel/rcio"
PWM_BASE="$RCIO_BASE/pwm"   # expects pwm0..pwm7 etc.

log(){ printf '[%s] %s\n' "$(date +"%F %T")" "$*"; }

verify() {
  log "Checking /boot/config.txt for overlay and SPI..."
  grep -E '^(dtoverlay|dtparam)=' /boot/config.txt || true
  echo

  log "Listing SPI devices..."
  ls -1 /dev/spidev* || true
  echo

  log "RCIO status:"
  if [[ -r $RCIO_BASE/status/alive ]]; then
    printf "  alive    : %s\n"     "$(cat $RCIO_BASE/status/alive)"
    printf "  init_ok  : %s\n"     "$(cat $RCIO_BASE/status/init_ok)"
    printf "  pwm_ok   : %s\n"     "$(cat $RCIO_BASE/status/pwm_ok)"
    printf "  board    : %s\n"     "$(cat $RCIO_BASE/status/board_name)"
  else
    echo "  RCIO status not available at $RCIO_BASE"
  fi
  echo

  if [[ -d "$PWM_BASE" ]]; then
    log "Found RCIO PWM sysfs at $PWM_BASE:"
    ls "$PWM_BASE" | sed 's/^/  /'
  else
    log "RCIO PWM sysfs not found (expected $PWM_BASE)."
  fi

  echo
  log "If init_ok=0 after enabling dtoverlay=navio2 and SPI, do a FULL power-cycle (remove all power for 10–15s), then boot with Navio2 and the 5V rail coming up at the same time as the Pi."
}

# ESC calibration using RCIO PWM sysfs (channels 0..3)
calibrate() {
  local channels=(0 1 2 3)     # RC outputs 1–4
  local period_ns=20000000     # 50 Hz
  local max_us=2000000         # 2000 µs
  local min_us=1000000         # 1000 µs

  if [[ ! -d "$PWM_BASE" ]]; then
    echo "RCIO PWM sysfs not found at $PWM_BASE. Run verify first." >&2
    exit 1
  fi

  log "Preparing PWM channels: ${channels[*]}"
  for ch in "${channels[@]}"; do
    local d="$PWM_BASE/pwm$ch"
    [[ -d "$d" ]] || { echo "Missing $d"; exit 1; }
    echo "$period_ns" | sudo tee "$d/period" >/dev/null
    echo 0 | sudo tee "$d/enable" >/dev/null
  done

  echo
  read -rp "Disconnect LiPo from ESCs, then press ENTER to continue..." _

  log "Sending MAX throttle (calibration start) to channels ${channels[*]}..."
  for ch in "${channels[@]}"; do
    echo 1 | sudo tee "$PWM_BASE/pwm$ch/enable" >/dev/null
    echo "$max_us" | sudo tee "$PWM_BASE/pwm$ch/duty_cycle" >/dev/null
  done

  echo
  read -rp "Now CONNECT LiPo. After the ESCs play the 'max' beeps, press ENTER..." _

  log "Sending MIN throttle (finalize calibration)..."
  for ch in "${channels[@]}"; do
    echo "$min_us" | sudo tee "$PWM_BASE/pwm$ch/duty_cycle" >/dev/null
  done

  sleep 2

  log "Optionally set neutral (1500 µs)."
  for ch in "${channels[@]}"; do
    echo 1500000 | sudo tee "$PWM_BASE/pwm$ch/duty_cycle" >/dev/null
  done

  sleep 1

  log "Disabling outputs."
  for ch in "${channels[@]}"; do
    echo 0 | sudo tee "$PWM_BASE/pwm$ch/enable" >/dev/null
  done

  log "ESC calibration complete."
}

case "${1:-}" in
  verify)    verify ;;
  calibrate) calibrate ;;
  *) echo "Usage: $0 {verify|calibrate}"; exit 2 ;;
esac
