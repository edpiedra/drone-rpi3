#!/usr/bin/env python3
import time
import navio2.pwm as pwm_mod
import navio2.util as util

# Must be root for hardware access
util.check_apm()

# PWM configuration
SERVO_MIN = 1100   # µs (stop)
SERVO_MAX = 1900   # µs (full throttle)
TEST_POWER = 1300  # µs (low spin test)

# NOTE: Navio2 PWM channels are 0-based in the Python API.
# If your old code used 1–4, switch to 0–3.
MOTOR_CHANNELS = [0, 1, 2, 3]

# Initialize PWM for each motor channel
pwms = {}
for ch in MOTOR_CHANNELS:
    p = pwm_mod.PWM(ch)
    p.initialize()
    p.set_period(50)           # 50 Hz for ESCs
    p.enable()
    p.set_duty_cycle(SERVO_MIN)
    pwms[ch] = p

print("Starting motor test. Props OFF. ESCs powered and calibrated?")

# Give ESCs a moment at min signal to arm safely
time.sleep(3.0)

try:
    for ch in MOTOR_CHANNELS:
        print(f"Spinning motor on channel {ch}...")
        pwms[ch].set_duty_cycle(TEST_POWER)   # start motor
        time.sleep(0.5)                       # spin time
        pwms[ch].set_duty_cycle(SERVO_MIN)    # stop
        print(f"Motor {ch} stopped. Waiting 2 seconds.")
        time.sleep(2.0)

finally:
    print("Stopping and disabling all motors.")
    for ch, p in pwms.items():
        p.set_duty_cycle(SERVO_MIN)
        p.disable()
    print("Test complete.")
