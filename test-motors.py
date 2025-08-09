#!/usr/bin/env python3
import time
import navio.pwm
import navio.util

# Enable root access for hardware
navio.util.check_apm()

# PWM configuration
SERVO_MIN = 1100  # microseconds (stop)
SERVO_MAX = 1900  # microseconds (full throttle)
TEST_POWER = 1300 # microseconds (low spin test)
MOTOR_CHANNELS = [1, 2, 3, 4]  # Navio2 motor output channels

# Initialize PWM objects for each motor channel
pwms = {}
for ch in MOTOR_CHANNELS:
    pwm = navio.pwm.PWM(ch)
    pwm.initialize()
    pwm.set_period(50)  # 50Hz for ESCs
    pwm.enable()
    pwm.set_duty_cycle(SERVO_MIN)  # Start at stop
    pwms[ch] = pwm

print("Starting motor test. Props removed? ESCs armed?")

try:
    for ch in MOTOR_CHANNELS:
        print(f"Spinning motor on channel {ch}...")
        pwms[ch].set_duty_cycle(TEST_POWER)  # Start motor
        time.sleep(0.5)  # Spin time
        pwms[ch].set_duty_cycle(SERVO_MIN)   # Stop motor
        print(f"Motor {ch} stopped. Waiting 2 seconds.")
        time.sleep(2)

finally:
    print("Stopping all motors.")
    for ch in MOTOR_CHANNELS:
        pwms[ch].set_duty_cycle(SERVO_MIN)
    print("Test complete.")
