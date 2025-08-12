#!/usr/bin/env bash
set -euo pipefail

PWMCHIP="/sys/class/pwm/pwmchip0"   # Navio2 RCIO PWM
CHANNELS=(0 1 2 3)                  # RC outputs 1–4 → pwm0..pwm3
PERIOD_NS=20000000                  # 50 Hz
MAX_NS=2000000                      # 2000 µs
MIN_NS=1000000                      # 1000 µs

log(){ printf '[%s] %s\n' "$(date +"%F %T")" "$*"; }

require(){
  [[ -d "$PWMCHIP" ]] || { echo "No $PWMCHIP; is dtoverlay=navio2 active?"; exit 1; }
}

export_if_needed(){
  local ch="$1"
  [[ -d "$PWMCHIP/pwm$ch" ]] || echo "$ch" | sudo tee "$PWMCHIP/export" >/dev/null
}

setup_channels(){
  for ch in "${CHANNELS[@]}"; do
    export_if_needed "$ch"
    echo 0            | sudo tee "$PWMCHIP/pwm$ch/enable" >/dev/null || true
    echo "$PERIOD_NS" | sudo tee "$PWMCHIP/pwm$ch/period" >/dev/null
  done
}

set_all(){
  local duty="$1"
  for ch in "${CHANNELS[@]}"; do
    echo "$duty" | sudo tee "$PWMCHIP/pwm$ch/duty_cycle" >/dev/null
  done
}

enable_all(){ for ch in "${CHANNELS[@]}"; do echo 1 | sudo tee "$PWMCHIP/pwm$ch/enable" >/dev/null; done; }
disable_all(){ for ch in "${CHANNELS[@]}"; do echo 0 | sudo tee "$PWMCHIP/pwm$ch/enable" >/dev/null; done; }
cleanup(){ for ch in "${CHANNELS[@]}"; do [[ -d "$PWMCHIP/pwm$ch" ]] && echo "$ch" | sudo tee "$PWMCHIP/unexport" >/dev/null || true; done; }

calibrate(){
  require
  setup_channels
  echo
  read -rp "Disconnect LiPo from ESCs, then press ENTER..." _
  log "Sending MAX throttle..."
  set_all "$MAX_NS"
  enable_all
  echo
  read -rp "Now CONNECT LiPo; after the 'max' beeps, press ENTER..." _
  log "Sending MIN throttle..."
  set_all "$MIN_NS"
  sleep 2
  log "Optionally set neutral (1500 µs) for a second..."
  set_all 1500000
  sleep 1
  log "Disabling."
  disable_all
  cleanup
  log "ESC calibration complete."
}

verify(){
  require
  log "Overlay/SPI check:"
  grep -E '^(dtoverlay|dtparam)=' /boot/config.txt || true
  echo
  log "RCIO status:"
  if [[ -r /sys/kernel/rcio/status/alive ]]; then
    printf "  alive   : %s\n" "$(cat /sys/kernel/rcio/status/alive)"
    printf "  init_ok : %s\n" "$(cat /sys/kernel/rcio/status/init_ok)"
    printf "  pwm_ok  : %s\n" "$(cat /sys/kernel/rcio/status/pwm_ok)"
    printf "  board   : %s\n" "$(cat /sys/kernel/rcio/status/board_name)"
  fi
  echo
  log "PWM chip:"
  ls -d "$PWMCHIP" || true
  echo "npwm: $(cat "$PWMCHIP/npwm")"
}

case "${1:-}" in
  calibrate) calibrate ;;
  verify)    verify ;;
  *) echo "Usage: $0 {verify|calibrate}"; exit 2 ;;
esac
