from navio2 import pwm
import time

NUM_MOTORS = 4
FREQ_HZ = 400
PERIOD_NS = int(1e9 / FREQ_HZ)
NEUTRAL_US = 1000
MAX_US = 2000
THROTTLE_PERCENT = 10
SPIN_TIME = 2.0
DELAY_BETWEEN = 1.0

pulse_width_us = NEUTRAL_US + (MAX_US - NEUTRAL_US) * (THROTTLE_PERCENT / 100.0)
pulse_width_ns = int(pulse_width_us * 1000)

print('starting test.')

# Initialize and configure each motor channel only once
channels = []
for motor in range(NUM_MOTORS):
    ch = pwm.PWM(motor)
    ch.set_period(PERIOD_NS)
    ch.enable()
    channels.append(ch)

# Spin each motor in sequence
for motor, ch in enumerate(channels):
    print(f'testing motor {motor}.')
    ch.set_duty_cycle(pulse_width_ns)
    time.sleep(SPIN_TIME)
    ch.set_duty_cycle(NEUTRAL_US * 1000)
    time.sleep(DELAY_BETWEEN)

# Optionally disable PWM channels at the end
for ch in channels:
    ch.disable()

print('finished test.')
