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

for motor in range(NUM_MOTORS):
    print(f'testing motor {motor}.')
    with pwm.PWM(motor) as channel:
        channel.set_period(PERIOD_NS)
        channel.set_duty_cycle(pulse_width_ns)
        channel.enable()
        time.sleep(SPIN_TIME)
        channel.set_duty_cycle(NEUTRAL_US * 1000)
        time.sleep(DELAY_BETWEEN)

print('finished test.')        