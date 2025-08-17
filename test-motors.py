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
    try:
        ch.deinitialize()  # force deinit if left hanging
    except:
        pass
    ch.initialize()
    try:
        ch.set_period(PERIOD_NS)
        ch.enable()
    except OSError as e:
        print(f"Warning: Failed to set period/enable motor {motor}: {e}")
    channels.append(ch)


try:
    for motor, ch in enumerate(channels):
        print(f'testing motor {motor}.')
        ch.set_duty_cycle(pulse_width_ns)
        time.sleep(SPIN_TIME)
        ch.set_duty_cycle(NEUTRAL_US * 1000)
        time.sleep(DELAY_BETWEEN)
except KeyboardInterrupt:
    print("\nInterrupted! Stopping all motors.")
finally:
    for ch in channels:
        try:
            ch.set_duty_cycle(NEUTRAL_US * 1000)
            ch.disable()
            ch.deinitialize()
        except:
            pass
    print("finished test.")
