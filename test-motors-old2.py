from navio2 import pwm
import time

NUM_MOTORS = 4
FREQ_HZ = 400
PERIOD_NS = int(1e9 / FREQ_HZ)  # 2.5ms = 2,500,000ns

NEUTRAL_US = 1000
MAX_US = 2000
THROTTLE_PERCENT = 10

SPIN_TIME = 2.0
DELAY_BETWEEN = 1.0

# Calculate desired pulse width in ns
pulse_width_us = NEUTRAL_US + (MAX_US - NEUTRAL_US) * (THROTTLE_PERCENT / 100.0)
pulse_width_ns = int(pulse_width_us * 1000)

# Sanity check
if not (0 < pulse_width_ns < PERIOD_NS):
    raise ValueError(f"Invalid pulse width: {pulse_width_ns} ns")

print('starting test.')

channels = []
for motor in range(NUM_MOTORS):
    print(f'initializing motor {motor}.')
    ch = pwm.PWM(motor)
    ch.initialize()
    ch.set_period(PERIOD_NS)
    ch.enable()
    channels.append(ch)

try:
    for motor, ch in enumerate(channels):
        print(f'testing motor {motor}.')
        ch.set_duty_cycle(pulse_width_ns)  # e.g., 1100us pulse
        time.sleep(SPIN_TIME)
        ch.set_duty_cycle(NEUTRAL_US * 1000)  # 1000us pulse
        time.sleep(DELAY_BETWEEN)
except KeyboardInterrupt:
    print("Interrupted. Stopping all motors.")
finally:
    for ch in channels:
        ch.set_duty_cycle(NEUTRAL_US * 1000)
        ch.disable()
        ch.deinitialize()

print('finished test.')
