from navio2 import pwm 
import time 

NUM_MOTORS = 4
FREQ = 400                    
NEUTRAL_US = 1000  
MAX_US = 2000           
THROTTLE_PERCENT = 10   
SPIN_TIME = 2.0       
DELAY_BETWEEN = 1.0    

pulse_width = NEUTRAL_US + (MAX_US - NEUTRAL_US) * (THROTTLE_PERCENT / 100.0)

print('starting test.')

for motor in range(NUM_MOTORS):
    with pwm.PWM(motor) as channel:
        channel.set_period(FREQ)
        channel.enable()
        channel.set_duty_cycle(pulse_width)
        time.sleep(SPIN_TIME)
        channel.set_duty_cycle(NEUTRAL_US)
        time.sleep(DELAY_BETWEEN)

print('finished test.')        