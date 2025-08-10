# esc_calibrate_direct.py  (PROPS OFF)
import time
from navio2 import pwm

MOTOR_CHANS = [0,1,2,3]     # adjust if needed
HIGH = 2000                 # μs (full throttle)
LOW  = 1000                 # μs (min)

pwms = []
for ch in MOTOR_CHANS:
    p = pwm.PWM(ch)
    p.initialize()
    p.set_period(50)
    p.enable()
    p.set_duty_cycle(LOW)   # safe low first
    pwms.append(p)

input("Ready. Press Enter, THEN immediately power the ESCs (LiPo ON). "
      "They must see HIGH at power-up...")

for p in pwms:
    p.set_duty_cycle(HIGH)  # send max
print("Holding HIGH for 2.5s...")
time.sleep(2.5)

for p in pwms:
    p.set_duty_cycle(LOW)   # then min to save range
print("Holding LOW for 3s...")
time.sleep(3.0)

for p in pwms:
    p.set_duty_cycle(LOW)
print("Done. Power-cycle ESCs and test at low throttle.")
