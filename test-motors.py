from pymavlink import mavutil
import time

# Connect to ArduPilot (adjust device and baudrate as needed)
# For UART, use something like '/dev/ttyAMA0', 57600
# For UDP, use 'udp:127.0.0.1:14550' if you're running ArduPilot locally
master = mavutil.mavlink_connection('udp:127.0.0.1:14550')

# Wait for heartbeat to make sure we're connected
master.wait_heartbeat()
print(f"Heartbeat from system {master.target_system} component {master.target_component}")

# Arm the drone (required for motor test)
def arm():
    master.mav.command_long_send(
        master.target_system, master.target_component,
        mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
        0,
        1, 0, 0, 0, 0, 0, 0
    )
    print("Sent arm command")
    master.recv_match(type='COMMAND_ACK', blocking=True)
    time.sleep(2)

# Disarm the drone
def disarm():
    master.mav.command_long_send(
        master.target_system, master.target_component,
        mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
        0,
        0, 0, 0, 0, 0, 0, 0
    )
    print("Sent disarm command")
    master.recv_match(type='COMMAND_ACK', blocking=True)

# Run motor test on specific motor
def test_motor(motor_num, throttle_type=0, throttle_pct=10, duration=2):
    print(f"Testing motor {motor_num} at {throttle_pct}% for {duration} sec")
    master.mav.command_long_send(
        master.target_system, master.target_component,
        mavutil.mavlink.MAV_CMD_DO_MOTOR_TEST,
        0,
        motor_num,         # motor sequence (1-4 for quad)
        throttle_type,     # 0: percent, 1: PWM
        throttle_pct,      # throttle (in % or PWM)
        duration,          # duration in seconds
        0, 0, 0            # unused
    )
    master.recv_match(type='COMMAND_ACK', blocking=True)
    time.sleep(duration + 1)

# Begin testing
arm()

# Test motors 1 through 4 individually (modify for hexa/octo)
for i in range(1, 5):
    test_motor(motor_num=i, throttle_type=0, throttle_pct=10, duration=2)

disarm()
