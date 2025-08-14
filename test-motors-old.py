#!/usr/bin/env python3

import time
from navio2 import pwm

# Adjust these for your ESC and motor setup
PWM_OUTPUTS = list(range(4))  # 0-3 for quad; extend for hex or octa
FREQ = 400                    # ESC update frequency (Hz)
NEUTRAL_US = 1000              # Minimum pulse width in microseconds
MAX_US = 2000                  # Maximum pulse width in microseconds
THROTTLE_PERCENT = 10          # 10% throttle
SPIN_TIME = 2.0                # seconds per motor
DELAY_BETWEEN = 1.0            # seconds between motors

# Calculate pulse width for desired throttle
pulse_width = NEUTRAL_US + (MAX_US - NEUTRAL_US) * (THROTTLE_PERCENT / 100.0)

def main():
    print(f"Initializing PWM at {FREQ} Hz...")
    for ch in PWM_OUTPUTS:
        pwm.init(ch)
        pwm.set_frequency(ch, FREQ)
        pwm.enable(ch)

    print("Starting motor test...")
    for ch in PWM_OUTPUTS:
        print(f"Motor {ch}: spinning at {THROTTLE_PERCENT}% for {SPIN_TIME} sec")
        pwm.set_duty_cycle(ch, pulse_width)
        time.sleep(SPIN_TIME)
        pwm.set_duty_cycle(ch, NEUTRAL_US)
        time.sleep(DELAY_BETWEEN)

    print("Motor test complete. Stopping all motors...")
    for ch in PWM_OUTPUTS:
        pwm.set_duty_cycle(ch, NEUTRAL_US)
        pwm.disable(ch)

if __name__ == "__main__":
    main()
