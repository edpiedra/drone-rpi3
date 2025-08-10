#!/usr/bin/env python3
"""
Navio2 + ArduCopter motor test (Pi 3)

- Preferred: use MAVLink motor test (ArduPilot stays in control).
- Fallback: direct PWM via Navio2 API (requires ArduPilot stopped).

Usage:
  sudo python3 motor_test.py
  sudo python3 motor_test.py --endpoint udp:127.0.0.1:14551 --motors 1,2,3,4 --on-sec 1.0 --pause-sec 1.0 --percent 20
"""

import argparse
import os
import sys
import time
import logging
from typing import List

# ---------- logging ----------
LOG_PATH = "~/install_logs/navio_motor_test.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_PATH), logging.StreamHandler(sys.stdout)],
)

def require_root():
    if os.geteuid() != 0:
        logging.error("Please run with sudo/root.")
        sys.exit(1)

def read_rcio_status():
    base = "/sys/kernel/rcio/status"
    status = {}
    for name in ("alive", "init_ok", "pwm_ok"):
        try:
            with open(os.path.join(base, name)) as f:
                status[name] = f.read().strip()
        except Exception:
            status[name] = "?"
    return status

# ---------- MAVLink (preferred) ----------
def try_mavlink(endpoint, motors: List[int], on_sec: float, pause_sec: float, percent: int) -> bool:
    """
    Returns True if MAVLink path succeeded, False to allow fallback.
    """
    try:
        from pymavlink import mavutil
    except Exception as e:
        logging.warning("pymavlink not available (%s).", e)
        return False

    try:
        logging.info("Connecting to ArduCopter via MAVLink at %s ...", endpoint)
        m = mavutil.mavlink_connection(endpoint, autoreconnect=True, source_system=255)
        m.wait_heartbeat(timeout=8)
        logging.info("Heartbeat OK (sysid=%s compid=%s).", m.target_system, m.target_component)
    except Exception as e:
        logging.warning("MAVLink connection failed: %s", e)
        return False

    # Ensure we know the autopilot type (optional)
    try:
        m.mav.command_long_send(
            m.target_system,
            m.target_component,
            mavutil.mavlink.MAV_CMD_REQUEST_AUTOPILOT_CAPABILITIES,
            0, 1, 0, 0, 0, 0, 0, 0
        )
    except Exception:
        pass

    # Motor test using MAV_CMD_DO_MOTOR_TEST
    # See: https://mavlink.io/en/messages/common.html#MAV_CMD_DO_MOTOR_TEST
    # param1=motor, param2=test_type(0-throttle_pct), param3=throttle_pct, param4=timeout(sec), param5=count(ignored here)
    for motor in motors:
        logging.info("MAVLink: testing motor %d at %d%% for %.2fs ...", motor, percent, on_sec)
        try:
            m.mav.command_long_send(
                m.target_system,
                m.target_component,
                mavutil.mavlink.MAV_CMD_DO_MOTOR_TEST,
                0,
                motor,     # param1: motor index (1-based)
                0,         # param2: throttle type (0 = percentage)
                percent,   # param3: throttle %
                on_sec,    # param4: duration (sec)
                0, 0, 0    # param5-7 unused
            )
        except Exception as e:
            logging.error("Failed to command motor %d: %s", motor, e)
            return False

        # Wait for the duration plus a small guard
        time.sleep(on_sec + 0.2)
        if pause_sec > 0:
            time.sleep(pause_sec)

    logging.info("MAVLink motor test complete.")
    return True

# ---------- Direct PWM (fallback) ----------
def navio_pwm_test(channels: List[int], on_sec: float, pause_sec: float, us_active: int, us_idle: int):
    try:
        import navio.pwm
    except Exception as e:
        logging.error("Navio2 Python API not available: %s", e)
        sys.exit(2)

    # Initialize channels
    pwms = []
    for ch in channels:
        pwm = navio.pwm.PWM(ch)
        pwm.initialize()
        pwm.set_period(50)           # 50 Hz (20ms)
        pwm.enable()
        pwm.set_duty_cycle(us_idle)  # safety low
        pwms.append(pwm)

    # Spin each channel
    for ch, pwm in zip(channels, pwms):
        logging.info("PWM: spinning channel %d at %dus for %.2fs ...", ch, us_active, on_sec)
        pwm.set_duty_cycle(us_active)
        time.sleep(on_sec)
        pwm.set_duty_cycle(us_idle)
        if pause_sec > 0:
            time.sleep(pause_sec)

    logging.info("Direct PWM motor test complete.")

def main():
    parser = argparse.ArgumentParser(description="Navio2 motor test (MAVLink preferred, PWM fallback).")
    parser.add_argument("--endpoint", default="udp:127.0.0.1:14550",
                        help="MAVLink endpoint (e.g., udp:127.0.0.1:14551 or /dev/ttyAMA0,57600)")
    parser.add_argument("--motors", default="1,2,3,4",
                        help="Motor order for MAVLink mode (1-based), e.g., 1,2,3,4")
    parser.add_argument("--channels", default="0,1,2,3",
                        help="PWM channels for direct mode (0-based), e.g., 0,1,2,3")
    parser.add_argument("--on-sec", type=float, default=1.0, help="Spin duration per motor (seconds)")
    parser.add_argument("--pause-sec", type=float, default=1.0, help="Pause between motors (seconds)")
    parser.add_argument("--percent", type=int, default=20, help="Throttle %% for MAVLink mode (5–30 typical)")
    parser.add_argument("--us-active", type=int, default=1300, help="Active pulse width for direct PWM (µs)")
    parser.add_argument("--us-idle", type=int, default=1000, help="Idle/stop pulse width for direct PWM (µs)")
    args = parser.parse_args()

    require_root()
    logging.info("Log file: %s", LOG_PATH)

    # Quick RCIO status visibility
    status = read_rcio_status()
    logging.info("RCIO status: alive=%s init_ok=%s pwm_ok=%s", status.get("alive"), status.get("init_ok"), status.get("pwm_ok"))

    # Try MAVLink first
    motors = [int(x) for x in args.motors.split(",") if x.strip()]
    if try_mavlink(args.endpoint, motors, args.on_sec, args.pause_sec, args.percent):
        return

    logging.warning("Falling back to direct PWM (ArduPilot must be STOPPED for this).")
    channels = [int(x) for x in args.channels.split(",") if x.strip()]
    navio_pwm_test(channels, args.on_sec, args.pause_sec, args.us_active, args.us_idle)

if __name__ == "__main__":
    main()
