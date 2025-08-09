#!/usr/bin/env python3
import time
import navio2.pwm as pwm_mod
import navio2.util as util

util.check_apm()  # ensure ArduPilot is NOT running

SERVO_MIN_US = 1100
SERVO_MAX_US = 1900
TEST_POWER_US = 1300
F_HZ = 50
PERIOD_US = 1_000_000 // F_HZ  # 20_000 us at 50 Hz

MOTOR_CHANNELS = [0, 1, 2, 3]

def set_pulse(p, pulse_us):
    """Be flexible across navio2 variants."""
    if hasattr(p, "set_duty_cycle_us"):
        p.set_duty_cycle_us(int(pulse_us))
    else:
        # Some builds use 'set_duty_cycle' as a fraction (0..1) or percent.
        # We'll try fraction first; if that fails, try raw microseconds.
        frac = float(pulse_us) / float(PERIOD_US)  # 0..1
        try:
            p.set_duty_cycle(frac)   # e.g., 0.055 for 1100us at 20ms
        except Exception:
            # Fallback: some forks actually expect microseconds here
            p.set_duty_cycle(int(pulse_us))

pwms = {}
for ch in MOTOR_CHANNELS:
    p = pwm_mod.PWM(ch)
    p.initialize()
    p.set_period(F_HZ)            # set period first
    set_pulse(p, SERVO_MIN_US)    # set a safe duty BEFORE enabling
    p.enable()                    # then enable the output
    pwms[ch] = p

print("Starting motor test. Props OFF. ESCs powered and calibrated?")
time.sleep(2.0)

try:
    for ch in MOTOR_CHANNELS:
        print(f"Spinning motor on channel {ch}...")
        set_pulse(pwms[ch], TEST_POWER_US)
        time.sleep(0.5)
        set_pulse(pwms[ch], SERVO_MIN_US)
        print("Waiting 2s…")
        time.sleep(2.0)
finally:
    print("Stopping and disabling all motors.")
    for ch, p in pwms.items():
        set_pulse(p, SERVO_MIN_US)
        p.disable()
    print("Test complete.")
