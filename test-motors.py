#!/usr/bin/env python3
"""
Navio2 motor test (RPi3, Emlid image, ArduPilot stopped)

Usage examples:
  sudo -E python3 -m test-motors
  sudo -E python3 -m test-motors --channels 1 2 3 4 --spin 1350 --spin-sec 2.5
  sudo -E python3 -m test-motors --calibrate --channels 1  # one-time ESC calibration
  sudo -E python3 -m test-motors --stop-apm                # try to stop ArduPilot first
"""

import argparse
import os
import sys
import time
import subprocess

import navio2.pwm as pwm_mod
import navio2.util as util


def stop_apm():
    """Try to stop common ArduPilot services to free RCIO PWM."""
    services = ["arducopter", "ardupilot", "arduplane", "ardurover"]
    for s in services:
        try:
            subprocess.run(["sudo", "systemctl", "stop", s], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
    # also pkill if needed
    try:
        subprocess.run(["sudo", "pkill", "-f", "-i", "arducopter|ardupilot|arduplane|ardurover"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def apm_running() -> bool:
    """Best-effort check for APM."""
    try:
        out = subprocess.check_output(
            "ps aux | egrep -i 'ardu(copter|pilot|plane|rover)' | grep -v grep || true",
            shell=True, text=True
        ).strip()
        return bool(out)
    except Exception:
        return False


def rcio_ok() -> bool:
    """Check RCIO state."""
    try:
        alive = open("/sys/kernel/rcio/status/alive").read().strip()
        init_ok = open("/sys/kernel/rcio/status/init_ok").read().strip()
        pwm_ok = open("/sys/kernel/rcio/status/pwm_ok").read().strip()
        return alive == "1" and init_ok == "1" and pwm_ok == "1"
    except Exception:
        return False


def set_pulse(p, period_us: int, pulse_us: int):
    """Set pulse width in microseconds on a PWM channel."""
    # Many ESCs expect 50Hz: period_us ~= 20000 us, pulses 1000-2000 us
    p.set_period(period_us)
    p.set_duty_cycle(pulse_us)


def build_pwm(ch: int):
    """Create, initialize and enable a PWM channel."""
    p = pwm_mod.PWM(ch)
    p.initialize()
    p.enable()
    return p


def parse_args():
    ap = argparse.ArgumentParser(description="Sequential motor test for Navio2")
    ap.add_argument("--channels", type=int, nargs="+", default=[1, 2, 3, 4],
                    help="RCOUT channels to test (1-based). Default: 1 2 3 4")
    ap.add_argument("--freq", type=int, default=50,
                    help="PWM update frequency in Hz (50 is typical for ESCs)")
    ap.add_argument("--min", dest="min_us", type=int, default=1000,
                    help="Min/idle pulse width in microseconds (default 1000)")
    ap.add_argument("--spin", dest="spin_us", type=int, default=1350,
                    help="Spin pulse width in microseconds (default 1350)")
    ap.add_argument("--spin-sec", type=float, default=2.5,
                    help="How long to spin each motor (seconds)")
    ap.add_argument("--gap-sec", type=float, default=2.0,
                    help="Pause between motors (seconds)")
    ap.add_argument("--arm-hold-sec", type=float, default=2.0,
                    help="Hold time at min pulse for ESC arming (seconds)")
    ap.add_argument("--calibrate", action="store_true",
                    help="Perform ESC calibration (2000us then 1000us) on specified channels, then exit")
    ap.add_argument("--stop-apm", action="store_true",
                    help="Try to stop ArduPilot services before running")
    ap.add_argument("--dry-run", action="store_true",
                    help="Print what would be done without actually driving PWM")
    return ap.parse_args()


def main():
    args = parse_args()

    if args.stop_apm:
        print("[info] Stopping ArduPilot services…")
        stop_apm()

    # Keep util.check_apm to prevent silent conflicts unless user asked us to stop it.
    # If APM is still running, util.check_apm() will raise.
    if apm_running():
        print("[warn] ArduPilot still appears to be running.")
    util.check_apm()

    if not rcio_ok():
        sys.exit("[error] RCIO not ready (alive/init_ok/pwm_ok != 1). Check power to the servo rail and RCIO status.")

    period_us = int(1_000_000 // args.freq)
    chs = args.channels

    if args.dry_run:
        print(f"[dry-run] channels={chs}, freq={args.freq}Hz, period={period_us}us, "
              f"min={args.min_us}us, spin={args.spin_us}us")
        return 0

    # Build PWM objects
    pwms = []
    try:
        for ch in chs:
            p = build_pwm(ch)
            pwms.append((ch, p))

        # Always start by sending MIN to all channels (lets ESCs see true minimum)
        for _, p in pwms:
            set_pulse(p, period_us, args.min_us)

        if args.calibrate:
            # One-time calibration (PROPS OFF)
            # 1) full throttle (2000us) for ~2.5s
            # 2) then immediate drop to 1000us for ~3s
            print("[CAL] Starting ESC calibration (PROPS OFF).")
            time.sleep(0.5)
            for ch, p in pwms:
                print(f"[CAL] CH{ch}: 2000us …")
                set_pulse(p, period_us, 2000)
            time.sleep(2.5)
            for ch, p in pwms:
                print(f"[CAL] CH{ch}: 1000us …")
                set_pulse(p, period_us, 1000)
            time.sleep(3.0)
            print("[CAL] Done. Returning to idle (1000us).")
            for _, p in pwms:
                set_pulse(p, period_us, 1000)
            return 0

        # Arm phase at MIN (some ESCs need a moment at true minimum)
        print(f"[info] Holding {args.min_us}us for {args.arm_hold_sec:.1f}s to arm ESCs…")
        time.sleep(args.arm_hold_sec)

        print("\n[info] Spinning each motor sequentially. PROPS OFF.")
        for ch, p in pwms:
            print(f"\n[spin] CH{ch}: {args.spin_us}us for {args.spin_sec:.1f}s")
            set_pulse(p, period_us, args.spin_us)
            t0 = time.time()
            try:
                while time.time() - t0 < args.spin_sec:
                    time.sleep(0.05)
            except KeyboardInterrupt:
                print("\n[info] Ctrl+C detected — stopping current channel.")
                break
            # back to min, gap
            set_pulse(p, period_us, args.min_us)
            print(f"[spin] CH{ch}: stopped. Waiting {args.gap_sec:.1f}s…")
            t1 = time.time()
            try:
                while time.time() - t1 < args.gap_sec:
                    time.sleep(0.05)
            except KeyboardInterrupt:
                print("\n[info] Ctrl+C detected — exiting.")
                break

        # Final return to MIN on all channels
        for _, p in pwms:
            set_pulse(p, period_us, args.min_us)

    except KeyboardInterrupt:
        print("\n[info] Ctrl+C detected — exiting.")

    finally:
        print("\n[info] Disabling all outputs…")
        for _, p in pwms:
            try:
                set_pulse(p, period_us, args.min_us)
                p.disable()
            except Exception:
                pass
        print("[info] Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
