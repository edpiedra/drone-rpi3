from pymavlink import mavutil
m = mavutil.mavlink_connection('udp:192.168.1.31:14550')  # change if needed
m.wait_heartbeat()
m.mav.param_set_send(m.target_system, m.target_component,
                     b'ESC_CALIBRATION', float(3),
                     mavutil.mavlink.MAV_PARAM_TYPE_INT32)
print("ESC_CALIBRATION set to 3 (auto-calibrate on next boot)")
