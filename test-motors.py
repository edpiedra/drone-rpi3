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

channels = []
for motor in range(NUM_MOTORS):
    print(f'initializing motor {motor}.')
    ch = pwm.PWM(motor)
    ch.initialize()
    try:
        ch.set_period(PERIOD_NS)
    except OSError as e:
        print(f"Warning: Failed to set period for motor {motor}: {e}")
    ch.enable()
    channels.append(ch)

for motor, ch in enumerate(channels):
    print(f'testing motor {motor}.')
    ch.set_duty_cycle(pulse_width_ns)
    time.sleep(SPIN_TIME)
    ch.set_duty_cycle(NEUTRAL_US * 1000)
    time.sleep(DELAY_BETWEEN)

for ch in channels:
    ch.disable()
    ch.deinitialize()

print('finished test.')
