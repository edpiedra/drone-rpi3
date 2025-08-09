#!/usr/bin/env python3
import time
import sys
import navio2.pwm as pwm_mod
import navio2.util as util

# Stop ArduPilot first! (systemctl stop arducopter)
util.check_apm()

F_HZ = 50
PERIOD_US = 1_000_000 // F_HZ  # 20,000 us
SERVO_MIN_US = 1100
TEST_US = 1450                  # a bit higher so direction is obvious
SPIN_SEC = 3.0
GAP_SEC = 3.0

# Navio2 channels are 0-based; ArduPilot labeling shown in comments
MOTORS = [
    (0, "Motor 1 (Front Right)  EXPECTED: CCW"),
    (1, "Motor 2 (Rear  Left)   EXPECTED: CCW"),
    (2, "Motor 3 (Front Left)   EXPECTED: CW"),
    (3, "Motor 4 (Rear  Right)  EXPECTED: CW"),
]

def set_pulse(p, pulse_us):
    if hasattr(p, "set_duty_cycle_us"):
        p.set_duty_cycle_us(int(pulse_us))
    else:
        # Fallback across variants: try fractional duty
        frac = float(pulse_us) / float(PERIOD_US)
        try:
            p.set_duty_cycle(frac)
        except Exception:
            p.set_duty_cycle(int(pulse_us))

# Init all channels at min (before enabling)
pwms = []
for ch, _ in MOTORS:
    p = pwm_mod.PWM(ch)
    p.initialize()
    p.set_period(F_HZ)
    set_pulse(p, SERVO_MIN_US)
    p.enable()
    pwms.append((ch, p))

print("=== MOTOR DIRECTION CHECK ===")
print("* Props OFF. Tape/zip-tie flags on motor bells.")
print("* ESCs powered. ArduPilot stopped.")
time.sleep(2)

try:
    for ch, label in MOTORS:
        print(f"\n{label}")
        for i in range(3, 0, -1):
            print(f"  Spinning channel {ch} in {i}...")
            time.sleep(1)
        set_pulse(dict(pwms)[ch], TEST_US)
        t0 = time.time()
        while time.time() - t0 < SPIN_SEC:
            time.sleep(0.05)
        set_pulse(dict(pwms)[ch], SERVO_MIN_US)
        print(f"  Stopped. Waiting {GAP_SEC:.0f}s...")
        time.sleep(GAP_SEC)
finally:
    print("\nDisabling all outputs...")
    for _, p in pwms:
        try:
            set_pulse(p, SERVO_MIN_US)
            p.disable()
        except Exception:
            pass
    print("Done.")
