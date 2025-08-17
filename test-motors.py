from pymavlink import mavutil
import time

master = mavutil.mavlink_connection('udp:127.0.0.1:14550')
master.wait_heartbeat()
print("Connected")

# Arm the drone
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
    0,
    1, 0, 0, 0, 0, 0, 0
)
print("Armed")
time.sleep(2)

# Engage motor interlock (if applicable)
# You might need this if your interlock is assigned to RC channel 8
master.mav.rc_channels_override_send(
    master.target_system, master.target_component,
    0, 0, 0, 0, 0, 0, 1900, 0  # CH8 high
)
print("Motor interlock released")
time.sleep(2)

# Run motor test on motor 1
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_DO_MOTOR_TEST,
    0,
    1,     # motor number (1-based)
    0,     # throttle type: 0 = percentage
    10,    # throttle (30%)
    3,     # duration in seconds
    0, 0, 0
)
print("Motor test sent")

# Disarm after test
time.sleep(4)
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
    0,
    0, 0, 0, 0, 0, 0, 0
)
print("Disarmed")
