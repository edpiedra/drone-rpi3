#!/usr/bin/env bash
set -euo pipefail
log(){ printf '[%s] %s\n' "$(date +"%F %T")" "$*"; }

log "Kernel: $(uname -a)"
log "Config overlay/SPI lines:"
grep -E '^(dtoverlay|dtparam)=' /boot/config.txt || true
echo

log "Overlay actually applied?"
if [[ -d /proc/device-tree/overlays/navio2 ]]; then
  echo "  /proc/device-tree/overlays/navio2 is present"
else
  echo "  navio2 overlay NOT visible under /proc/device-tree/overlays"
fi
echo

log "SPI devices:"
ls -1 /dev/spidev* || true
echo

log "RCIO status:"
if [[ -r /sys/kernel/rcio/status/alive ]]; then
  for k in alive init_ok pwm_ok board_name; do
    printf "  %-8s : %s\n" "$k" "$(cat /sys/kernel/rcio/status/$k)"
  done
else
  echo "  /sys/kernel/rcio/status not found"
fi
echo

log "PWM sysfs:"
ls -d /sys/class/pwm/pwmchip* 2>/dev/null || echo "  no pwmchip nodes"
for c in /sys/class/pwm/pwmchip*; do
  [[ -d "$c" ]] && echo "  $c npwm=$(cat "$c/npwm")"
done
echo

log "RCIO firmware files present?"
sudo find /lib/firmware -maxdepth 3 -iname '*rcio*' -o -iname 'navio*' 2>/dev/null | sed 's/^/  /' || true
echo

log "Who is using SPI right now?"
sudo lsof /dev/spidev* 2>/dev/null | sed 's/^/  /' || echo "  nobody"
echo

log "Relevant dmesg (rcio|navio|spi|firmware) — last 200 lines:"
dmesg | tail -n 200 | grep -Ei 'rcio|navio|spi|firmware' || echo "  (no matches)"
